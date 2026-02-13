![stat 200 Message nul Orders null VemrCards null Se...](Exported%20image%2020260210144004-0.png) ![Machine generated alternative text EventSeat Seat ...](Exported%20image%2020260210144007-1.png) ![Machine generated alternative text priceType Price...](Exported%20image%2020260210144008-2.png) ![852693 Transaction Id OwnerUserId 1459721 PriceTyp...](Exported%20image%2020260210144009-3.png)

MD Parsed

RAW

Active ticket @newC = 1  
Active ticket @MD = 0 … wut?

{**￼** "start": **0**,**￼** "limit": **100**,**￼** "pageSize": **1**,**￼** "totalSize": **1**,**￼** "hasNext": false,**￼** "hasPrevious": false,**￼** "results": [**￼** {**￼** "id": "852693",**￼** "transactionId": "3408146", +**￼** "cardNumber": "2261", +**￼** "status": **0**,**￼** "owner": {**￼** "id": "1459721",**￼** "identifier": "jsb@manydigital.com", +**￼** "firstname": "Jonas ", +**￼** "lastname": "Buus", +**￼** "gender": "male",**￼** "birthday": "2019-08-23T00:00:00+02:00" +**￼** },**￼** "seat": {**￼** "id": "334142",**￼** "stadium": {**￼** "id": "12",**￼** "name": "Right to Dream Park" +**￼** },**￼** "sector": {**￼** "id": "512",**￼** "name": "RedZone (D)", +**￼** "platform": "JH Container Tribunen", +**￼** "polygon": [**￼** {**￼** "x": **173**,**￼** "y": **484****￼** },**￼** {**￼** "x": **213**,**￼** "y": **484****￼** },**￼** {**￼** "x": **213**,**￼** "y": **137****￼** },**￼** {**￼** "x": **173**,**￼** "y": **119****￼** }**￼** ]**￼** },**￼** "entranceText": "1", +**￼** "isNumbered": true, **￼** "row": "25", +**￼** "number": "2", +**￼** "position": {**￼** "x": **2**,**￼** "y": **25****￼** }**￼** },**￼** "priceInfo": {**￼** "priceType": {**￼** "id": "125",**￼** "name": "FRI", +**￼** "priceTypeCode": "A"**￼** },**￼** "price": **0**,**￼** "deliveryPrice": **0**,**￼** "totalPrice": **0****￼** },**￼** "deliveryType": "Nyt kort",**￼** "barcodeText": "B70AFB5A" +**￼** }**￼** ]**￼**}

Api/GetUserProductsEx? Er det endpoint vi bruger
 
newC er villig til at lave et specifikt kald som giver os kun de information vi har brug for, det gør vores begges idividulle backends hutrigere og bedre. Disse parametre skal de skal defineres.  
Send opfølgende email som definere disse parametre.
 
BarcodeText:  
Status: 1 aktiv

Id: unikke id for seasoncard

SeasonTicketId: 74 \<-- dette bruges til at se hvorvidt der er aktive fremtidige  
seasonTicketEx, [page20](https://manydigital.sharepoint.com/sites/ManyDigital/Shared%20Documents/Code/NewC/RoboticketAPI_v0.23.docx) of documentation returns List\<ApiEvent\>  
==class ApiEvent :== ApiBaseProduct  
=={==  
==string Date { get; set; }==  
==int StadiumId { get; set; }==  
==int MinimumTicketCount { get; set; }==  
==int MaximumTicketCount { get; set; }==  
==string DisplayDate { get; set; }==  
==bool TakeFirstFreeSeat { get; set; }==  
==string Motto { get; set; }==  
string HomeTeamLogo { get; set; }  
string AwayTeamLogo { get; set; }  
==string HomeTeamLogoUrl { get; }==  
==string AwayTeamLogoUrl { get; }==  
==bool DontShowInSeasonTicket { get; set; }==  
==}==

Mads  
mhc@newC.dk