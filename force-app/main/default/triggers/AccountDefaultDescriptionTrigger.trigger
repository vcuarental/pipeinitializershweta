trigger AccountDefaultDescriptionTrigger on Account (before insert, before update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            AccountDefaultDescriptionHandler.handleBeforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            AccountDefaultDescriptionHandler.handleBeforeUpdate(Trigger.new);
        }
    }
}