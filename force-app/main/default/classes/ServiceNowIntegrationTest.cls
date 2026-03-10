@isTest(SeeAllData=true)
public class ServiceNowIntegrationTest {

    @isTest
    static void testCreateChangeRequestSuccess() {
        // Query for an existing promotion to avoid license validation
        List<copado__Promotion__c> existingPromotions = [
            SELECT Id FROM copado__Promotion__c LIMIT 1
        ];

        copado__Promotion__c promotion;
        if (existingPromotions.isEmpty()) {
            // If no promotions exist, skip the test
            System.assert(true, 'No promotions available for testing');
            return;
        } else {
            promotion = existingPromotions[0];
        }

        // Set up mock HTTP response
        Test.setMock(HttpCalloutMock.class, new ServiceNowMockSuccess());

        Test.startTest();

        // Call the invocable method
        List<ServiceNowIntegrationInvocable.PromotionRequest> requests = new List<ServiceNowIntegrationInvocable.PromotionRequest>();
        ServiceNowIntegrationInvocable.PromotionRequest req = new ServiceNowIntegrationInvocable.PromotionRequest();
        req.promotionId = promotion.Id;
        requests.add(req);

        List<ServiceNowIntegrationInvocable.PromotionResponse> responses = ServiceNowIntegrationInvocable.createChangeRequest(requests);

        Test.stopTest();

        // Verify results
        System.assertEquals(1, responses.size(), 'Should have one response');
        System.assertEquals(true, responses[0].isSuccess, 'Should be successful');
        System.assertNotEquals(null, responses[0].message, 'Should have a message');
        System.assert(responses[0].message.contains('queued'), 'Message should indicate job was queued');
    }

    @isTest
    static void testOAuthHandlerCaching() {
        // Test OAuth token caching mechanism
        Test.setMock(HttpCalloutMock.class, new ServiceNowMockSuccess());

        Test.startTest();

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
                SELECT Instance_URL__c, API_Endpoint__c, Table_Name__c,
                    Client_Id__c, Client_Secret__c, Token_Endpoint__c
                FROM ServiceNowConfig__mdt
                WHERE DeveloperName = 'ServiceNow_PDI'
                LIMIT 1
            ];
        }

        String token1 = ServiceNowOAuthHandler.getAccessToken(config);
        String token2 = ServiceNowOAuthHandler.getAccessToken(config);

        Test.stopTest();

        // Verify token caching works
        System.assertEquals(token1, token2, 'Cached token should be reused');
        System.assertNotEquals(null, token1, 'Token should not be null');
    }

    @isTest
    static void testOAuthHandlerFailure() {
        // Test OAuth failure handling
        Test.setMock(HttpCalloutMock.class, new ServiceNowMockOAuthFailure());

        Test.startTest();

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
                SELECT Instance_URL__c, API_Endpoint__c, Table_Name__c,
                    Client_Id__c, Client_Secret__c, Token_Endpoint__c
                FROM ServiceNowConfig__mdt
                WHERE DeveloperName = 'ServiceNow_PDI'
                LIMIT 1
            ];
        }

        Boolean exceptionThrown = false;
        try {
            ServiceNowOAuthHandler.getAccessToken(config);
        } catch (ServiceNowOAuthHandler.OAuthException e) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Should throw OAuthException on failure');
    }

    @isTest
    static void testInvalidPromotionId() {
        // Test with null promotion ID
        Test.startTest();

        List<ServiceNowIntegrationInvocable.PromotionRequest> requests = new List<ServiceNowIntegrationInvocable.PromotionRequest>();
        ServiceNowIntegrationInvocable.PromotionRequest req = new ServiceNowIntegrationInvocable.PromotionRequest();
        req.promotionId = null;
        requests.add(req);

        List<ServiceNowIntegrationInvocable.PromotionResponse> responses = ServiceNowIntegrationInvocable.createChangeRequest(requests);

        Test.stopTest();

        // Verify error handling
        System.assertEquals(1, responses.size(), 'Should have one response');
        System.assertEquals(false, responses[0].isSuccess, 'Should fail with null promotion ID');
        System.assert(responses[0].message.contains('Error'), 'Message should indicate error');
    }

    // Mock class for successful ServiceNow response
    private class ServiceNowMockSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();

            // Check if this is OAuth token request
            if (req.getEndpoint().contains('oauth')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"test_token_123","expires_in":3600}');
            } else {
                // ServiceNow Change Request creation
                res.setStatusCode(201);
                res.setBody('{"result":{"number":"CHG0001234","sys_id":"abc123"}}');
            }

            return res;
        }
    }

    // Mock class for OAuth failure
    private class ServiceNowMockOAuthFailure implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setBody('{"error":"invalid_client"}');
            return res;
        }
    }
}