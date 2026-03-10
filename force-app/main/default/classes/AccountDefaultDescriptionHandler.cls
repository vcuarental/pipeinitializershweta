public class AccountDefaultDescriptionHandler {
    
    /**
     * Adds a default description to Accounts that don't have one
     * @param accounts List of Account records to process
     */
    public static void addDefaultDescription(List<Account> accounts) {
        for (Account acc : accounts) {
            if (String.isBlank(acc.Description)) {
                acc.Description = 'Default Account - Created on ' + System.today().format();
            }
        }
    }
    
    /**
     * Trigger handler method for before insert
     * @param newAccounts List of new Account records
     */
    public static void handleBeforeInsert(List<Account> newAccounts) {
        addDefaultDescription(newAccounts);
    }
    
    /**
     * Trigger handler method for before update
     * @param newAccounts List of updated Account records
     */
    public static void handleBeforeUpdate(List<Account> newAccounts) {
        addDefaultDescription(newAccounts);
    }
}