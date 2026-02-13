**GetTicketsMD**
 
**Ticket**  
**{**  
string Id;  
string TransactionId;  
string TicketNumber;  
TicketStatus  
{  
Enum ACTIVE = 0, CANCELLEd = 1  
}  
string DeliveryType  
stringBarcodeText  
ManyOwner  
**{**  
string id  
string Identifier  
string FirstName  
string LastName  
string Gender  
**}**  
ManyEvent  
{  
string Id  
DateTimeOffset Date  
ManyStadium   
**{**  
string Id  
string Name  
**}**  
string Name  
string Description  
string HomeTeamLogoUrl  
string AwayTeamLogoUrl  
int MinimumTicketCount  
int MaximumTicketCount  
}  
ManySeat  
**{**  
string Id  
ManyStadium{}  
ManySector   
{  
string Id  
string Name  
string Platform  
List\<ManyCords\>  
**{**  
int x  
int y  
**}**  
}  
string EntranceText  
bool IsNumbered  
string Row  
String Number  
ManyCords {}  
**}**  
ManyPriceInfo  
{  
ManyPriceType  
{  
string id  
string Name  
string PriceTypeCode  
}  
double Price  
double DeliveryPrice  
double TotalPrice  
}  
**}**
 
SeasonCard  
**{**  
string Id;  
string TransactionId;  
string TicketNumber;  
TicketStatus  
{  
Enum ACTIVE = 0, CANCELLEd = 1  
}  
string DeliveryType  
stringBarcodeText  
ManyOwner  
**{**  
string id  
string Identifier  
string FirstName  
string LastName  
string Gender  
**}**  
ManyEvent  
{  
string Id  
DateTimeOffset Date  
ManyStadium   
**{**  
string Id  
string Name  
**}**  
string Name  
string Description  
string HomeTeamLogoUrl  
string AwayTeamLogoUrl  
int MinimumTicketCount  
int MaximumTicketCount  
}  
ManySeat  
**{**  
string Id  
ManyStadium{}  
ManySector   
{  
string Id  
string Name  
string Platform  
List\<ManyCords\>  
**{**  
int x  
int y  
**}**  
}  
string EntranceText  
bool IsNumbered  
string Row  
String Number  
ManyCords {}  
**}**  
ManyPriceInfo  
{  
ManyPriceType  
{  
string id  
string Name  
string PriceTypeCode  
}  
double Price  
double DeliveryPrice  
double TotalPrice  
}  
Int SeasonTicketId:
 
{
 
}  
**}**