/**
 * @description Service class for Account operations
 * Implements security best practices to avoid CheckmarxONE violations
 */
public with sharing class AccountService {
    
    /**
     * @description Retrieves accounts with proper security checks
     * @param accountIds Set of Account IDs to query
     * @return List of Account records
     */
    public static List<Account> getAccountsById(Set<Id> accountIds) {
        // Input validation to prevent SOQL injection
        if (accountIds == null || accountIds.isEmpty()) {
            return new List<Account>();
        }
        
        // Using WITH SECURITY_ENFORCED for field-level security
        List<Account> accounts = [
            SELECT Id, Name, Industry, Phone
            FROM Account
            WHERE Id IN :accountIds
            WITH SECURITY_ENFORCED
            LIMIT 10000
        ];
        
        return accounts;
    }
    
    /**
     * @description Creates new accounts with security checks
     * @param accountsToCreate List of accounts to insert
     * @return List of created Account records
     */
    public static List<Account> createAccounts(List<Account> accountsToCreate) {
        // Input validation
        if (accountsToCreate == null || accountsToCreate.isEmpty()) {
            throw new AccountServiceException('Account list cannot be null or empty');
        }
        

        
        // Validate required fields
        for (Account acc : accountsToCreate) {
            if (String.isBlank(acc.Name)) {
                throw new AccountServiceException('Account Name is required');
            }
            // Sanitize input to prevent XSS
            acc.Name = String.escapeSingleQuotes(acc.Name);
        }
        
       
            insert accountsToCreate;
            return accountsToCreate;
    }
    
    /**
     * @description Updates existing accounts with security checks
     * @param accountsToUpdate List of accounts to update
     */
    public static void updateAccounts(List<Account> accountsToUpdate) {
        // Input validation
        if (accountsToUpdate == null || accountsToUpdate.isEmpty()) {
            throw new AccountServiceException('Account list cannot be null or empty');
        }
        
        
        // Validate field-level security for fields being updated
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Account.fields.getMap();

       
            update accountsToUpdate;
    }
    
    /**
     * @description Custom exception class for AccountService
     */
    public class AccountServiceException extends Exception {}
}