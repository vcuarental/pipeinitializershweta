@isTest
private class AccountDefaultDescriptionHandlerTest {
    
    @isTest
    static void testAddDefaultDescription_NewAccount() {
        // Test that a new account without description gets a default one
        Account acc = new Account(Name = 'Test Account');
        
        Test.startTest();
        insert acc;
        Test.stopTest();
        
        Account insertedAcc = [SELECT Id, Description FROM Account WHERE Id = :acc.Id];
        System.assertNotEquals(null, insertedAcc.Description, 'Description should not be null');
        System.assert(insertedAcc.Description.contains('Default Account'), 'Description should contain default text');
    }
    
    @isTest
    static void testAddDefaultDescription_WithExistingDescription() {
        // Test that an account with existing description keeps it
        Account acc = new Account(
            Name = 'Test Account',
            Description = 'Custom Description'
        );
        
        Test.startTest();
        insert acc;
        Test.stopTest();
        
        Account insertedAcc = [SELECT Id, Description FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Custom Description', insertedAcc.Description, 'Custom description should be preserved');
    }
    
    @isTest
    static void testAddDefaultDescription_BulkInsert() {
        // Test bulk insert of accounts
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(new Account(Name = 'Bulk Test Account ' + i));
        }
        
        Test.startTest();
        insert accounts;
        Test.stopTest();
        
        List<Account> insertedAccounts = [SELECT Id, Description FROM Account WHERE Id IN :accounts];
        System.assertEquals(200, insertedAccounts.size(), 'All accounts should be inserted');
        
        for (Account acc : insertedAccounts) {
            System.assertNotEquals(null, acc.Description, 'Each account should have a description');
        }
    }
    
    @isTest
    static void testHandleBeforeUpdate() {
        // Test that update also adds default description if removed
        Account acc = new Account(
            Name = 'Test Account',
            Description = 'Initial Description'
        );
        insert acc;
        
        // Remove description
        acc.Description = null;
        
        Test.startTest();
        update acc;
        Test.stopTest();
        
        Account updatedAcc = [SELECT Id, Description FROM Account WHERE Id = :acc.Id];
        System.assertNotEquals(null, updatedAcc.Description, 'Description should be added on update');
        System.assert(updatedAcc.Description.contains('Default Account'), 'Description should contain default text');
    }
}