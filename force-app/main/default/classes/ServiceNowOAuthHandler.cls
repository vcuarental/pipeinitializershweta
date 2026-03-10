/**
 * @description Handles OAuth authentication with ServiceNow
 * Uses client_credentials grant type
 * @author Copado Integration Team
 * @date 2026-02-26
 */
public class ServiceNowOAuthHandler {

    private static String cachedToken;
    private static DateTime tokenExpiry;

    /**
     * @description Gets OAuth access token from ServiceNow
     * Uses cached token if still valid
     * @param config ServiceNow configuration from Custom Metadata
     * @return OAuth access token
     */
    public static String getAccessToken(ServiceNowConfig__mdt config) {
        // Check if we have a valid cached token
        if (cachedToken != null && tokenExpiry != null && DateTime.now() < tokenExpiry) {
            System.debug('🔑 Using cached OAuth token');
            return cachedToken;
        }

        // Request new token
        String tokenEndpoint = config.Instance_URL__c + config.Token_Endpoint__c;

        System.debug('🔑 Requesting OAuth token from: ' + tokenEndpoint);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(tokenEndpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        // Use client_credentials grant type
        String body = 'grant_type=client_credentials' +
                     '&client_id=' + EncodingUtil.urlEncode(config.Client_Id__c, 'UTF-8') +
                     '&client_secret=' + EncodingUtil.urlEncode(config.Client_Secret__c, 'UTF-8');

        req.setBody(body);

        Http http = new Http();
        HttpResponse res = http.send(req);

        System.debug('📡 OAuth Response Status: ' + res.getStatusCode());

        if (res.getStatusCode() == 200) {
            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            cachedToken = (String) responseBody.get('access_token');

            // Handle expires_in as either Integer or String
            Integer expiresIn;
            Object expiresInObj = responseBody.get('expires_in');
            if (expiresInObj instanceof Integer) {
                expiresIn = (Integer) expiresInObj;
            } else if (expiresInObj instanceof String) {
                expiresIn = Integer.valueOf((String) expiresInObj);
            } else {
                expiresIn = 3600; // Default to 1 hour
            }

            // Set expiry time (subtract 60 seconds for safety margin)
            tokenExpiry = DateTime.now().addSeconds(expiresIn - 60);

            System.debug('✅ OAuth token obtained successfully');
            System.debug('⏰ Token expires in: ' + expiresIn + ' seconds');

            return cachedToken;
        } else {
            String errorMessage = 'Failed to get OAuth token. Status: ' + res.getStatusCode() + ', Body: ' + res.getBody();
            System.debug('❌ ' + errorMessage);
            throw new OAuthException(errorMessage);
        }
    }

    /**
     * @description Custom exception for OAuth errors
     */
    public class OAuthException extends Exception {}
}