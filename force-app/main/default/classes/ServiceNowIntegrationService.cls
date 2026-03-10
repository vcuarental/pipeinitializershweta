public class ServiceNowIntegrationService {
    
    @future(callout=true)
    public static void createUserStoriesInServiceNow(List<Id> userStoryIds) {
        List<copado__User_Story__c> userStories = [
            SELECT Id, Name, copado__User_Story_Title__c, 
                   copado__Status__c, copado__Functional_Specifications__c,
                   copadoconnect__External_Id__c
            FROM copado__User_Story__c 
            WHERE Id IN :userStoryIds
            AND copadoconnect__External_Id__c = null
        ];
        
        for(copado__User_Story__c us : userStories) {
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint('callout:ServiceNow_Named_Credential/api/now/table/rm_story');
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json');
                req.setHeader('Accept', 'application/json');
                
                Map<String, Object> body = new Map<String, Object>{
                    'short_description' => us.copado__User_Story_Title__c,
                    'description' => us.copado__Functional_Specifications__c,
                    'state' => mapCopadoStatusToServiceNow(us.copado__Status__c)
                };
                req.setBody(JSON.serialize(body));
                
                Http http = new Http();
                HttpResponse res = http.send(req);
                
                if(res.getStatusCode() == 201) {
                    Map<String, Object> result = 
                        (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                    Map<String, Object> resultData = 
                        (Map<String, Object>)result.get('result');
                    String sysId = (String)resultData.get('sys_id');
                    
                    // Update with sys_id - this happens OUTSIDE trigger context
                    copado__User_Story__c usToUpdate = new copado__User_Story__c(
                        Id = us.Id,
                        copadoconnect__External_Id__c = sysId
                    );
                    update usToUpdate;
                    
                    System.debug('Successfully synced to ServiceNow: ' + sysId);
                }
            } catch(Exception e) {
                System.debug('Error syncing to ServiceNow: ' + e.getMessage());
                // Consider logging to a custom object for monitoring
            }
        }
    }
    
    private static String mapCopadoStatusToServiceNow(String copadoStatus) {
        Map<String, String> statusMapping = new Map<String, String>{
            'Approved' => 'Draft',
            'In Progress' => 'In Progress',
            'Completed' => 'Complete'
        };
        return statusMapping.get(copadoStatus) != null ? 
               statusMapping.get(copadoStatus) : 'Draft';
    }
}