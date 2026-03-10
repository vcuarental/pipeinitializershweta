/**
 * @description Invocable class for ServiceNow Change Request creation
 * Called by Flow when Promotion is completed to Production
 * @author Copado Integration Team
 * @date 2026-02-26
 */
public with sharing class ServiceNowIntegrationInvocable {

    @InvocableMethod(
        label='Create ServiceNow Change Request'
        description='Creates a ServiceNow Change Request for a Copado Promotion'
        category='ServiceNow'
    )
    public static List<PromotionResponse> createChangeRequest(List<PromotionRequest> requests) {
        List<PromotionResponse> responses = new List<PromotionResponse>();

        for (PromotionRequest request : requests) {
            PromotionResponse response = new PromotionResponse();

            try {
                // Validate Promotion ID
                if (request.promotionId == null) {
                    throw new ServiceNowException('Promotion ID cannot be null');
                }

                System.debug('🔵 ServiceNow Integration: Queueing job for Promotion: ' + request.promotionId);

                // Enqueue the job asynchronously to avoid mixed DML/callout error
                System.enqueueJob(new ServiceNowChangeRequestQueueable(request.promotionId));

                response.isSuccess = true;
                response.message = 'ServiceNow Change Request queued for processing';

                System.debug('✅ ServiceNow Change Request queued successfully');

            } catch (Exception e) {
                response.isSuccess = false;
                response.message = 'Error: ' + e.getMessage();

                System.debug('❌ Error queueing ServiceNow request: ' + e.getMessage());
                System.debug('Stack Trace: ' + e.getStackTraceString());
            }

            responses.add(response);
        }

        return responses;
    }

    /**
     * @description Input wrapper for Promotion ID
     */
    public class PromotionRequest {
        @InvocableVariable(label='Promotion ID' description='The ID of the Copado Promotion record' required=true)
        public Id promotionId;
    }

    /**
     * @description Output wrapper for response
     */
    public class PromotionResponse {
        @InvocableVariable(label='Success' description='Indicates if the request was successfully queued')
        public Boolean isSuccess;

        @InvocableVariable(label='Message' description='Status or error message')
        public String message;
    }

    /**
     * @description Custom exception class for ServiceNow integration errors
     */
    public class ServiceNowException extends Exception {}
}