/**
 * @description Test class for ServiceNowChangeRequestService
 */
@IsTest
private class ServiceNowChangeRequestServiceTest {

    @IsTest
    static void testClassExists() {
        // Test that the class can be instantiated
        Test.startTest();
        ServiceNowChangeRequestService service = new ServiceNowChangeRequestService();
        Test.stopTest();
        
        System.assertNotEquals(null, service, 'Service should be instantiated');
    }
}