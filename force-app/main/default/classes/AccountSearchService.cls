public with sharing class AccountSearchService {

    public static List<Account> findAccounts() {
        // ✅ Tainted source
        String nameFilter = ApexPages.currentPage()
            .getParameters()
            .get('name');

        // ❌ Critical: SOQL Injection
        String query = 'SELECT Id, Name FROM Account WHERE Name = \'' + nameFilter + '\'';
        return Database.query(query);
    }
}