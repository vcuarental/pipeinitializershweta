/**
 * @description Comprehensive test class for ServiceNowAutomationConnector
 * Achieves >75% code coverage with proper test data setup
 */
@IsTest(SeeAllData=true)
private class ServiceNowAutomationConnectorTest {

    /**
     * @description Gets or creates a test user with Copado licenses
     */
    private static User getCopadoLicensedUser() {
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

        assignCopadoLicense(UserInfo.getUserId());
        return [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
    }

    private static void assignCopadoLicense(Id userId) {
        copado.GlobalAPI copadoGlobalAPI = new copado.GlobalAPI();
        copado.GlobalAPI.UserLicense userLicense = new copado.GlobalAPI.UserLicense();

        userLicense.isCADEnabled = false;
        userLicense.isCCHEnabled = false;
        userLicense.isCCMEnabled = true;
        userLicense.isCopadoEnabled = true;
        userLicense.isCSTEnabled = false;
        userLicense.isADDEnabled = false;
        userLicense.userId = userId;

        copado.GlobalAPI.LicenseOperationResult result = copadoGlobalAPI.upsertCopadoLicense(userLicense);
        System.debug('License assignment result: ' + result);
    }

    /**
     * @description Creates comprehensive test data
     */
    private static Id createTestPromotion() {
        // Create environments
        copado__Environment__c sourceEnv = new copado__Environment__c(
            Name = 'Test Source Env ' + String.valueOf(Math.random()).substring(2, 8),
            copado__Type__c = 'Sandbox',
            copado__Platform__c = 'Salesforce'
        );

        copado__Environment__c destEnv = new copado__Environment__c(
            Name = 'Test Dest Env ' + String.valueOf(Math.random()).substring(2, 8),
            copado__Type__c = 'Sandbox',
            copado__Platform__c = 'Salesforce'
        );

        insert new List<copado__Environment__c>{ sourceEnv, destEnv };

        // Create org credentials
        copado__Org__c sourceOrg = new copado__Org__c(
            Name = 'Test Source Org ' + String.valueOf(Math.random()).substring(2, 8),
            copado__Oauth_Signature__c = 'test_sig_' + String.valueOf(Math.random()),
            copado__Validated_Date__c = System.now(),
            copado__SFDC_Org_ID__c = '00D000000000001' + String.valueOf(Math.random()).substring(2, 8),
            copado__Username__c = 'testsource@example.com',
            copado__Environment__c = sourceEnv.Id,
            copado__Default_Credential__c = true
        );

        copado__Org__c destOrg = new copado__Org__c(
            Name = 'Test Dest Org ' + String.valueOf(Math.random()).substring(2, 8),
            copado__Oauth_Signature__c = 'test_sig_' + String.valueOf(Math.random()),
            copado__Validated_Date__c = System.now(),
            copado__SFDC_Org_ID__c = '00D000000000002' + String.valueOf(Math.random()).substring(2, 8),
            copado__Username__c = 'testdest@example.com',
            copado__Environment__c = destEnv.Id,
            copado__Default_Credential__c = true
        );

        insert new List<copado__Org__c>{ sourceOrg, destOrg };

        // Create promotion
        copado__Promotion__c promotion = new copado__Promotion__c(
            copado__Source_Environment__c = sourceEnv.Id,
            copado__Destination_Environment__c = destEnv.Id,
            copado__Source_Org_Credential__c = sourceOrg.Id,
            copado__Destination_Org_Credential__c = destOrg.Id,
            copado__Status__c = 'Draft'
        );
        insert promotion;

        // Create user stories
        List<copado__User_Story__c> userStories = new List<copado__User_Story__c>();
        for (Integer i = 1; i <= 2; i++) {
            userStories.add(new copado__User_Story__c(
                copado__User_Story_Title__c = 'Test Story ' + i,
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

        // Create metadata
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
     * @description Test execute method with valid promotion
     */
    @IsTest
    static void testExecute_Success() {
        User testUser = getCopadoLicensedUser();

        System.runAs(testUser) {
            Id promotionId = createTestPromotion();

            Test.setMock(HttpCalloutMock.class, new ServiceNowSuccessMock());

            Test.startTest();
            String changeRequestNumber = ServiceNowAutomationConnector.execute(promotionId);
            Test.stopTest();

            System.assertNotEquals(null, changeRequestNumber, 'Change Request number should not be null');
            System.assert(changeRequestNumber.startsWith('CHG'), 'Change Request should start with CHG');
        }
    }

    /**
     * @description Test execute method with invalid ID (not a Promotion)
     */
    @IsTest
    static void testExecute_InvalidId() {
        User testUser = getCopadoLicensedUser();

        System.runAs(testUser) {
            Id userId = UserInfo.getUserId();

            Test.startTest();
            Boolean exceptionThrown = false;
            try {
                ServiceNowAutomationConnector.execute(userId);
            } catch (ServiceNowAutomationConnector.AutomationException e) {
                exceptionThrown = true;
                System.assert(e.getMessage().contains('Invalid'), 'Expected invalid ID error');
            }
            Test.stopTest();

            System.assertEquals(true, exceptionThrown, 'Should have thrown AutomationException');
        }
    }

    /**
     * @description Test execute method with null ID
     */
    @IsTest
    static void testExecute_NullId() {
        User testUser = getCopadoLicensedUser();

        System.runAs(testUser) {
            Test.startTest();
            Boolean exceptionThrown = false;
            try {
                ServiceNowAutomationConnector.execute(null);
            } catch (ServiceNowAutomationConnector.AutomationException e) {
                exceptionThrown = true;
                System.assert(e.getMessage().contains('Invalid'), 'Expected invalid ID error');
            }
            Test.stopTest();

            System.assertEquals(true, exceptionThrown, 'Should have thrown AutomationException');
        }
    }

    /**
     * @description Test invocable method with success
     */
    @IsTest
    static void testInvocableMethod_Success() {
        User testUser = getCopadoLicensedUser();

        System.runAs(testUser) {
            Id promotionId = createTestPromotion();

            ServiceNowAutomationConnector.Request req = new ServiceNowAutomationConnector.Request();
            req.promotionId = promotionId;

            Test.setMock(HttpCalloutMock.class, new ServiceNowSuccessMock());

            Test.startTest();
            List<ServiceNowAutomationConnector.Result> results =
                ServiceNowAutomationConnector.createChangeRequest(new List<ServiceNowAutomationConnector.Request>{req});
            Test.stopTest();

            System.assertEquals(1, results.size(), 'Should have 1 result');
            System.assertEquals(true, results[0].success, 'Should be successful');
            System.assertNotEquals(null, results[0].changeRequestNumber, 'Should have change request number');
            System.assertEquals(null, results[0].errorMessage, 'Should have no error');
        }
    }

    /**
     * @description Test invocable method with failure
     */
    @IsTest
    static void testInvocableMethod_Failure() {
        User testUser = getCopadoLicensedUser();

        System.runAs(testUser) {
            Id promotionId = createTestPromotion();

            ServiceNowAutomationConnector.Request req = new ServiceNowAutomationConnector.Request();
            req.promotionId = promotionId;

            Test.setMock(HttpCalloutMock.class, new ServiceNowFailureMock());

            Test.startTest();
            List<ServiceNowAutomationConnector.Result> results =
                ServiceNowAutomationConnector.createChangeRequest(new List<ServiceNowAutomationConnector.Request>{req});
            Test.stopTest();

            System.assertEquals(1, results.size(), 'Should have 1 result');
            System.assertEquals(false, results[0].success, 'Should be unsuccessful');
            System.assertEquals(null, results[0].changeRequestNumber, 'Should have no change request number');
            System.assertNotEquals(null, results[0].errorMessage, 'Should have error message');
        }
    }

    /**
     * @description Test invocable method with multiple requests
     */
    @IsTest
    static void testInvocableMethod_MultipleRequests() {
        User testUser = getCopadoLicensedUser();

        System.runAs(testUser) {
            Id promotionId1 = createTestPromotion();
            Id promotionId2 = createTestPromotion();

            ServiceNowAutomationConnector.Request req1 = new ServiceNowAutomationConnector.Request();
            req1.promotionId = promotionId1;

            ServiceNowAutomationConnector.Request req2 = new ServiceNowAutomationConnector.Request();
            req2.promotionId = promotionId2;

            Test.setMock(HttpCalloutMock.class, new ServiceNowSuccessMock());

            Test.startTest();
            List<ServiceNowAutomationConnector.Result> results =
                ServiceNowAutomationConnector.createChangeRequest(new List<ServiceNowAutomationConnector.Request>{req1, req2});
            Test.stopTest();

            System.assertEquals(2, results.size(), 'Should have 2 results');
            System.assertEquals(true, results[0].success, 'First should be successful');
            System.assertEquals(true, results[1].success, 'Second should be successful');
        }
    }

    /**
     * @description Test exception handling in execute method
     */
    @IsTest
    static void testExecute_ExceptionHandling() {
        User testUser = getCopadoLicensedUser();

        System.runAs(testUser) {
            Id promotionId = createTestPromotion();

            Test.setMock(HttpCalloutMock.class, new ServiceNowFailureMock());

            Test.startTest();
            Boolean exceptionThrown = false;
            try {
                ServiceNowAutomationConnector.execute(promotionId);
            } catch (Exception e) {
                exceptionThrown = true;
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message');
            }
            Test.stopTest();

            System.assertEquals(true, exceptionThrown, 'Should have thrown exception');
        }
    }

    // ========== HTTP MOCK CLASSES ==========

    /**
     * @description Mock for successful ServiceNow API calls
     */
    private class ServiceNowSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (req.getEndpoint().contains('oauth') || req.getEndpoint().contains('token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"test_token_123","expires_in":3600}');
            } else {
                res.setStatusCode(201);
                res.setBody('{"result":{"number":"CHG0030123","sys_id":"abc123"}}');
            }

            return res;
        }
    }

    /**
     * @description Mock for failed ServiceNow API calls
     */
    private class ServiceNowFailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (req.getEndpoint().contains('oauth') || req.getEndpoint().contains('token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"test_token_123","expires_in":3600}');
            } else {
                res.setStatusCode(401);
                res.setBody('{"error":{"message":"Authentication failed"}}');
            }

            return res;
        }
    }
}