/**
 * @description Test class for ServiceNowSyncQueueable
 */
@IsTest
private class ServiceNowSyncQueueableTest {

    @IsTest
    static void testClassExists() {
        // Test that the class can be instantiated
        Test.startTest();
        ServiceNowSyncQueueable queueable = new ServiceNowSyncQueueable();
        Test.stopTest();
        
        System.assertNotEquals(null, queueable, 'Queueable should be instantiated');
    }
}