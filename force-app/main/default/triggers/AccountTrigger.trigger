trigger AccountTrigger on Account (after insert, after update) {
    Set<Id> accountIds = new Set<Id>();

    for (Account acc : Trigger.new) {
        if ((Trigger.isUpdate && (acc.Business_Address__c != Trigger.oldMap.get(acc.Id).Business_Address__c ||
            acc.Business_City__c != Trigger.oldMap.get(acc.Id).Business_City__c ||
            acc.Business_State__c != Trigger.oldMap.get(acc.Id).Business_State__c)) ||
            Trigger.isInsert) {
            accountIds.add(acc.Id);
        }
    }

    if (!accountIds.isEmpty()) {
        list<TriggerSetting__c> customSettings = [SELECT Is_Active__c FROM TriggerSetting__c LIMIT 1];
        if (!customSettings.isEmpty() && customSettings[0].Is_Active__c) {
            if (!System.isFuture() && !System.isBatch()) {
                CensusDataHudUserController.execute(accountIds);
            }
        }
    }
}