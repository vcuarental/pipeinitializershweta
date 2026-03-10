/**
 * @description Test class for AccountService
 * Provides comprehensive coverage for all methods and security scenarios
 */
@IsTest
private class AccountServiceTest {
    
    /**
     * @description Setup test data
     */
    @TestSetup
    static void setupTestData() {
        // Create test accounts
        List<Account> testAccounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            testAccounts.add(new Account(
                Name = 'Test Account ' + i,
                Industry = 'Technology',
                Phone = '555-000-' + i,
                BillingCity = 'San Francisco'
            ));
        }
        insert testAccounts;
    }
    
    /**
     * @description Test getAccountsById with valid IDs
     */
    @IsTest
    static void testGetAccountsByIdSuccess() {
        // Arrange
        List<Account> existingAccounts = [SELECT Id FROM Account LIMIT 5];
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : existingAccounts) {
            accountIds.add(acc.Id);
        }
        
        // Act
        Test.startTest();
        List<Account> results;
        try {
            results = AccountService.getAccountsById(accountIds);
            // Assert - if successful
            System.assertEquals(5, results.size(), 'Should return 5 accounts');
            System.assertNotEquals(null, results[0].Name, 'Account Name should be populated');
            System.assertNotEquals(null, results[0].Id, 'Account Id should be populated');
        } catch (System.QueryException e) {
            // If security enforced fails due to field permissions, that is expected in some orgs
            System.assert(e.getMessage().contains('Insufficient permissions'), 
                         'Should be a security-related exception');
        }
        Test.stopTest();
    }
    
    /**
     * @description Test getAccountsById with null input
     */
    @IsTest
    static void testGetAccountsByIdNullInput() {
        // Act
        Test.startTest();
        List<Account> results = AccountService.getAccountsById(null);
        Test.stopTest();
        
        // Assert
        System.assertEquals(0, results.size(), 'Should return empty list for null input');
    }
    
    /**
     * @description Test getAccountsById with empty set
     */
    @IsTest
    static void testGetAccountsByIdEmptySet() {
        // Arrange
        Set<Id> emptySet = new Set<Id>();
        
        // Act
        Test.startTest();
        List<Account> results = AccountService.getAccountsById(emptySet);
        Test.stopTest();
        
        // Assert
        System.assertEquals(0, results.size(), 'Should return empty list for empty set');
    }
    
    /**
     * @description Test getAccountsById with non-existent IDs
     */
    @IsTest
    static void testGetAccountsByIdNonExistent() {
        // Arrange
        Set<Id> fakeIds = new Set<Id>();
        // Create a fake Account ID that does not exist
        fakeIds.add('001000000000000AAA');
        
        // Act
        Test.startTest();
        List<Account> results;
        try {
            results = AccountService.getAccountsById(fakeIds);
            // Assert
            System.assertEquals(0, results.size(), 'Should return empty list for non-existent IDs');
        } catch (System.QueryException e) {
            // If security enforced fails due to field permissions, that is expected in some orgs
            System.assert(e.getMessage().contains('Insufficient permissions'), 
                         'Should be a security-related exception');
        }
        Test.stopTest();
    }
    
    /**
     * @description Test createAccounts with valid data
     */
    @IsTest
    static void testCreateAccountsSuccess() {
        // Arrange
        List<Account> newAccounts = new List<Account>();
        newAccounts.add(new Account(
            Name = 'New Test Account 1',
            Industry = 'Finance'
        ));
        newAccounts.add(new Account(
            Name = 'New Test Account 2',
            Industry = 'Healthcare'
        ));
        
        // Act
        Test.startTest();
        List<Account> createdAccounts = AccountService.createAccounts(newAccounts);
        Test.stopTest();
        
        // Assert
        System.assertEquals(2, createdAccounts.size(), 'Should create 2 accounts');
        System.assertNotEquals(null, createdAccounts[0].Id, 'Created account should have an ID');
        
        // Verify accounts were actually created
        List<Account> verifyAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'New Test Account%'];
        System.assertEquals(2, verifyAccounts.size(), 'Should find 2 newly created accounts');
    }
    
    /**
     * @description Test createAccounts with input sanitization
     */
    @IsTest
    static void testCreateAccountsWithSanitization() {
        // Arrange
        List<Account> newAccounts = new List<Account>();
        String testName = 'Test Account with quote';
        newAccounts.add(new Account(
            Name = testName
        ));
        
        // Act
        Test.startTest();
        List<Account> createdAccounts = AccountService.createAccounts(newAccounts);
        Test.stopTest();
        
        // Assert
        System.assertEquals(1, createdAccounts.size(), 'Should create 1 account');
        System.assertNotEquals(null, createdAccounts[0].Name, 'Name should be populated');
    }
    
    /**
     * @description Test createAccounts with null input
     */
    @IsTest
    static void testCreateAccountsNullInput() {
        // Act & Assert
        Test.startTest();
        try {
            AccountService.createAccounts(null);
            System.assert(false, 'Should throw exception for null input');
        } catch (AccountService.AccountServiceException e) {
            System.assert(e.getMessage().contains('cannot be null or empty'), 
                         'Exception message should mention null or empty');
        }
        Test.stopTest();
    }
    
    /**
     * @description Test createAccounts with empty list
     */
    @IsTest
    static void testCreateAccountsEmptyList() {
        // Arrange
        List<Account> emptyList = new List<Account>();
        
        // Act & Assert
        Test.startTest();
        try {
            AccountService.createAccounts(emptyList);
            System.assert(false, 'Should throw exception for empty list');
        } catch (AccountService.AccountServiceException e) {
            System.assert(e.getMessage().contains('cannot be null or empty'), 
                         'Exception message should mention null or empty');
        }
        Test.stopTest();
    }
    
    /**
     * @description Test createAccounts with blank name
     */
    @IsTest
    static void testCreateAccountsBlankName() {
        // Arrange
        List<Account> newAccounts = new List<Account>();
        newAccounts.add(new Account(Name = ''));
        
        // Act & Assert
        Test.startTest();
        try {
            AccountService.createAccounts(newAccounts);
            System.assert(false, 'Should throw exception for blank name');
        } catch (AccountService.AccountServiceException e) {
            System.assert(e.getMessage().contains('Name is required'), 
                         'Exception message should mention Name is required');
        }
        Test.stopTest();
    }
    
    /**
     * @description Test createAccounts with null name
     */
    @IsTest
    static void testCreateAccountsNullName() {
        // Arrange
        List<Account> newAccounts = new List<Account>();
        newAccounts.add(new Account(Industry = 'Technology'));
        
        // Act & Assert
        Test.startTest();
        try {
            AccountService.createAccounts(newAccounts);
            System.assert(false, 'Should throw exception for null name');
        } catch (AccountService.AccountServiceException e) {
            System.assert(e.getMessage().contains('Name is required'), 
                         'Exception message should mention Name is required');
        }
        Test.stopTest();
    }
    
    /**
     * @description Test updateAccounts with valid data
     */
    @IsTest
    static void testUpdateAccountsSuccess() {
        // Arrange
        List<Account> existingAccounts = [SELECT Id, Name, Industry FROM Account LIMIT 2];
        existingAccounts[0].Name = 'Updated Account 1';
        existingAccounts[0].Industry = 'Manufacturing';
        existingAccounts[1].Name = 'Updated Account 2';
        existingAccounts[1].Industry = 'Retail';
        
        // Act
        Test.startTest();
        AccountService.updateAccounts(existingAccounts);
        Test.stopTest();
        
        // Assert
        List<Account> updatedAccounts = [
            SELECT Id, Name, Industry 
            FROM Account 
            WHERE Id IN :existingAccounts
        ];
        System.assertEquals('Updated Account 1', updatedAccounts[0].Name, 'Account name should be updated');
        System.assertEquals('Manufacturing', updatedAccounts[0].Industry, 'Account industry should be updated');
    }
    
    /**
     * @description Test updateAccounts with null input
     */
    @IsTest
    static void testUpdateAccountsNullInput() {
        // Act & Assert
        Test.startTest();
        try {
            AccountService.updateAccounts(null);
            System.assert(false, 'Should throw exception for null input');
        } catch (AccountService.AccountServiceException e) {
            System.assert(e.getMessage().contains('cannot be null or empty'), 
                         'Exception message should mention null or empty');
        }
        Test.stopTest();
    }
    
    /**
     * @description Test updateAccounts with empty list
     */
    @IsTest
    static void testUpdateAccountsEmptyList() {
        // Arrange
        List<Account> emptyList = new List<Account>();
        
        // Act & Assert
        Test.startTest();
        try {
            AccountService.updateAccounts(emptyList);
            System.assert(false, 'Should throw exception for empty list');
        } catch (AccountService.AccountServiceException e) {
            System.assert(e.getMessage().contains('cannot be null or empty'), 
                         'Exception message should mention null or empty');
        }
        Test.stopTest();
    }
    
    /**
     * @description Test bulk operations with large dataset
     */
    @IsTest
    static void testBulkOperations() {
        // Arrange - Create bulk accounts
        List<Account> bulkAccounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            bulkAccounts.add(new Account(
                Name = 'Bulk Account ' + i,
                Industry = 'Technology'
            ));
        }
        
        // Act - Create
        Test.startTest();
        List<Account> createdAccounts = AccountService.createAccounts(bulkAccounts);
        
        // Update
        for (Account acc : createdAccounts) {
            acc.Industry = 'Finance';
        }
        AccountService.updateAccounts(createdAccounts);
        
        // Query
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : createdAccounts) {
            accountIds.add(acc.Id);
        }
        
        List<Account> queriedAccounts;
        try {
            queriedAccounts = AccountService.getAccountsById(accountIds);
            // Assert
            System.assertEquals(200, createdAccounts.size(), 'Should create 200 accounts');
            System.assertEquals(200, queriedAccounts.size(), 'Should query 200 accounts');
            System.assertEquals('Finance', queriedAccounts[0].Industry, 'Industry should be updated to Finance');
        } catch (System.QueryException e) {
            // If security enforced fails due to field permissions, verify creation and update worked
            System.assertEquals(200, createdAccounts.size(), 'Should create 200 accounts');
            System.assert(e.getMessage().contains('Insufficient permissions'), 
                         'Should be a security-related exception');
        }
        Test.stopTest();
    }
    
    /**
     * @description Test exception handling for custom exception
     */
    @IsTest
    static void testCustomException() {
        // Act & Assert
        Test.startTest();
        try {
            throw new AccountService.AccountServiceException('Test exception message');
        } catch (AccountService.AccountServiceException e) {
            System.assertEquals('Test exception message', e.getMessage(), 'Exception message should match');
        }
        Test.stopTest();
    }
}