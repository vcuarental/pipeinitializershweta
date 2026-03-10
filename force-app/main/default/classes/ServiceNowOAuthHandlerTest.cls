/**
 * @description Test class for ServiceNowOAuthHandler
 */
@IsTest
private class ServiceNowOAuthHandlerTest {

    @TestVisible
    private static ServiceNowConfig__mdt testConfig;

    @TestSetup
    static void setupTestConfig() {
        // Test config is set in each test method
    }

    @IsTest
    static void testGetAccessTokenSuccess() {
        // Set up test configuration
        ServiceNowConfig__mdt config = createTestConfig();

        // Set up mock response
        Test.setMock(HttpCalloutMock.class, new ServiceNowOAuthMock(200, true));

        Test.startTest();
        String token = ServiceNowOAuthHandler.getAccessToken(config);
        Test.stopTest();

        System.assertNotEquals(null, token, 'Token should not be null');
        System.assertEquals('mock_access_token_12345', token, 'Token should match mock value');
    }

    @IsTest
    static void testGetAccessTokenCached() {
        ServiceNowConfig__mdt config = createTestConfig();
        Test.setMock(HttpCalloutMock.class, new ServiceNowOAuthMock(200, true));

        Test.startTest();
        String token1 = ServiceNowOAuthHandler.getAccessToken(config);
        String token2 = ServiceNowOAuthHandler.getAccessToken(config);
        Test.stopTest();

        System.assertEquals(token1, token2, 'Cached token should be returned');
    }

    @IsTest
    static void testGetAccessTokenFailure() {
        ServiceNowConfig__mdt config = createTestConfig();
        Test.setMock(HttpCalloutMock.class, new ServiceNowOAuthMock(401, false));

        Test.startTest();
        try {
            ServiceNowOAuthHandler.getAccessToken(config);
            System.assert(false, 'Exception should have been thrown');
        } catch (ServiceNowOAuthHandler.OAuthException e) {
            System.assert(e.getMessage().contains('Failed to get OAuth token'),
                         'Exception message should indicate OAuth failure');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetAccessTokenWithStringExpiresIn() {
        ServiceNowConfig__mdt config = createTestConfig();
        Test.setMock(HttpCalloutMock.class, new ServiceNowOAuthMock(200, true, true));

        Test.startTest();
        String token = ServiceNowOAuthHandler.getAccessToken(config);
        Test.stopTest();

        System.assertNotEquals(null, token, 'Token should not be null even with string expires_in');
    }

    /**
     * @description Helper method to create test configuration
     */
    private static ServiceNowConfig__mdt createTestConfig() {
        ServiceNowConfig__mdt config = new ServiceNowConfig__mdt(
            Client_Id__c = 'test_client_id',
            Client_Secret__c = 'test_client_secret',
            Instance_URL__c = 'https://test.service-now.com',
            Token_Endpoint__c = '/oauth_token.do',
            API_Endpoint__c = '/api/now/table',
            Table_Name__c = 'change_request'
        );
        return config;
    }

    /**
     * @description Mock class for OAuth HTTP callouts
     */
    private class ServiceNowOAuthMock implements HttpCalloutMock {
        private Integer statusCode;
        private Boolean isSuccess;
        private Boolean useStringExpiresIn;

        public ServiceNowOAuthMock(Integer statusCode, Boolean isSuccess) {
            this(statusCode, isSuccess, false);
        }

        public ServiceNowOAuthMock(Integer statusCode, Boolean isSuccess, Boolean useStringExpiresIn) {
            this.statusCode = statusCode;
            this.isSuccess = isSuccess;
            this.useStringExpiresIn = useStringExpiresIn;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);

            if (isSuccess) {
                String responseBody;
                if (useStringExpiresIn) {
                    responseBody = '{"access_token":"mock_access_token_12345","expires_in":"3600","token_type":"Bearer"}';
                } else {
                    responseBody = '{"access_token":"mock_access_token_12345","expires_in":3600,"token_type":"Bearer"}';
                }
                res.setBody(responseBody);
            } else {
                res.setBody('{"error":"invalid_client","error_description":"Invalid credentials"}');
            }

            return res;
        }
    }
}