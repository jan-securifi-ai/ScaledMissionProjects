@isTest
public class CensusDataHudUserControllerTest {
    
    @testSetup
    static void set(){
        TriggerSetting__c abc = new TriggerSetting__c();
        abc.Is_Active__c = true;
        abc.Name='test';
        insert abc;
    }
    
    @IsTest
    private static void testCensusTract() {
        Account obj = new Account(Name='Test Account', Business_Address__c='415 Mission St',Business_City__c='San Francisco',Business_State__c='CA',
                                  ShippingCountry='United States', ShippingPostalCode='94105');
        insert obj;
        CensusDataHudUserController.data data = new CensusDataHudUserController.data();
        list<CensusDataHudUserController.data> dataList = new list<CensusDataHudUserController.data>();
        data.street = '123 test';
        data.city = 'test';
        data.state = 'MI';
        data.zip ='12234';
        data.country = 'US';
        dataList.add(data);
        
        Set<Id> setAccountId =  new Set<Id>();
        setAccountId.add(obj.Id);
        Test.setMock(HttpCalloutMock.class, new CensusDataHudUserControllerTestMock());
        Test.startTest();
        CensusDataHudUserController.execute(setAccountId);
        CensusDataHudUserController.getXYCordinates('12');
        CensusDataHudUserController.getPlaceId('123 test');
        CensusDataHudUserController.getKey();
        CensusDataHudUserController.makeGeocodingCalloutInvocable('12', '22'); 
        CensusDataHudUserController.requestControllerInvocable(dataList);
        Test.stopTest();
    }

    @IsTest
    private static void testCensusTract2() {
        Account obj = new Account(Name='Test Account', Business_Address__c='415 Mission St',Business_City__c='San Francisco',Business_State__c='CA',
                                  ShippingCountry='United States', ShippingPostalCode='94105');
        insert obj;
        CensusDataHudUserControllerTestMock mock = new CensusDataHudUserControllerTestMock();
        mock.addFailureResponse();
        Set<Id> setAccountId =  new Set<Id>();
        setAccountId.add(obj.Id);
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        CensusDataHudUserController.execute(setAccountId);
        Test.stopTest();
    }
    
    @IsTest
    private static void testCensusTract3() {
        Account obj = new Account(Name='Test Account', Business_Address__c='415 Mission St',Business_City__c='San Francisco',Business_State__c='CA',
                                  ShippingCountry='United States', ShippingPostalCode='94105');
        insert obj;
        CensusDataHudUserController.data data = new CensusDataHudUserController.data();
        list<CensusDataHudUserController.data> dataList = new list<CensusDataHudUserController.data>();
        data.street = '123 test';
        data.city = 'test';
        data.state = 'MI';
        data.zip ='12234';
        data.country = 'US';
        dataList.add(data);
        CensusDataHudUserControllerTestMock mock = new CensusDataHudUserControllerTestMock();
        mock.addFailureResponse2();
        Set<Id> setAccountId =  new Set<Id>();
        setAccountId.add(obj.Id);
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        CensusDataHudUserController.execute(setAccountId);
        CensusDataHudUserController.getXYCordinates('12');
        CensusDataHudUserController.getPlaceId('123 test');
        CensusDataHudUserController.makeGeocodingCalloutInvocable('12', '22'); 
        CensusDataHudUserController.requestControllerInvocable(dataList);
        Test.stopTest();
    }
}