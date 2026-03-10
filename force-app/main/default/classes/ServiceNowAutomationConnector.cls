/**
 * @description ServiceNow Integration wrapper for Copado Automation Rules
 * This class provides a simple entry point that can be called from Automation Rules
 */
public with sharing class ServiceNowAutomationConnector {
    
    /**
     * @description Creates a ServiceNow Change Request for a Promotion
     * This method can be called from Copado Automation Rules
     * @param promotionId The ID of the Promotion record
     * @return String The Change Request number created in ServiceNow
     */
    public static String execute(Id promotionId) {
        try {
            System.debug('🔵 ServiceNowAutomationConnector called for Promotion: ' + promotionId);
            
            // Validate it's a Promotion record
            if (promotionId == null || promotionId.getSObjectType() != Schema.copado__Promotion__c.SObjectType) {
                throw new AutomationException('Invalid Promotion ID provided');
            }
            
            // Call the existing ServiceNow integration
            String changeRequestNumber = ServiceNowChangeRequestCreator.createChangeRequest(promotionId);
            
            System.debug('✅ SUCCESS: Change Request ' + changeRequestNumber + ' created');
            
            return changeRequestNumber;
            
        } catch (Exception e) {
            System.debug('❌ ERROR: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            throw e;
        }
    }
    
    /**
     * @description Invocable method for Flow/Process Builder
     * @param requests List of promotion IDs
     * @return List of results
     */
    @InvocableMethod(label='Create ServiceNow Change Request' 
                     description='Creates a ServiceNow Change Request for a Copado Promotion'
                     category='ServiceNow')
    public static List<Result> createChangeRequest(List<Request> requests) {
        List<Result> results = new List<Result>();
        
        for (Request req : requests) {
            Result result = new Result();
            try {
                result.changeRequestNumber = execute(req.promotionId);
                result.success = true;
                result.errorMessage = null;
            } catch (Exception e) {
                result.success = false;
                result.errorMessage = e.getMessage();
                result.changeRequestNumber = null;
            }
            results.add(result);
        }
        
        return results;
    }
    
    /**
     * @description Input parameters for invocable method
     */
    public class Request {
        @InvocableVariable(label='Promotion ID' required=true)
        public Id promotionId;
    }
    
    /**
     * @description Output results for invocable method
     */
    public class Result {
        @InvocableVariable(label='Success')
        public Boolean success;
        
        @InvocableVariable(label='Change Request Number')
        public String changeRequestNumber;
        
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
    
    /**
     * @description Custom exception class
     */
    public class AutomationException extends Exception {}
}