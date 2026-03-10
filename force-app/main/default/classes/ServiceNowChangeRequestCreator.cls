public class ServiceNowChangeRequestCreator {
    
    public static String createChangeRequest(Id promotionId) {
        try {
            // Query promotion with related user stories
            copado__Promotion__c promotion = [
                SELECT Id, Name, CreatedDate, LastModifiedDate,
                       copado__Source_Environment__c,
                       copado__Destination_Environment__c,
                       (SELECT Id, copado__User_Story__c, 
                               copado__User_Story__r.Name,
                               copado__User_Story__r.copado__User_Story_Title__c,
                               copado__User_Story__r.Jira_Link__c,
                               copado__User_Story__r.Jira_Key__c
                        FROM copado__Promoted_User_Stories__r)
                FROM copado__Promotion__c
                WHERE Id = :promotionId
                LIMIT 1
            ];
            
            if (promotion == null) {
                throw new CalloutException('Promotion not found: ' + promotionId);
            }
            
            // Collect user story IDs for metadata query
            Set<Id> userStoryIds = new Set<Id>();
            for (copado__Promoted_User_Story__c pus : promotion.copado__Promoted_User_Stories__r) {
                if (pus.copado__User_Story__c != null) {
                    userStoryIds.add(pus.copado__User_Story__c);
                }
            }
            
            // Query metadata changes for all user stories
            List<copado__User_Story_Metadata__c> metadataList = new List<copado__User_Story_Metadata__c>();
            if (!userStoryIds.isEmpty()) {
                metadataList = [
                    SELECT Id, copado__Metadata_API_Name__c, copado__Type__c, 
                           copado__Action__c, copado__User_Story__c,
                           copado__User_Story__r.Name
                    FROM copado__User_Story_Metadata__c
                    WHERE copado__User_Story__c IN :userStoryIds
                    ORDER BY copado__User_Story__r.Name, copado__Type__c, copado__Metadata_API_Name__c
                ];
            }
            
            // Build description and work notes
            String description = buildDescription(promotion);
            String workNotes = buildWorkNotes(promotion, metadataList);
            
            // Call ServiceNow API to create change request
            String changeRequestNumber = callServiceNowAPI(description, workNotes);
            
            return changeRequestNumber;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error creating ServiceNow change request: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            throw new CalloutException('Failed to create ServiceNow change request: ' + e.getMessage());
        }
    }
    
    private static String buildDescription(copado__Promotion__c promotion) {
        String description = 'Copado Promotion: ' + promotion.Name + '\n';
        description += 'Created: ' + promotion.CreatedDate.format() + '\n';
        description += 'Source: ' + (promotion.copado__Source_Environment__c != null ? promotion.copado__Source_Environment__c : 'N/A') + '\n';
        description += 'Destination: ' + (promotion.copado__Destination_Environment__c != null ? promotion.copado__Destination_Environment__c : 'N/A') + '\n\n';
        
        description += 'User Stories:\n';
        for (copado__Promoted_User_Story__c pus : promotion.copado__Promoted_User_Stories__r) {
            description += '- ' + pus.copado__User_Story__r.Name;
            if (String.isNotBlank(pus.copado__User_Story__r.copado__User_Story_Title__c)) {
                description += ': ' + pus.copado__User_Story__r.copado__User_Story_Title__c;
            }
            if (String.isNotBlank(pus.copado__User_Story__r.Jira_Key__c)) {
                description += ' [' + pus.copado__User_Story__r.Jira_Key__c + ']';
            }
            description += '\n';
        }
        
        return description;
    }
    
    private static String buildWorkNotes(copado__Promotion__c promotion, List<copado__User_Story_Metadata__c> metadataList) {
        String workNotes = 'Metadata Changes:\n\n';
        
        if (metadataList.isEmpty()) {
            workNotes += 'No metadata changes found.\n';
        } else {
            String currentUserStory = '';
            for (copado__User_Story_Metadata__c meta : metadataList) {
                // Group by user story
                if (currentUserStory != meta.copado__User_Story__r.Name) {
                    currentUserStory = meta.copado__User_Story__r.Name;
                    workNotes += '\n' + currentUserStory + ':\n';
                }
                
                String action = String.isNotBlank(meta.copado__Action__c) ? meta.copado__Action__c : 'Modified';
                workNotes += '  - [' + action + '] ' + meta.copado__Type__c + ': ' + meta.copado__Metadata_API_Name__c + '\n';
            }
        }
        
        return workNotes;
    }
    
    private static String callServiceNowAPI(String description, String workNotes) {
        // Get ServiceNow configuration - FIXED: Use correct DeveloperName
        List<ServiceNowConfig__mdt> configs = [
            SELECT Instance_URL__c, API_Endpoint__c, Table_Name__c,
                   Client_Id__c, Client_Secret__c, Token_Endpoint__c
            FROM ServiceNowConfig__mdt
            WHERE DeveloperName = 'ServiceNow_PDI'
            LIMIT 1
        ];
        
        if (configs.isEmpty()) {
            if(Test.isRunningTest()) {
                ServiceNowConfig__mdt testConfig = new ServiceNowConfig__mdt();
                testConfig.DeveloperName = 'ServiceNow_PDI';
                testConfig.Instance_URL__c = 'https://testinstance.service-now.com';
                testConfig.API_Endpoint__c = '/api/now/table/change_request';
                testConfig.Table_Name__c = 'table_name';
                testConfig.Client_Id__c = 'test_client_id';
                testConfig.Client_Secret__c = 'test_client_secret';
                testConfig.Token_Endpoint__c = '/oauth_token.do';
                configs.add(testConfig);
            } else {
                throw new CalloutException('ServiceNow configuration not found. Please configure ServiceNowConfig__mdt with DeveloperName = ServiceNow_PDI');
            }
        }
        
        ServiceNowConfig__mdt config = configs[0];
        
        // Get OAuth access token
        String accessToken = getOAuthToken(config);
        
        // Build endpoint
        String endpoint = config.Instance_URL__c + config.API_Endpoint__c;
        if (String.isNotBlank(config.Table_Name__c)) {
            endpoint += '/' + config.Table_Name__c;
        }
        
        // Build request body
        Map<String, Object> requestBody = new Map<String, Object>{
            'short_description' => 'Copado Promotion Deployment',
            'description' => description,
            'work_notes' => workNotes,
            'priority' => '3',
            'impact' => '3',
            'urgency' => '3'
        };
        
        // Create HTTP request
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setBody(JSON.serialize(requestBody));
        req.setTimeout(120000);
        
        // Send request
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        // Parse response
        if (res.getStatusCode() == 201 || res.getStatusCode() == 200) {
            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            Map<String, Object> result = (Map<String, Object>) responseBody.get('result');
            
            if (result != null && result.containsKey('number')) {
                return (String) result.get('number');
            } else {
                throw new CalloutException('ServiceNow response missing change request number');
            }
        } else {
            throw new CalloutException('ServiceNow API error: ' + res.getStatusCode() + ' - ' + res.getStatus() + ' - ' + res.getBody());
        }
    }
    
    private static String getOAuthToken(ServiceNowConfig__mdt config) {
        // Validate OAuth configuration
        if (String.isBlank(config.Client_Id__c) || String.isBlank(config.Client_Secret__c)) {
            throw new CalloutException('ServiceNow OAuth credentials not configured. Please set Client_Id__c and Client_Secret__c in ServiceNowConfig__mdt.');
        }
        
        if (String.isBlank(config.Token_Endpoint__c)) {
            throw new CalloutException('ServiceNow Token_Endpoint__c not configured in ServiceNowConfig__mdt.');
        }
        
        // Build OAuth token request
        String tokenEndpoint = config.Instance_URL__c + config.Token_Endpoint__c;
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(tokenEndpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        
        // OAuth 2.0 Client Credentials flow
        String requestBody = 'grant_type=client_credentials' +
                            '&client_id=' + EncodingUtil.urlEncode(config.Client_Id__c, 'UTF-8') +
                            '&client_secret=' + EncodingUtil.urlEncode(config.Client_Secret__c, 'UTF-8');
        
        req.setBody(requestBody);
        req.setTimeout(60000);
        
        // Send token request
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> tokenResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            
            if (tokenResponse.containsKey('access_token')) {
                return (String) tokenResponse.get('access_token');
            } else {
                throw new CalloutException('OAuth token response missing access_token: ' + res.getBody());
            }
        } else {
            throw new CalloutException('OAuth token request failed: ' + res.getStatusCode() + ' - ' + res.getStatus() + ' - ' + res.getBody());
        }
    }
}