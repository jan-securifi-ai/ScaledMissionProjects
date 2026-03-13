global class CensusDataHudUserController {
    
    @future(callout = true)
    public static void execute(Set <Id> setAccountIds) {
        Census_Data__c cdError = new Census_Data__c();
        list<account> accList = new list<account>();
        list<account> accListUpdated = new list<account>();
        accList = [SELECT Id, Name,Business_Address__c,Longitude_X__c,Census_Tract_Code__c,Latitude_Y__c,Business_City__c,Business_State__c,ShippingPostalCode 
                           FROM Account 
                           WHERE Id in: setAccountIds];
        
        
        for (Account acc: accList)
        {
            cdError.Account__c = acc.id;
            if(acc.Business_Address__c !=null && acc.Business_City__c !=null && acc.Business_State__c !=null){
                
                List<String> listOfValues = makeGeocodingCallout(acc.Business_Address__c, acc.Business_City__c ,acc.Business_State__c,acc.id,acc.Longitude_X__c, acc.Latitude_Y__c,1); //'16655 Turner Cemetery Rd' 'Glen Saint Mary' 'FL'
                //listOfValues[0] --> cbsa
                //listOfValues[1] --> GeoId
                system.debug('here return from census<< ' + listOfValues);
                try{
                    if(listOfValues.size()>0){
                        
                        if(listOfValues.size()>4){
                            if(acc.Census_Tract_Code__c==null || acc.Census_Tract_Code__c == ''){
                            acc.Tract_Code__c = listOfValues[2];
                            acc.State_Code__c = listOfValues[3];
                            acc.County_Code__c = listOfValues[4];
                            accListUpdated.add(acc);
                            }
                        }
                        
                        List<String> listEndpoints = new List<String>();
                        listEndpoints.add(listOfValues[0] + 'M' + listOfValues[1]);
                        listEndpoints.add(listOfValues[0] + 'N' + listOfValues[1]);
                        listEndpoints.add(listOfValues[0] + 'MM' + listOfValues[1]);
                        response fmr = new response();
                        response IL = new response();
                        
                        fmr = fetchData(listEndpoints, 'fmr',acc.id);
                        if(fmr.responseCode!='200'){
                            if(listOfValues.size()>4){
                                cdError.County__c = listOfValues[4];
                                cdError.State__c = listOfValues[3];
                                cdError.Tract__c = listOfValues[2];
                                cdError.CBSA__c = listOfValues[0];
                                cdError.GEOID__c = listOfValues[1];
                            }
                            cdError.Account__c = acc.id;
                            cdError.Error_Message__c = 'Callout error: ' + fmr.responseCode + ' - ' + fmr.responseBody;
                            cdError.Status_Code__c = Decimal.valueOf(fmr.responseCode);
                            
                        }else{
                            IL = fetchData(listEndpoints, 'il',acc.id);
                            if(IL.responseCode!='200'){
                                if(listOfValues.size()>4){
                                    cdError.County__c = listOfValues[4];
                                    cdError.State__c = listOfValues[3];
                                    cdError.Tract__c = listOfValues[2];
                                    cdError.CBSA__c = listOfValues[0];
                                    cdError.GEOID__c = listOfValues[1];
                                }
                                
                                cdError.Error_Message__c = 'Callout error: ' + IL.responseCode + ' - ' + IL.responseBody;
                                cdError.Status_Code__c = Decimal.valueOf(IL.responseCode);
                            }else{
                                String censusId = parseFMRResponse(fmr.responseBody, acc.Id, fmr.endpointSuffix);
                                if(censusId!=null && censusId!=''){
                                    parseILResponse(IL.responseBody, censusId,listOfValues[2],listOfValues[4],listOfValues[3],listOfValues[0],listOfValues[1]);
                                }
                            }
                        }
                        
                        
                    }else{
                        cdError.Error_Message__c = 'line 66>> no data in listOfValues >> '+listOfValues ;
                        insert cdError; 
                    }
                }catch(exception e){
                    system.debug('Unexpected Error>> : '+ e.getLineNumber() + ' : '+ e.getMessage());
                    system.debug('Additional Info : '+ e.getStackTraceString());
                    cdError.Account__c = acc.id;
                    cdError.Error_Message__c = 'Unexpected Error>> : '+ e.getLineNumber() + ' : '+ e.getMessage() + ' \n ' + e.getStackTraceString() ;
                    
					insert cdError;                    
                }
                
                 
            }else{
                cdError.Error_Message__c = 'Either one of these is missing: address, city or state';
                insert cdError; 
            }
            
            
        }
        if(accListUpdated.size()>0){
        system.debug('account list updated>> ');
        update accListUpdated;
        }
    }
    
    public class response {
        public string endpointSuffix {get;set;}
        public string responseBody {get;set;}
        public string responseCode {get;set;}
        public string dataType {get;set;}
        public boolean errorFlag  {get;set;}
        public string errorMsg  {get;set;}
        public string placeId  {get;set;}
        public string latitude {get;set;}
        public string longitude {get;set;}
    }
    private static response fetchData(List<String> listEndpoints, String dataType,string accId) {
        response res = new response();
        res.dataType = dataType;
        date d = system.today();
        Integer priorYear = d.year()-1;
        String baseUrl = 'https://www.huduser.gov/hudapi/public/';
        String endpoint = dataType.equalsIgnoreCase('il') ? 'il/data/METRO' : 'fmr/data/METRO';
        string censusId='';
        for (String endpointSuffix : listEndpoints) {
            HttpRequest request = new HttpRequest();
            request.setMethod('GET');
            system.debug('endpoint failing 128>> '+ baseUrl + endpoint + endpointSuffix +'?year='+priorYear);
            request.setEndpoint(baseUrl + endpoint + endpointSuffix +'?year='+priorYear);
            request.setHeader('Authorization', 'Bearer ' + getAccessToken());
            
            Http httpObj = new Http();
            HttpResponse response = httpObj.send(request);
            
            if (response.getStatusCode() == 200) {
                String responseBody = response.getBody();
                //entityId = endpointSuffix;
                if(dataType =='fmr'){
                    
                    //parseJSON(responseBody);
                    responseBody = responseBody.replaceAll('One-Bedroom', 'One_Bedroom');
                    responseBody = responseBody.replaceAll('Two-Bedroom', 'Two_Bedroom');
                    responseBody = responseBody.replaceAll('Three-Bedroom', 'Three_Bedroom');
                    responseBody = responseBody.replaceAll('Four-Bedroom', 'Four_Bedroom');
                    
                    //censusId = parseFMRResponse(responseBody, accountId, endpointSuffix);
                    
                    
                }
                res.responseCode = string.valueOf(response.getStatusCode());
                res.responseBody = responseBody;
                res.endpointSuffix = endpointSuffix;
                
                break;
                
            } else {
                System.debug('Fail Response Body is>> ' + response.getBody());
                res.responseCode = string.valueOf(response.getStatusCode());
                
                res.endpointSuffix = endpointSuffix;
                Map<String, Object> parsedJson = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                
                if (parsedJson.containsKey('error')) {
                    String errorMessage = (String) parsedJson.get('error');
                    if(errorMessage == 'Missing or invalid value in the query parameter(s)'){
                        res.responseBody = 'No data found for the entityid';
                    }else{
                        res.responseBody = response.getBody();
                    }
                    
                    
                }
                
            }
        }
        return res;
        //System.debug('Entity Id is>> ' + entityId);
    }
    
    private static String getAccessToken() {
        list<Census_Hud_User__mdt> metadata = new list<Census_Hud_User__mdt>();
        metadata = [select Access_Token__c from Census_Hud_User__mdt];
        if(metadata.size()>0){
            return metadata[0].Access_Token__c;
        }
        return '';
    }
    
    public static list<string> makeGeocodingCallout(String street, String city, String state,string accId,string x, string y,Integer calloutNumber) {
        system.debug('calloutNumber>>>> '+ calloutNumber);
        list<string> listOfValues = new list<string>();
        
        try{
            String endpoint = '';
            if(calloutNumber==1){
                endpoint = System.Label.Custom_Label_Census_Demographic_Endpoint2
                    + 'street=' + EncodingUtil.urlEncode(street, 'UTF-8')
                    + '&city=' + EncodingUtil.urlEncode(city, 'UTF-8')
                    + '&state=' + EncodingUtil.urlEncode(state, 'UTF-8')
                    + '&benchmark=Public_AR_Current'   //Public_AR_Census2020
                    + '&vintage=Census2010_Current'   //Census2010_Census2020
                    + '&layers=All'
                    + '&format=json';
            }else if(calloutNumber==2){
                endpoint = System.Label.Custom_Label_Census_Demographic_Endpoint2
                    + 'street=' + EncodingUtil.urlEncode(street, 'UTF-8')
                    + '&city=' + EncodingUtil.urlEncode(city, 'UTF-8')
                    + '&state=' + EncodingUtil.urlEncode(state, 'UTF-8')
                    + '&benchmark=Public_AR_Current'
                    + '&vintage=Census2010_Current'
                    + '&layers=All'
                    + '&format=json';
            }else{
                endpoint = System.Label.Census_Demographic_Endpoint + 'x='+x + '&y='+y+ '&benchmark=Public_AR_Current'+ '&vintage=Census2010_Current'+ '&layers=All' + '&format=json';
            }
            system.debug('endpoint>> '+ endpoint);
            // Create an HTTP request
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('GET');
            
            Http httpObj = new Http();
            HttpResponse response = httpObj.send(request);
            String GEOID='';
            String CBSA ='';
            String county2 ='';
            String stateCode = '';
            String tract = '';
            boolean checkFlag = false;
            System.debug('response>> '+response.getBody());
            if (response.getStatusCode() == 200) {
                String responseBody = response.getBody();
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                
                Map<String, Object> result = (Map<String, Object>) jsonResponse.get('result');
                system.debug('resutl> '+ result);
                List<Object> addressMatches = (List<Object>) result.get('addressMatches');
                
                if(calloutNumber==3){
                    Map<String, Object> geographies = (Map<String, Object>) result.get('geographies');
                    if(geographies!=null){checkFlag = true;
                    }
                }
                system.debug('addressMatches>> '+ addressMatches);
                if ((addressMatches != null && !addressMatches.isEmpty()) || checkFlag) {
                    Map<String, Object> geographies = new Map<String, Object>();
                    if(!checkFlag){
                        Map<String, Object> firstAddressMatch = (Map<String, Object>) addressMatches[0];
                        geographies = (Map<String, Object>) firstAddressMatch.get('geographies');
                    }else{ geographies = (Map<String, Object>) result.get('geographies');
                    }
                    List<Object> censusBlocks = (List<Object>) geographies.get('Census Blocks');
                    List<Object> metropolitanDivisions = (List<Object>) geographies.get('Metropolitan Statistical Areas');
                    if(metropolitanDivisions==null || metropolitanDivisions.isEmpty()){metropolitanDivisions = (List<Object>) geographies.get('Metropolitan Divisions');
                    }
                    List<Object> counties = (List<Object>) geographies.get('Counties');
                    if (censusBlocks != null && !censusBlocks.isEmpty()) {
                        Map<String, Object> firstCensusBlock = (Map<String, Object>) censusBlocks[0];
                        
                        county2 = (String) firstCensusBlock.get('COUNTY');
                        stateCode = (String) firstCensusBlock.get('STATE');
                        tract = (String) firstCensusBlock.get('TRACT');
                        
                        System.debug('County: ' + county2);
                        System.debug('State: ' + stateCode);
                        System.debug('Tract: ' + tract);
                        string tractVar ;
                        if(tract!=null){
                            tractVar= String.valueOf(double.valueOf(tract)/100);
                        }
                    } else {
                        System.debug('No census blocks found');
                    }
                    
                    if (metropolitanDivisions != null && !metropolitanDivisions.isEmpty()) {
                        Map<String, Object> metropolitanDivision = (Map<String, Object>) metropolitanDivisions[0];
                        
                        CBSA = (String) metropolitanDivision.get('CBSA');
                        GEOID = (String) metropolitanDivision.get('GEOID');
                        system.debug('CBSA>> '+ CBSA);
                        system.debug('GEOID>> '+ GEOID);
                    } else {
                        System.debug('No Metropolitan Divisions found');
                    }
                    
                    if (counties != null && !counties.isEmpty()) {
                        Map<String, Object> county = (Map<String, Object>) counties[0];
                        
                        //GEOID = (String) county.get('GEOID');
                        //system.debug('GEOID>> '+ GEOID);
                    } else {
                        System.debug('No Counties found');
                    }
                    System.debug('confition>> '+ (CBSA!=''&& GEOID !=''));
                    if(CBSA!=''&& GEOID !=''){
                        listOfValues.add(CBSA);
                        listOfValues.add(GEOID);
                        listOfValues.add(tract);
                        listOfValues.add(stateCode);
                        listOfValues.add(county2);
                        return listOfValues;
                    }
                    
                } else {
                    System.debug('No address matches found');
                    if(calloutNumber==3){Census_Data__c cdError = new Census_Data__c(); cdError.Account__c = accId; cdError.Error_Message__c = 'No address matches found'; cdError.Status_Code__c = 200; insert cdError;
                    }else{
                        calloutNumber = calloutNumber+1;
                        listOfValues =  makeGeocodingCallout(street,city,state,accId,x, y,calloutNumber);
                    }
                }
                
                
            } else {
                System.debug('Callout error: ' + response.getStatusCode() + ' - ' + response.getStatus());
                Census_Data__c cdError = new Census_Data__c(); cdError.Account__c = accId; cdError.Error_Message__c = 'Callout error: ' + response.getStatusCode() + ' - ' + response.getBody();
                cdError.Status_Code__c = response.getStatusCode(); insert cdError;
            }
            
        }
        Catch(exception e){
            system.debug('Unexpected Error Occured!! : '+ e.getLineNumber() + ' : '+ e.getMessage());
        }
        system.debug('listOfValues>>>2 '+ listOfValues);
        return listOfValues;
    }
    
    public static string parseFMRResponse(String jsonString,  string accountId , string entityId) {
        Census_Data__c cd = new Census_Data__c();
        list<FMR_Basic_Data__c> bdList = new list<FMR_Basic_Data__c>();
        FMR_Basic_Data__c bd = new FMR_Basic_Data__c();
        list<Account> accList = new list<account>();
        accList = [select id, Business_Zip__c from account where id=: accountId];
        cd.Entity_ID__c = entityId;
        cd.Account__c = accountId;
        try{
            Map<String, Object> parsedData = (Map<String, Object>) JSON.deserializeUntyped(jsonString);
            
            if (parsedData.containsKey('data')) {
                Map<String, Object> data = (Map<String, Object>) parsedData.get('data');
                
                if (data.containsKey('county_name')) {
                    String countyName = (String) data.get('county_name');
                    cd.County_Name__c = countyName;
                }
                
                if (data.containsKey('counties_msa')) {
                    String countiesMsa = (String) data.get('counties_msa');
                    cd.Counties_MSA__c = countiesMsa;
                }
                
                if (data.containsKey('metro_status')) {
                    String metroStatus = (String) data.get('metro_status');
                    cd.Metro_Status__c = metroStatus;
                }
                
                if (data.containsKey('metro_name')) {
                    String metroName = (String) data.get('metro_name');
                    cd.Metro_Name__c = metroName;
                }
                
                if (data.containsKey('area_name')) {
                    String areaName = (String) data.get('area_name');
                    cd.Area_Name__c = areaName;
                }
                
                if (data.containsKey('town_name')) {
                    String town_name = (String) data.get('town_name');
                    cd.Town_Name__c = town_name;
                }
                
                if (data.containsKey('year')) {String yearMFR = (String) data.get('year'); cd.Year__c = yearMFR;
                }
                
                if (data.containsKey('smallarea_status')) {
                    String smallareaStatus = (String) data.get('smallarea_status');
                    cd.Small_Area_Status__c = smallareaStatus;
                }
                insert cd;
                if (data.containsKey('basicdata')) {
                    Object basicData = data.get('basicdata');
                    
                    if (basicData instanceof List<Object>) { List<BasicDataWrapper> basicDataList = new List<BasicDataWrapper>();
                        for (Object item : (List<Object>) basicData) {
                            basicDataList.add((BasicDataWrapper) JSON.deserialize( JSON.serialize(item), BasicDataWrapper.class));
                        }
                        
                        for (BasicDataWrapper dataItem : basicDataList) {
                            bd = new FMR_Basic_Data__c(); bd.Efficiency__c = String.valueOf(dataItem.Efficiency);
                            bd.Four_Bedroom__c =  String.valueOf(dataItem.Four_Bedroom); bd.Two_Bedroom__c = String.valueOf(dataItem.Two_Bedroom);
                            bd.Three_Bedroom__c = String.valueOf(dataItem.Three_Bedroom); bd.One_Bedroom__c =  String.valueOf(dataItem.One_Bedroom);
                            bd.Year__c = dataItem.year; bd.Census_Data__c = cd.id;  bd.Zip_Code__c  =  dataItem.zip_code; bdList.add(bd);
                        }
                    } else if (basicData instanceof Map<String, Object>) {
                        BasicDataWrapper singleBasicData = (BasicDataWrapper) JSON.deserialize(
                            JSON.serialize(basicData),
                            BasicDataWrapper.class
                        );
                        bd = new FMR_Basic_Data__c();
                        bd.Efficiency__c = String.valueOf(singleBasicData.Efficiency);
                        bd.Four_Bedroom__c =  String.valueOf(singleBasicData.Four_Bedroom);
                        bd.Two_Bedroom__c = String.valueOf(singleBasicData.Two_Bedroom);
                        bd.Three_Bedroom__c = String.valueOf(singleBasicData.Three_Bedroom);
                        bd.One_Bedroom__c =  String.valueOf(singleBasicData.One_Bedroom);
                        bd.Year__c = singleBasicData.year; bd.Census_Data__c = cd.id;
                        bd.Zip_Code__c  =  singleBasicData.zip_code;
                        bdList.add(bd);
                    }
                }
                bd = new FMR_Basic_Data__c();
                if(accList.size()>0){
                    if(bdList.size()>1){ for(FMR_Basic_Data__c fmr:bdList){ if(fmr.Zip_Code__c == accList[0].Business_Zip__c){ bd = fmr;
                            }
                        }
                    }else{
                        bd = bdList[0];
                        bd.Zip_Code__c = accList[0].Business_Zip__c;
                    }
                }
                if(bd!=null){
                    insert bd;
                }
                //insert bdList;
                
            }
            
        }catch(exception e){
            system.debug('Unexcpected Error!!>> : '+ e.getLineNumber() + '  :  '+ e.getMessage());
        }   
        if(cd!=null){
            return cd.id;
        }else{
            return '';
        }
    }
    
    public class BasicDataWrapper {
        public String zip_code;
        public Integer Efficiency;
        public string year;
        @SerializedName('One-Bedroom')
        public Integer One_Bedroom;
        
        @SerializedName('Two-Bedroom')
        public Integer Two_Bedroom;
        
        @SerializedName('Three-Bedroom')
        public Integer Three_Bedroom;
        
        @SerializedName('Four-Bedroom')
        public Integer Four_Bedroom;
    }
    
    public static void parseILResponse(string jsonString, string censusDataId,string tract,string county,string stateCode,string cbsa,string geoId){
        system.debug('response in IL>> '+ jsonString);
        try{
            Census_Data__c cd = [select id,Median_Income__c,County__c,CBSA__c,GEOID__c,State__c,Tract__c from Census_Data__c where id =: censusdataId];
            IL_Data_Extremely_Low__c el = new IL_Data_Extremely_Low__c();
            IL_Data_Low__c l = new IL_Data_Low__c();
            IL_Data_Very_Low__c vl = new IL_Data_Very_Low__c();
            Map<String, Object> dataMap = (Map<String, Object>)JSON.deserializeUntyped(jsonString);
            if (dataMap.containsKey('data')) {
                Map<String, Object> data = (Map<String, Object>) dataMap.get('data');
                cd.Median_Income__c = Decimal.valueOf(String.valueOf(data.get('median_income')));
                cd.County__c = county;
                cd.State__c = stateCode;
                cd.Tract__c = tract;
                cd.CBSA__c = cbsa;
                cd.GEOID__c = geoId;
                cd.Status_Code__c = 200;
                update cd;
                // Access very low income data
                Map<String, Object> veryLowData = (Map<String, Object>)data.get('very_low');
                vl.IL_50_P1__c = Decimal.valueOf(String.valueOf(veryLowData.get('il50_p1')));
                vl.IL_50_P2__c = Decimal.valueOf(String.valueOf(veryLowData.get('il50_p2')));
                vl.IL_50_P3__c = Decimal.valueOf(String.valueOf(veryLowData.get('il50_p3')));
                vl.IL_50_P4__c = Decimal.valueOf(String.valueOf(veryLowData.get('il50_p4')));
                vl.IL_50_P5__c = Decimal.valueOf(String.valueOf(veryLowData.get('il50_p5')));
                vl.IL_50_P6__c = Decimal.valueOf(String.valueOf(veryLowData.get('il50_p6')));
                vl.IL_50_P7__c = Decimal.valueOf(String.valueOf(veryLowData.get('il50_p7')));
                vl.IL_50_P8__c = Decimal.valueOf(String.valueOf(veryLowData.get('il50_p8')));
                vl.Census_Data__c = cd.id;
                
                // Access extremely low income data
                Map<String, Object> extremelyLowData = (Map<String, Object>)data.get('extremely_low');
                el.IL_30_P1__c = Decimal.valueOf(String.valueOf(extremelyLowData.get('il30_p1')));
                el.IL_30_P2__c = Decimal.valueOf(String.valueOf(extremelyLowData.get('il30_p2')));
                el.IL_30_P3__c = Decimal.valueOf(String.valueOf(extremelyLowData.get('il30_p3')));
                el.IL_30_P4__c = Decimal.valueOf(String.valueOf(extremelyLowData.get('il30_p4')));
                el.IL_30_P5__c = Decimal.valueOf(String.valueOf(extremelyLowData.get('il30_p5')));
                el.IL_30_P6__c = Decimal.valueOf(String.valueOf(extremelyLowData.get('il30_p6')));
                el.IL_30_P7__c = Decimal.valueOf(String.valueOf(extremelyLowData.get('il30_p7')));
                el.IL_30_P8__c = Decimal.valueOf(String.valueOf(extremelyLowData.get('il30_p8')));
                el.Census_Data__c = cd.id;
                
                
                // Access low income data
                Map<String, Object> lowData = (Map<String, Object>)data.get('low');
                l.IL_80_P1__c = Decimal.valueOf(String.valueOf(lowData.get('il80_p1')));
                l.IL_80_P2__c = Decimal.valueOf(String.valueOf(lowData.get('il80_p2')));
                l.IL_80_P3__c = Decimal.valueOf(String.valueOf(lowData.get('il80_p3')));
                l.IL_80_P4__c = Decimal.valueOf(String.valueOf(lowData.get('il80_p4')));
                l.IL_80_P5__c = Decimal.valueOf(String.valueOf(lowData.get('il80_p5')));
                l.IL_80_P6__c = Decimal.valueOf(String.valueOf(lowData.get('il80_p6')));
                l.IL_80_P7__c = Decimal.valueOf(String.valueOf(lowData.get('il80_p7')));
                l.IL_80_P8__c = Decimal.valueOf(String.valueOf(lowData.get('il80_p8')));
                l.Census_Data__c = cd.id;
                
                insert l;
                insert vl;
                insert el;
            }
        }
        catch(exception e){
            system.debug('Unexpected Error>> '+ e.getLineNumber() +' : '+ e.getMessage());
        }
    }
    
    global class data{
        @InvocableVariable
        global string street;
        @InvocableVariable
        global string city;
        @InvocableVariable
        global string state;
        @InvocableVariable
        global string zip;
        @InvocableVariable
        global string country;  
    }
    global class returnData{
        @InvocableVariable
        global string errorMsg;
        @InvocableVariable
        global string CensusTract;
        @InvocableVariable
        global string state;
        @InvocableVariable
        global string county;
        @InvocableVariable
        global string tract;
        @InvocableVariable
        global boolean errorFlag;
        
    }
    @InvocableMethod(label='Census Data' description='Census Data Retrievel' callout = true)
    global static list<returnData> requestControllerInvocable(list<data> inputAddress){
        list<string> str = new list<string>();
        response res = new response();
        list<returnData> dataReturnVar = new list<returnData>();
        returnData dr = new returnData();
        dr.errorFlag = false;
        try{
            string address = inputAddress[0].street+', '+ inputAddress[0].city+', '+inputAddress[0].state+' '+inputAddress[0].zip+', '+inputAddress[0].country;
            res = getPlaceId(address);
            if(!res.errorFlag){ String placeId = res.placeId; res = new response();
                
                res = getXYCordinates(placeId);
                if(!res.errorFlag){
                    string Y = res.latitude;
                    string X = res.longitude;
                    system.debug('X Final>> '+ X);
                    system.debug('Y Final>> '+ Y);
                    
                  str =   makeGeocodingCalloutInvocable(X, Y);
                    
                    if(str.size()>0){
                        dr.CensusTract = str[1]+str[0]+str[2];
                        dr.state = str[1];
                        dr.county = str[0];
                        dr.tract = str[2];
                    }
                }else{
                    dr.errorFlag= res.errorFlag;
                    dr.errorMsg = res.errorMsg;
                }
                
            }else{
                dr.errorFlag= res.errorFlag;
                dr.errorMsg = res.errorMsg;
            }
            
            
        }catch(exception e){
            dr.errorFlag = true;
            dr.errorMsg = 'Unexpected Error: '+ e.getLineNumber()+ ' : ' + e.getMessage();
        }
        
        dataReturnVar.add(dr);
        return dataReturnVar;
    }
    
    public static response getXYCordinates(string placeId){
        response res = new response();
        res.errorFlag = false;
        try{
            string url = 'https://maps.googleapis.com/maps/api/place/details/json?placeid='+ placeId+'&key='+getKey();
            
            Http h = new Http();
            HttpRequest req = new HttpRequest();
            HttpResponse response = new HttpResponse();
            req.setMethod('GET');
            req.setEndpoint(url);
            req.setTimeout(120000);
            response = h.send(req); 
            
            if(response.getStatusCode()==200){
                //system.debug('response>> '+ response.getBody());
                Map<String, Object> parsedJson = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                
                if (parsedJson.containsKey('status') && parsedJson.get('status') instanceof String) {
                    String status = (String) parsedJson.get('status');
                    
                    if (status.equals('OK')) {
                        Map<String, Object> result = (Map<String, Object>) parsedJson.get('result');
                        Map<String, Object> geometry = (Map<String, Object>) result.get('geometry');
                        if (geometry != null) {
                            Map<String, Object> location = (Map<String, Object>) geometry.get('location');
                            
                            Object latObj = location.get('lat');
                            Object lngObj = location.get('lng');
                            
                            if (latObj instanceof Double && lngObj instanceof Double) {
                                Double lat = (Double) latObj;
                                Double lng = (Double) lngObj;
                                
                                System.debug('Latitude: ' + lat);
                                System.debug('Longitude: ' + lng);
                                
                                res.latitude = string.valueOf(lat);
                                res.longitude= string.valueOf(lng);
                                return res;
                            } else {
                                System.debug('Latitude and/or Longitude not found or not of the expected type.');
                            }
                        } else {
                            System.debug('Geometry object not found in the JSON.');
                        }
                    } else {
                        System.debug('Status is not "OK".');
                        res.errorFlag = true;
                        res.errorMsg = 'Unable to get address information from google api.';
                        return res;
                    }
                } else {
                    System.debug('Status key not found in the JSON.');
                }
                
            }else{
                system.debug('Unexpected Error: '+ response.getStatusCode()+ ' : '+ response.getBody());
                res.errorFlag = true;
                res.errorMsg = 'Unexpected Error: '+ response.getStatusCode()+ ' : '+ response.getBody();
                return res;
            }
        }
        Catch(exception e){
            system.debug('Unexpected Error: '+ e.getLineNumber()+ ' : '+ e.getMessage());
            res.errorFlag = true;
            res.errorMsg = 'Unexpected Error: '+ e.getLineNumber()+ ' : '+ e.getMessage();
            return res;
        }
        return res;
    }
    
    
    public static response getPlaceId(string address){
        response res = new response();
        res.errorFlag = false;
        try{
            system.debug('https://maps.googleapis.com/maps/api/place/autocomplete/json?input='+ address+'&key='+getKey());
            string url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?input='+ EncodingUtil.urlEncode(address, 'UTF-8')+'&key='+getKey();
            
            Http h = new Http();
            HttpRequest req = new HttpRequest();
            HttpResponse response = new HttpResponse();
            req.setMethod('GET');
            req.setEndpoint(url);
            req.setTimeout(120000);
            response = h.send(req); 
            
            if(response.getStatusCode()==200){
                // system.debug('response>> '+ response.getBody());
                Map<String, Object> parsedResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                if (parsedResponse.get('status').equals('OK')) {
                    List<Object> predictions = (List<Object>) parsedResponse.get('predictions');
                    if (!predictions.isEmpty()) { Map<String, Object> firstPrediction = (Map<String, Object>) predictions[0]; String placeId = (String) firstPrediction.get('place_id');
                        
                        System.debug('Place ID: ' + placeId);
                        res.placeId = placeId; return res;
                    }
                } else {
                    System.debug('Status is not OK');
                    res.errorFlag = true; res.errorMsg = 'Unable to get address information from google api.'; return res;
                }
            }else{
                system.debug('Unexpected Error: '+ response.getStatusCode()+ ' : '+ response.getBody());
                res.errorFlag = true; res.errorMsg = 'Unexpected Error: '+ response.getStatusCode()+ ' : '+ response.getBody(); return res;
            }
            
        }Catch(exception e){
            system.debug('Unexpected Error: '+ e.getLineNumber()+ ' : '+ e.getMessage());
            res.errorFlag = true;
            res.errorMsg = 'Unexpected Error: '+ e.getLineNumber()+ ' : '+ e.getMessage();
            return res;
        }
        return res;
    }
    
    
    
    
    
    public static string getKey(){
        List<PlacesAPI__c> placesAPIs = new List<PlacesAPI__c>();
        
        placesAPIs = [SELECT Id,key__c FROM PlacesAPI__c LIMIT 1];
        
        if(placesAPIs.size()>0){return placesAPIs[0].key__c;
        }
        
        system.debug('##### FlowAddress: #####');
        system.debug('API key not found. Check Custom Settings.');
        return null;
    }
    
    
    public static list<string> makeGeocodingCalloutInvocable(string x, string y) {
       
        list<string> listOfValues = new list<string>();
        Integer calloutNumber = 3;
        try{
            String endpoint = '';
            
                endpoint = System.Label.Census_Demographic_Endpoint
                    + 'x='+x
                    + '&y='+y
                    + '&benchmark=Public_AR_Current'
                    + '&vintage=Census2010_Current'
                    + '&layers=All'
                    + '&format=json';
            
            system.debug('endpoint>> '+ endpoint);
            // Create an HTTP request
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('GET');
            
            Http httpObj = new Http();
            HttpResponse response = httpObj.send(request);
            String GEOID='';
            String CBSA ='';
            String county2 ='';
            String stateCode = '';
            String tract = '';
            boolean checkFlag = false;
            System.debug('response>> '+response.getBody());
            if (response.getStatusCode() == 200) {
                String responseBody = response.getBody();
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                
                Map<String, Object> result = (Map<String, Object>) jsonResponse.get('result');
                system.debug('resutl> '+ result);
                List<Object> addressMatches = (List<Object>) result.get('addressMatches');
                
                if(calloutNumber==3){
                    Map<String, Object> geographies = (Map<String, Object>) result.get('geographies');
                    if(geographies!=null){ checkFlag = true;
                    }
                }
                system.debug('addressMatches>> '+ addressMatches);
                if ((addressMatches != null && !addressMatches.isEmpty()) || checkFlag) {
                    Map<String, Object> geographies = new Map<String, Object>();
                    if(!checkFlag){
                        Map<String, Object> firstAddressMatch = (Map<String, Object>) addressMatches[0];
                        geographies = (Map<String, Object>) firstAddressMatch.get('geographies');
                    }else{ geographies = (Map<String, Object>) result.get('geographies');
                    }
                    List<Object> censusBlocks = (List<Object>) geographies.get('Census Blocks');
                    List<Object> metropolitanDivisions = (List<Object>) geographies.get('Metropolitan Statistical Areas');
                    if(metropolitanDivisions==null || metropolitanDivisions.isEmpty()){ metropolitanDivisions = (List<Object>) geographies.get('Metropolitan Divisions');
                    }
                    List<Object> counties = (List<Object>) geographies.get('Counties');
                    if (censusBlocks != null && !censusBlocks.isEmpty()) {
                        Map<String, Object> firstCensusBlock = (Map<String, Object>) censusBlocks[0];
                        
                        county2 = (String) firstCensusBlock.get('COUNTY');
                        stateCode = (String) firstCensusBlock.get('STATE');
                        tract = (String) firstCensusBlock.get('TRACT');
                        
                        System.debug('County: ' + county2);
                        System.debug('State: ' + stateCode);
                        System.debug('Tract: ' + tract);
                        listOfValues.add(county2);
                        listOfValues.add(stateCode);
                        listOfValues.add(tract);
                        return listOfValues;
                    } else {
                        System.debug('No census blocks found');
                    }
                    
                    if (metropolitanDivisions != null && !metropolitanDivisions.isEmpty()) {
                        Map<String, Object> metropolitanDivision = (Map<String, Object>) metropolitanDivisions[0];
                        
                        CBSA = (String) metropolitanDivision.get('CBSA');
                        GEOID = (String) metropolitanDivision.get('GEOID');
                        system.debug('CBSA>> '+ CBSA);
                        system.debug('GEOID>> '+ GEOID);
                    } else {
                        System.debug('No Metropolitan Divisions found');
                    }
                    
                    if (counties != null && !counties.isEmpty()) { Map<String, Object> county = (Map<String, Object>) counties[0];
                        
                        //GEOID = (String) county.get('GEOID');
                        //system.debug('GEOID>> '+ GEOID);
                    } else {
                        System.debug('No Counties found');
                    }
                    
                    
                } else {
                    System.debug('No address matches found');
                   
                }
                
                
            } else {
                System.debug('Callout error: ' + response.getStatusCode() + ' - ' + response.getStatus());
            }
            
        }
        Catch(exception e){
            system.debug('Unexpected Error Occured!! : '+ e.getLineNumber() + ' : '+ e.getMessage());
        }
        system.debug('listOfValues>>>2 '+ listOfValues);
        return listOfValues;
    }
    
}