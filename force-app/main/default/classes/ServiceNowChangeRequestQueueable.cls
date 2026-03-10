/**
 * @description Queueable implementation for ServiceNow Change Request creation
 * Handles OAuth authentication and API callout to ServiceNow
 * Optimized to avoid HTTP 431 errors by reducing payload size
 * @author Copado Integration Team
 * @date 2026-02-27
 */
global class ServiceNowChangeRequestQueueable implements Queueable, Database.AllowsCallouts {

    private Id promotionId;
    private static final Integer MAX_COMPONENTS = 200; // Limit components to avoid payload size issues

    /**
     * @description Constructor
     * @param promotionId The Promotion record ID
     */
    global ServiceNowChangeRequestQueueable(Id promotionId) {
        this.promotionId = promotionId;
    }

    /**
     * @description Execute method called by the queue
     * @param context Queueable context
     */
    global void execute(QueueableContext context) {
        try {
            System.debug('🔵 Queueable: Creating ServiceNow Change Request for Promotion: ' + promotionId);

            // Get ServiceNow configuration
            ServiceNowConfig__mdt config;
            
            if(Test.isRunningTest()) {
                config = new ServiceNowConfig__mdt();
                config.DeveloperName = 'ServiceNow_PDI';
                config.Instance_URL__c = 'https://testinstance.service-now.com';
                config.API_Endpoint__c = '/api/now/table/change_request';
                config.Table_Name__c = 'table_name';
                config.Client_Id__c = 'test_client_id';
                config.Client_Secret__c = 'test_client_secret';
                config.Token_Endpoint__c = '/oauth_token.do';
            } else {
                config = [
                    SELECT Instance_URL__c, Token_Endpoint__c, Client_Id__c, Client_Secret__c,
                           API_Endpoint__c, Table_Name__c
                    FROM ServiceNowConfig__mdt
                    WHERE DeveloperName = 'ServiceNow_PDI'
                    LIMIT 1
                ];
            }

            System.debug('📋 Config loaded: ' + config.Instance_URL__c);

            // Query Promotion with related User Stories
            copado__Promotion__c promotion = [
                SELECT Id, Name, CreatedDate, LastModifiedDate, copado__Status__c,
                       copado__Project__r.Name, copado__Release__r.Name,
                       copado__Source_Environment__r.Name, copado__Destination_Environment__r.Name,
                       (SELECT Id, copado__User_Story__c, copado__User_Story__r.Name,
                               copado__User_Story__r.copado__User_Story_Title__c,
                               copado__User_Story__r.Jira_Link__c
                        FROM copado__Promoted_User_Stories__r
                        ORDER BY copado__User_Story__r.Name)
                FROM copado__Promotion__c
                WHERE Id = :promotionId
                LIMIT 1
            ];

            System.debug('📦 Promotion loaded: ' + promotion.Name);
            System.debug('📊 User Stories count: ' + promotion.copado__Promoted_User_Stories__r.size());

            // Build User Stories section for DESCRIPTION field
            String description = buildUserStoriesDescription(promotion);
            System.debug('📝 Description length: ' + description.length() + ' characters');

            // Build Components section for COMMENTS field
            Set<Id> userStoryIds = new Set<Id>();
            for (copado__Promoted_User_Story__c pus : promotion.copado__Promoted_User_Stories__r) {
                userStoryIds.add(pus.copado__User_Story__c);
            }

            String comments = buildComponentsComments(userStoryIds);
            System.debug('💬 Comments length: ' + comments.length() + ' characters');

            // Build ServiceNow Change Request payload
            Map<String, Object> changeRequest = new Map<String, Object>();

            String shortDescription = 'Copado Production Promotion: ' + promotion.Name;
            changeRequest.put('short_description', shortDescription);
            changeRequest.put('description', description);
            changeRequest.put('comments', comments);
            changeRequest.put('state', '1'); // New
            changeRequest.put('priority', '3'); // Moderate
            changeRequest.put('risk', '3'); // Moderate
            changeRequest.put('impact', '3'); // Moderate
            changeRequest.put('type', 'Normal');

            // Add environment details
            changeRequest.put('u_source_environment', promotion.copado__Source_Environment__r?.Name);
            changeRequest.put('u_target_environment', promotion.copado__Destination_Environment__r?.Name);

            // Add planned dates
            changeRequest.put('start_date', formatDateTimeForServiceNow(promotion.CreatedDate));
            changeRequest.put('end_date', formatDateTimeForServiceNow(promotion.LastModifiedDate));

            String payloadJson = JSON.serialize(changeRequest);
            System.debug('📦 Payload size: ' + payloadJson.length() + ' characters');
            System.debug('📝 Payload preview (first 500 chars): ' + payloadJson.substring(0, Math.min(500, payloadJson.length())));

            // Get OAuth token
            String accessToken = ServiceNowOAuthHandler.getAccessToken(config);
            System.debug('🔑 OAuth token obtained (length: ' + accessToken.length() + ')');

            // Build complete endpoint
            String endpoint = config.Instance_URL__c + config.API_Endpoint__c + '/' + config.Table_Name__c;

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');
            req.setBody(payloadJson);
            req.setTimeout(120000);

            System.debug('🌐 Sending request to: ' + endpoint);
            System.debug('📏 Total request size estimate: ' + (payloadJson.length() + accessToken.length() + 200) + ' bytes');

            Http http = new Http();
            HttpResponse res = http.send(req);

            System.debug('📡 ServiceNow Response Status: ' + res.getStatusCode());
            System.debug('📄 ServiceNow Response Body: ' + res.getBody());

            if (res.getStatusCode() == 201) {
                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                Map<String, Object> result = (Map<String, Object>) responseBody.get('result');
                String changeRequestNumber = (String) result.get('number');

                System.debug('✅ SUCCESS: Change Request ' + changeRequestNumber + ' created');

                // Update Promotion with CHG number
                copado__Promotion__c promoToUpdate = new copado__Promotion__c(
                    Id = promotionId,
                    ServiceNow_Change_Request__c = changeRequestNumber
                );
                update promoToUpdate;

                System.debug('✅ Promotion updated with CHG number: ' + changeRequestNumber);

            } else {
                String errorMsg = 'ServiceNow API returned status ' + res.getStatusCode() + ': ' + res.getBody();
                System.debug('❌ ERROR: ' + errorMsg);
                throw new ServiceNowException(errorMsg);
            }

        } catch (Exception e) {
            System.debug('❌ EXCEPTION: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            sendErrorNotification(promotionId, e.getMessage());
            throw e;
        }
    }

    /**
     * @description Builds User Stories description for ServiceNow Description field
     * Format: PROMOTION DETAILS first, then User Story Number + Title + Jira Link
     * @param promotion Promotion record with User Stories
     * @return Formatted description string
     */
    private String buildUserStoriesDescription(copado__Promotion__c promotion) {
        String description = '=== PROMOTION DETAILS ===\n';
        description += 'Promotion: ' + promotion.Name + '\n';
        description += 'Project: ' + (promotion.copado__Project__r?.Name != null ? promotion.copado__Project__r.Name : 'N/A') + '\n';
        description += 'Release: ' + (promotion.copado__Release__r?.Name != null ? promotion.copado__Release__r.Name : 'N/A') + '\n';
        description += 'Source: ' + (promotion.copado__Source_Environment__r?.Name != null ? promotion.copado__Source_Environment__r.Name : 'N/A') + '\n';
        description += 'Target: ' + (promotion.copado__Destination_Environment__r?.Name != null ? promotion.copado__Destination_Environment__r.Name : 'N/A') + '\n';
        description += 'Status: ' + (promotion.copado__Status__c != null ? promotion.copado__Status__c : 'N/A') + '\n';

        description += '\n=== USER STORIES ===\n';

        if (promotion.copado__Promoted_User_Stories__r.isEmpty()) {
            description += '\nNo User Stories attached to this promotion.\n';
        } else {
            description += '\n';
            for (copado__Promoted_User_Story__c pus : promotion.copado__Promoted_User_Stories__r) {
                String userStoryName = pus.copado__User_Story__r.Name;
                String userStoryTitle = pus.copado__User_Story__r.copado__User_Story_Title__c != null
                    ? pus.copado__User_Story__r.copado__User_Story_Title__c
                    : 'No Title';

                String jiraUrl = extractUrlFromHtml(pus.copado__User_Story__r.Jira_Link__c);

                description += userStoryName + ': ' + userStoryTitle + '\n';

                if (String.isNotBlank(jiraUrl)) {
                    description += 'Jira: ' + jiraUrl + '\n';
                }

                description += '\n';
            }
        }

        return description;
    }

    /**
     * @description Builds components list for ServiceNow Comments field
     * Groups components by User Story
     * @param userStoryIds Set of User Story IDs
     * @return Formatted components string
     */
    private String buildComponentsComments(Set<Id> userStoryIds) {
        String comments = '=== COMPONENTS ===\n\n';

        if (userStoryIds.isEmpty()) {
            return 'No components found for this promotion.';
        }

        // Query metadata components
        List<copado__User_Story_Metadata__c> metadataRecords = [
            SELECT Id, copado__User_Story__c, copado__User_Story__r.Name,
                   copado__Metadata_API_Name__c, copado__Type__c, copado__Action__c
            FROM copado__User_Story_Metadata__c
            WHERE copado__User_Story__c IN :userStoryIds
            ORDER BY copado__User_Story__r.Name, copado__Type__c, copado__Metadata_API_Name__c
            LIMIT :MAX_COMPONENTS
        ];

        System.debug('🔧 Metadata components found: ' + metadataRecords.size());

        if (metadataRecords.isEmpty()) {
            return 'No metadata components found for this promotion.';
        }

        // Group components by User Story
        Map<String, List<copado__User_Story_Metadata__c>> componentsByUserStory = new Map<String, List<copado__User_Story_Metadata__c>>();

        for (copado__User_Story_Metadata__c metadata : metadataRecords) {
            String usName = metadata.copado__User_Story__r.Name;
            if (!componentsByUserStory.containsKey(usName)) {
                componentsByUserStory.put(usName, new List<copado__User_Story_Metadata__c>());
            }
            componentsByUserStory.get(usName).add(metadata);
        }

        // Build formatted output
        for (String userStoryName : componentsByUserStory.keySet()) {
            comments += '[' + userStoryName + ']\n';

            for (copado__User_Story_Metadata__c metadata : componentsByUserStory.get(userStoryName)) {
                comments += '  - ' + metadata.copado__Type__c + ': '
                          + metadata.copado__Metadata_API_Name__c;

                if (String.isNotBlank(metadata.copado__Action__c)) {
                    comments += ' (' + metadata.copado__Action__c + ')';
                }

                comments += '\n';
            }

            comments += '\n';
        }

        // Add note if components were truncated
        if (metadataRecords.size() >= MAX_COMPONENTS) {
            comments += '\n[Note: Component list limited to ' + MAX_COMPONENTS + ' items. View full list in Salesforce.]\n';
        }

        return comments;
    }

    /**
     * @description Extracts clean URL from HTML anchor tags
     * Handles formats like: <a href="URL" target="_blank">Text</a>
     * @param htmlString The HTML string containing the URL
     * @return Clean URL or empty string
     */
    private String extractUrlFromHtml(String htmlString) {
        if (String.isBlank(htmlString)) {
            return '';
        }

        // If no HTML tags, return as-is
        if (!htmlString.contains('<') && !htmlString.contains('>')) {
            return htmlString.trim();
        }

        // Extract URL from href attribute using regex
        // Pattern matches: href="URL" or href='URL'
        Pattern hrefPattern = Pattern.compile('href=["\']([^"\']+)["\']');
        Matcher hrefMatcher = hrefPattern.matcher(htmlString);

        if (hrefMatcher.find()) {
            return hrefMatcher.group(1);
        }

        // Fallback: strip all HTML tags
        return htmlString.replaceAll('<[^>]+>', '').trim();
    }

    /**
     * @description Formats DateTime for ServiceNow API
     * @param dt DateTime to format
     * @return Formatted string (yyyy-MM-dd HH:mm:ss)
     */
    private String formatDateTimeForServiceNow(DateTime dt) {
        if (dt == null) {
            return null;
        }
        return dt.format('yyyy-MM-dd HH:mm:ss', 'GMT');
    }

    /**
     * @description Sends error notification email
     * @param promotionId Promotion ID
     * @param errorMessage Error message
     */
    private void sendErrorNotification(Id promotionId, String errorMessage) {
        try {
            copado__Promotion__c promo = [
                SELECT Id, Name, copado__Project__r.Name, OwnerId, Owner.Email
                FROM copado__Promotion__c
                WHERE Id = :promotionId
                LIMIT 1
            ];

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[] { promo.Owner.Email });
            email.setSubject('ServiceNow Integration Error - ' + promo.Name);

            String emailBody = 'An error occurred while creating a ServiceNow Change Request.\n\n';
            emailBody += 'Promotion: ' + promo.Name + '\n';
            emailBody += 'Project: ' + (promo.copado__Project__r?.Name != null ? promo.copado__Project__r.Name : 'N/A') + '\n\n';
            emailBody += 'Error: ' + errorMessage + '\n\n';
            emailBody += 'Please check debug logs or manually create the Change Request.';

            email.setPlainTextBody(emailBody);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });

            System.debug('📧 Error notification sent to: ' + promo.Owner.Email);

        } catch (Exception e) {
            System.debug('❌ Failed to send error notification: ' + e.getMessage());
        }
    }

    global class ServiceNowException extends Exception {}
}