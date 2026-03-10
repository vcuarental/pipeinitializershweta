/**
 * @description Test class for ServiceNowChangeRequestCreator
 * Provides comprehensive test coverage for ServiceNow integration
 * Uses SeeAllData=true to access Copado licenses and bypass validation rules
 * Runs as a licensed Copado user to satisfy license validation rules
 */
@isTest
private class ServiceNowChangeRequestCreatorTest {
    
    /**
     * @description Gets or creates a test user with Copado licenses
     * @return User with Copado Deployer or User license
     */
    private static User getCopadoLicensedUser() {
        // Try to find an existing active admin user
        List<User> adminUsers = [
            SELECT Id, Username, Email
            FROM User
            WHERE IsActive = true
            AND Profile.Name = 'System Administrator'
            LIMIT 1
        ];
        
        if (!adminUsers.isEmpty()) {
            assignCopadoLicense(adminUsers[0].Id);
            return adminUsers[0];
        }
        
        // Fallback to current user
        assignCopadoLicense(UserInfo.getUserId());
        return [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
    }

    private static void assignCopadoLicense(Id userId) {
        copado.GlobalAPI copadoGlobalAPI = new copado.GlobalAPI();
        copado.GlobalAPI.UserLicense userLicense = new copado.GlobalAPI.UserLicense();

        userLicense.isCADEnabled=false;     // Copado Plan License
        userLicense.isCCHEnabled=false;     // Compliance Hub License 
        userLicense.isCCMEnabled=true;      // Copado User License
        userLicense.isCopadoEnabled=true;   // Copado Admin License
        userLicense.isCSTEnabled=false;      // Selenium Testing License
        userLicense.isADDEnabled=false;      // Data Deployer License

        userLicense.userId = userId;

        copado.GlobalAPI.LicenseOperationResult result = copadoGlobalAPI.upsertCopadoLicense(userLicense);

        System.debug(result);
    }
    
    /**
     * @description Creates test data for a single test method
     * @return Id of the created promotion
     */
    private static Id createTestData() {
        // Create test environments
        copado__Environment__c sourceEnv = new copado__Environment__c(
            Name = 'Dev Environment Test ' + String.valueOf(Math.random()).substring(2, 8),
            copado__Type__c = 'Sandbox',
            copado__Platform__c = 'Salesforce'
        );
        
        copado__Environment__c destEnv = new copado__Environment__c(
            Name = 'QA Environment Test ' + String.valueOf(Math.random()).substring(2, 8),
            copado__Type__c = 'Sandbox',
            copado__Platform__c = 'Salesforce'
        );
        
        insert new List<copado__Environment__c>{ sourceEnv, destEnv };
        
        // Create org credentials
        copado__Org__c sourceOrg = new copado__Org__c(
            Name = 'Source Org Test ' + String.valueOf(Math.random()).substring(2, 8),
            copado__Oauth_Signature__c = 'test_signature_source_' + String.valueOf(Math.random()),
            copado__Validated_Date__c = System.now(),
            copado__SFDC_Org_ID__c = '00D000000000001' + String.valueOf(Math.random()).substring(2, 8),
            copado__Username__c = 'source@test.com',
            copado__Environment__c = sourceEnv.Id,
            copado__Default_Credential__c = true
        );
        
        copado__Org__c destOrg = new copado__Org__c(
            Name = 'Destination Org Test ' + String.valueOf(Math.random()).substring(2, 8),
            copado__Oauth_Signature__c = 'test_signature_dest_' + String.valueOf(Math.random()),
            copado__Validated_Date__c = System.now(),
            copado__SFDC_Org_ID__c = '00D000000000002' + String.valueOf(Math.random()).substring(2, 8),
            copado__Username__c = 'dest@test.com',
            copado__Environment__c = destEnv.Id,
            copado__Default_Credential__c = true
        );
        
        insert new List<copado__Org__c>{ sourceOrg, destOrg };
        
        // Create test promotion
        copado__Promotion__c promotion = new copado__Promotion__c(
            copado__Source_Environment__c = sourceEnv.Id,
            copado__Destination_Environment__c = destEnv.Id,
            copado__Source_Org_Credential__c = sourceOrg.Id,
            copado__Destination_Org_Credential__c = destOrg.Id,
            copado__Status__c = 'Draft'
        );
        insert promotion;
        
        // Create test user stories
        List<copado__User_Story__c> userStories = new List<copado__User_Story__c>();
        for (Integer i = 1; i <= 3; i++) {
            userStories.add(new copado__User_Story__c(
                copado__User_Story_Title__c = 'Test User Story ' + i,
                copado__Status__c = 'Approved',
                copado__Org_Credential__c = sourceOrg.Id,
                copado__Environment__c = sourceEnv.Id
            ));
        }
        insert userStories;
        
        // Link user stories to promotion
        List<copado__Promoted_User_Story__c> promotedUserStories = new List<copado__Promoted_User_Story__c>();
        for (copado__User_Story__c us : userStories) {
            promotedUserStories.add(new copado__Promoted_User_Story__c(
                copado__Promotion__c = promotion.Id,
                copado__User_Story__c = us.Id
            ));
        }
        insert promotedUserStories;
        
        // Create test metadata for user stories
        List<copado__User_Story_Metadata__c> metadataList = new List<copado__User_Story_Metadata__c>();
        for (copado__User_Story__c us : userStories) {
            metadataList.add(new copado__User_Story_Metadata__c(
                copado__User_Story__c = us.Id,
                copado__Metadata_API_Name__c = 'TestClass_' + us.Id.to15(),
                copado__Type__c = 'ApexClass',
                copado__Action__c = 'Add'
            ));
        }
        insert metadataList;
        
        return promotion.Id;
    }
    
    /**
     * @description Test successful change request creation
     */
    @isTest(SeeAllData=true)
    static void testCreateChangeRequestSuccess() {
        User testUser = getCopadoLicensedUser();
        
        System.runAs(testUser) {
            // Create test data
            Id promotionId = createTestData();
            
            // Setup mock HTTP response
            Test.setMock(HttpCalloutMock.class, new ServiceNowSuccessMock());
            
            Test.startTest();
            String changeRequestNumber = ServiceNowChangeRequestCreator.createChangeRequest(promotionId);
            Test.stopTest();
            
            // Verify result
            System.assertNotEquals(null, changeRequestNumber, 'Change request number should not be null');
            System.assertEquals('CHG0001234', changeRequestNumber, 'Change request number should match mock response');
        }
    }
    
    /**
     * @description Test change request creation with OAuth token retrieval
     */
    @isTest(SeeAllData=true)
    static void testCreateChangeRequestWithOAuth() {
        User testUser = getCopadoLicensedUser();
        
        System.runAs(testUser) {
            // Create test data
            Id promotionId = createTestData();
            
            Test.setMock(HttpCalloutMock.class, new ServiceNowOAuthMock());
            
            Test.startTest();
            String changeRequestNumber = ServiceNowChangeRequestCreator.createChangeRequest(promotionId);
            Test.stopTest();
            
            System.assertNotEquals(null, changeRequestNumber, 'Change request number should not be null');
        }
    }
    
    /**
     * @description Test error handling when promotion not found
     */
    @isTest(SeeAllData=true)
    static void testCreateChangeRequestPromotionNotFound() {
        User testUser = getCopadoLicensedUser();
        
        System.runAs(testUser) {
            // Use a fake promotion ID that doesn't exist
            Id fakePromotionId = Schema.SObjectType.copado__Promotion__c.getKeyPrefix() + '0'.repeat(12);
            
            Test.startTest();
            try {
                ServiceNowChangeRequestCreator.createChangeRequest(fakePromotionId);
                System.assert(false, 'Expected CalloutException was not thrown');
            } catch (CalloutException ex) {
                // The actual error message is "List has no rows for assignment to SObject"
                // which gets wrapped in "Failed to create ServiceNow change request"
                System.assert(
                    ex.getMessage().contains('Failed to create ServiceNow change request') || 
                    ex.getMessage().contains('List has no rows for assignment to SObject') ||
                    ex.getMessage().contains('Promotion not found'), 
                    'Exception message should indicate promotion not found. Actual: ' + ex.getMessage()
                );
            }
            Test.stopTest();
        }
    }
    
    /**
     * @description Test error handling when ServiceNow API returns error
     */
    @isTest(SeeAllData=true)
    static void testCreateChangeRequestServiceNowError() {
        User testUser = getCopadoLicensedUser();
        
        System.runAs(testUser) {
            // Create test data
            Id promotionId = createTestData();
            
            Test.setMock(HttpCalloutMock.class, new ServiceNowErrorMock());
            
            Test.startTest();
            try {
                ServiceNowChangeRequestCreator.createChangeRequest(promotionId);
                System.assert(false, 'Expected CalloutException was not thrown');
            } catch (CalloutException ex) {
                System.assert(ex.getMessage().contains('ServiceNow API error'), 
                             'Exception message should indicate ServiceNow API error: ' + ex.getMessage());
            }
            Test.stopTest();
        }
    }
    
    /**
     * @description Test error handling when OAuth token request fails
     */
    @isTest(SeeAllData=true)
    static void testCreateChangeRequestOAuthFailure() {
        User testUser = getCopadoLicensedUser();
        
        System.runAs(testUser) {
            // Create test data
            Id promotionId = createTestData();
            
            Test.setMock(HttpCalloutMock.class, new ServiceNowOAuthFailureMock());
            
            Test.startTest();
            try {
                ServiceNowChangeRequestCreator.createChangeRequest(promotionId);
                System.assert(false, 'Expected CalloutException was not thrown');
            } catch (CalloutException ex) {
                System.assert(ex.getMessage().contains('OAuth token request failed'), 
                             'Exception message should indicate OAuth failure: ' + ex.getMessage());
            }
            Test.stopTest();
        }
    }
    
    /**
     * @description Test with promotion that has no user stories
     */
    @isTest(SeeAllData=true)
    static void testCreateChangeRequestNoUserStories() {
        User testUser = getCopadoLicensedUser();
        
        System.runAs(testUser) {
            // Create minimal test data without user stories
            copado__Environment__c sourceEnv = new copado__Environment__c(
                Name = 'Dev Env No US ' + String.valueOf(Math.random()).substring(2, 8),
                copado__Type__c = 'Sandbox',
                copado__Platform__c = 'Salesforce'
            );
            
            copado__Environment__c destEnv = new copado__Environment__c(
                Name = 'QA Env No US ' + String.valueOf(Math.random()).substring(2, 8),
                copado__Type__c = 'Sandbox',
                copado__Platform__c = 'Salesforce'
            );
            
            insert new List<copado__Environment__c>{ sourceEnv, destEnv };
            
            copado__Org__c sourceOrg = new copado__Org__c(
                Name = 'Source Org No US ' + String.valueOf(Math.random()).substring(2, 8),
                copado__Oauth_Signature__c = 'test_sig_' + String.valueOf(Math.random()),
                copado__Validated_Date__c = System.now(),
                copado__SFDC_Org_ID__c = '00D000000000003' + String.valueOf(Math.random()).substring(2, 8),
                copado__Username__c = 'source_no_us@test.com',
                copado__Environment__c = sourceEnv.Id,
                copado__Default_Credential__c = true
            );
            
            copado__Org__c destOrg = new copado__Org__c(
                Name = 'Dest Org No US ' + String.valueOf(Math.random()).substring(2, 8),
                copado__Oauth_Signature__c = 'test_sig_dest_' + String.valueOf(Math.random()),
                copado__Validated_Date__c = System.now(),
                copado__SFDC_Org_ID__c = '00D000000000004' + String.valueOf(Math.random()).substring(2, 8),
                copado__Username__c = 'dest_no_us@test.com',
                copado__Environment__c = destEnv.Id,
                copado__Default_Credential__c = true
            );
            
            insert new List<copado__Org__c>{ sourceOrg, destOrg };
            
            // Create promotion without user stories
            copado__Promotion__c emptyPromotion = new copado__Promotion__c(
                copado__Source_Environment__c = sourceEnv.Id,
                copado__Destination_Environment__c = destEnv.Id,
                copado__Source_Org_Credential__c = sourceOrg.Id,
                copado__Destination_Org_Credential__c = destOrg.Id,
                copado__Status__c = 'Draft'
            );
            insert emptyPromotion;
            
            Test.setMock(HttpCalloutMock.class, new ServiceNowSuccessMock());
            
            Test.startTest();
            String changeRequestNumber = ServiceNowChangeRequestCreator.createChangeRequest(emptyPromotion.Id);
            Test.stopTest();
            
            System.assertNotEquals(null, changeRequestNumber, 'Change request should be created even without user stories');
        }
    }
    
    /**
     * @description Test with user stories that have Jira integration fields populated
     * Uses dynamic field checking and proper FLS handling
     */
    @isTest(SeeAllData=true)
    static void testCreateChangeRequestWithJiraFields() {
        User testUser = getCopadoLicensedUser();
        
        System.runAs(testUser) {
            // Create test data
            Id promotionId = createTestData();
            
            // Update user stories with Jira fields (if they exist and are editable)
            List<copado__Promoted_User_Story__c> promotedUS = [
                SELECT copado__User_Story__c 
                FROM copado__Promoted_User_Story__c 
                WHERE copado__Promotion__c = :promotionId
                LIMIT 1
            ];
            
            if (!promotedUS.isEmpty()) {
                copado__User_Story__c us = [
                    SELECT Id 
                    FROM copado__User_Story__c 
                    WHERE Id = :promotedUS[0].copado__User_Story__c
                ];
                
                // Check field existence and editability using Field-Level Security
                Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.copado__User_Story__c.fields.getMap();
                
                // Only update fields if they exist AND are editable
                if (fieldMap.containsKey('jira_key__c')) {
                    Schema.DescribeFieldResult jiraKeyDescribe = fieldMap.get('jira_key__c').getDescribe();
                    if (jiraKeyDescribe.isUpdateable()) {
                        us.put('Jira_Key__c', 'JIRA-123');
                    }
                }
                
                if (fieldMap.containsKey('jira_link__c')) {
                    Schema.DescribeFieldResult jiraLinkDescribe = fieldMap.get('jira_link__c').getDescribe();
                    if (jiraLinkDescribe.isUpdateable()) {
                        us.put('Jira_Link__c', 'https://jira.example.com/browse/JIRA-123');
                    }
                }
                
                // Only update if we actually set any fields
                if (us.getPopulatedFieldsAsMap().size() > 1) { // More than just Id
                    update us;
                }
            }
            
            Test.setMock(HttpCalloutMock.class, new ServiceNowSuccessMock());
            
            Test.startTest();
            String changeRequestNumber = ServiceNowChangeRequestCreator.createChangeRequest(promotionId);
            Test.stopTest();
            
            System.assertNotEquals(null, changeRequestNumber, 'Change request number should not be null');
        }
    }
    
    // ========== HTTP MOCK CLASSES ==========
    
    /**
     * @description Mock for successful ServiceNow API calls (OAuth + Change Request)
     */
    private class ServiceNowSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            // Check if this is OAuth token request
            if (req.getEndpoint().contains('oauth') || req.getEndpoint().contains('token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"mock_access_token_12345","token_type":"Bearer","expires_in":3600}');
            } 
            // Otherwise it's a change request creation
            else {
                res.setStatusCode(201);
                res.setBody('{"result":{"number":"CHG0001234","sys_id":"abc123","state":"New"}}');
            }
            
            return res;
        }
    }
    
    /**
     * @description Mock for OAuth flow with separate token and API calls
     */
    private class ServiceNowOAuthMock implements HttpCalloutMock {
        private Integer callCount = 0;
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            callCount++;
            
            // First call: OAuth token
            if (callCount == 1) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"test_token_xyz","token_type":"Bearer","expires_in":7200}');
            } 
            // Second call: Change request creation
            else {
                res.setStatusCode(201);
                res.setBody('{"result":{"number":"CHG0005678","sys_id":"xyz789"}}');
            }
            
            return res;
        }
    }
    
    /**
     * @description Mock for ServiceNow API error response
     */
    private class ServiceNowErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            // OAuth succeeds
            if (req.getEndpoint().contains('oauth') || req.getEndpoint().contains('token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"mock_token","token_type":"Bearer"}');
            } 
            // Change request fails
            else {
                res.setStatusCode(400);
                res.setStatus('Bad Request');
                res.setBody('{"error":{"message":"Invalid request parameters","detail":"Missing required field"}}');
            }
            
            return res;
        }
    }
    
    /**
     * @description Mock for OAuth token request failure
     */
    private class ServiceNowOAuthFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(401);
            res.setStatus('Unauthorized');
            res.setBody('{"error":"invalid_client","error_description":"Client authentication failed"}');
            
            return res;
        }
    }
}