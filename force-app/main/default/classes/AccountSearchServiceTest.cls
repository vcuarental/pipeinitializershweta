@IsTest
public class AccountSearchServiceTest {

    @IsTest
    static void testFindAccounts() {
        Account acc = new Account(Name = 'TestAccount');
        insert acc;

        Test.startTest();
        ApexPages.currentPage().getParameters().put('name', 'TestAccount');
        List<Account> results = AccountSearchService.findAccounts();
        Test.stopTest();

        System.assertEquals(1, results.size());
    }
}