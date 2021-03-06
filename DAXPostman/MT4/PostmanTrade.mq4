//+------------------------------------------------------------------+
//|                                                 PostmanTrade.mq4 |
//|                                    unimatrix27 based on ICE blog |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "unimatrix27 based on ICE blog"
#property link      ""
#property version   "1.00"
#property strict
extern double rSize = 1;         // wieviel % Kapital = 1 R
extern double stopLoss   =1;     // StopLoss Faktor
extern double takeProfit =1;      // TakeProfit Faktor in R
extern double ssThreshold = 20;    // Stochastik-Grenze (20 entspricht 80/20)
extern double rsiLowerLong = 45;      // RSI Mininum Long
extern double rsiUpperLong = 100;      // RSI Maximum Long
extern double rsiLowerShort = 0;      // RSI Mininum Short
extern double rsiUpperShort = 55;      // RSI Maximum Short

// TODO
extern int numberOfOpenTrades = 1;    // Maximale gleichzeitige Trades

extern int expireDuration = 6;    // Gültigkeit offener Orders in Stunden
extern int ssCountLong=3 ;          // Kerzenanzahl Long Stochastik-Extrem
extern int ssCountShort=3 ;          // Kerzenanzahl Short Stochastik-Extrem

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
// Ausgabe von ein paar Infos über den gehandelten Markt - nur zu Testzwecken
   Print("Symbol=",Symbol()); 
   Print("Low day price=",MarketInfo(Symbol(),MODE_LOW)); 
   Print("High day price=",MarketInfo(Symbol(),MODE_HIGH)); 
   Print("The last incoming tick time=",(MarketInfo(Symbol(),MODE_TIME))); 
   Print("Last incoming bid price=",MarketInfo(Symbol(),MODE_BID)); 
   Print("Last incoming ask price=",MarketInfo(Symbol(),MODE_ASK)); 
   Print("Point size in the quote currency=",MarketInfo(Symbol(),MODE_POINT)); 
   Print("Digits after decimal point=",MarketInfo(Symbol(),MODE_DIGITS)); 
   Print("Spread value in points=",MarketInfo(Symbol(),MODE_SPREAD)); 
   Print("Stop level in points=",MarketInfo(Symbol(),MODE_STOPLEVEL)); 
   Print("Lot size in the base currency=",MarketInfo(Symbol(),MODE_LOTSIZE)); 
   Print("Tick value in the deposit currency=",MarketInfo(Symbol(),MODE_TICKVALUE)); 
   Print("Tick size in points=",MarketInfo(Symbol(),MODE_TICKSIZE));  
   Print("Swap of the buy order=",MarketInfo(Symbol(),MODE_SWAPLONG)); 
   Print("Swap of the sell order=",MarketInfo(Symbol(),MODE_SWAPSHORT)); 
   Print("Market starting date (for futures)=",MarketInfo(Symbol(),MODE_STARTING)); 
   Print("Market expiration date (for futures)=",MarketInfo(Symbol(),MODE_EXPIRATION)); 
   Print("Trade is allowed for the symbol=",MarketInfo(Symbol(),MODE_TRADEALLOWED)); 
   Print("Minimum permitted amount of a lot=",MarketInfo(Symbol(),MODE_MINLOT)); 
   Print("Step for changing lots=",MarketInfo(Symbol(),MODE_LOTSTEP)); 
   Print("Maximum permitted amount of a lot=",MarketInfo(Symbol(),MODE_MAXLOT)); 
   Print("Swap calculation method=",MarketInfo(Symbol(),MODE_SWAPTYPE)); 
   Print("Profit calculation mode=",MarketInfo(Symbol(),MODE_PROFITCALCMODE)); 
   Print("Margin calculation mode=",MarketInfo(Symbol(),MODE_MARGINCALCMODE)); 
   Print("Initial margin requirements for 1 lot=",MarketInfo(Symbol(),MODE_MARGININIT)); 
   Print("Margin to maintain open orders calculated for 1 lot=",MarketInfo(Symbol(),MODE_MARGINMAINTENANCE)); 
   Print("Hedged margin calculated for 1 lot=",MarketInfo(Symbol(),MODE_MARGINHEDGED)); 
   Print("Free margin required to open 1 lot for buying=",MarketInfo(Symbol(),MODE_MARGINREQUIRED)); 
   Print("Order freeze level in points=",MarketInfo(Symbol(),MODE_FREEZELEVEL));  
    printf("ACCOUNT_BALANCE =  %G",AccountInfoDouble(ACCOUNT_BALANCE)); 
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
  
   double minimumLotSize;
   double currentFreeMargin;
   double priceOfOneLot;
   double newBuyOpen;
   double newSellOpen;
   double newBuyStopLoss;
   double newBuyTakeProfit;
   double newSellStopLoss;
   double newSellTakeProfit;
   double candleSize;
   double size;
   
   double lotSize;
   double balance;
   
   double lotStep;
   int    currentTicketNumberLong;
   int    currentTicketNumberShort;
   
   MqlDateTime currentTimeMql;
   datetime    searchTime;
   datetime    expireTime;
   
   // JFD ist eine Stunde hinterher - nicht immer. Ob es gerade so ist kann man durch den Vergleich von TimeLocal und TimeCurrent herausfinden
   int hourShift = (TimeLocal()-TimeCurrent())/3600;
   
   // Im Backtest tun wir so als wären wir immer eine Stunde hinterher. Das muss berücksichtigt werden, je nachdem welche historischen Daten man benutzt
   // Download über Tickstory und Import in den MT4 JFD mit Zeitzone GMT, dann geht es. Vorsicht: Wenn das nicht stimmt, wird die falsche Kerze gehandelt.
   if(IsTesting()) hourShift = -1;
   
   
//---
   //--------------------------------------------------------------- 3 --
   // Erstmal schauen, ob der EA überhaupt in einer gültigen Umgebung läuft, sonst abbrechen
   if(Bars < 60)                       // Not enough bars
     {
      Alert("Nicht genügend Daten / Kerzen");
      return;                                   // Exit start()
     }
   if(Period() != PERIOD_M1 
   && Period() != PERIOD_M5
   && Period() != PERIOD_M15
   && Period() != PERIOD_M30
   && Period() != PERIOD_H1)                              // Critical error
     {
      Alert("EA ist nur für den Stundenchart H1 oder kleiner (M1,M5,M15,M30) funktionsfähig");
      return;                                   // Exit start()
     }
    if(rsiUpperShort<=rsiLowerShort || rsiUpperLong<=rsiLowerLong){
       Alert("Ungültige Werte für RSI Schwellen");
       return;
    }


    // Einige Daten abfragen, die für die sinnvolle Berechnung einer Positionsgröße gebraucht werden.
    
   RefreshRates();                                                 // Daten aktuell halten
   minimumLotSize    = MarketInfo(Symbol(),MODE_MINLOT);           // Was ist die Mindestgröße, die im aktuellen Wert gehandelt werden muss
   currentFreeMargin = AccountFreeMargin();                        // Wieviel Margin ist im Moment frei
   priceOfOneLot     = MarketInfo(Symbol(),MODE_MARGINREQUIRED);   // Wie teuer ist 1 Lot
   lotStep           = MarketInfo(Symbol(),MODE_LOTSTEP);          // In welcher Schrittweite kann die Lotgröße verändert werden
   lotSize           = MarketInfo(Symbol(),MODE_LOTSIZE);          // In welcher Schrittweite kann die Lotgröße verändert werden
   balance           = AccountInfoDouble(ACCOUNT_BALANCE);         // Kontostand

   TimeToStruct(Time[0],currentTimeMql);                          // Die aktuelle Zeit in die MQL Struktur Form bringen, damit wir die Stunde besser aendern können


   // Testen ob offene Orders da sind
   
   if(OrdersTotal()>0) return;

   // Neue Orders öffnen?
     
   if (currentTimeMql.hour > 9+hourShift && currentTimeMql.hour < 9+(expireDuration+hourShift)){      // Wir öffnen neue Orders bzw. Trades nur zwischen 10 und 10+ExpireDuration Uhr. 
      //Print(currentTimeMql.hour);
      currentTimeMql.hour=9+hourShift;                                                // drehen wir die Zeit zurück in die 9 Uhr Kerze, um sie dann zu finden
      searchTime = StructToTime(currentTimeMql);                                      // Zeit umwandeln, wichtig für iBarShift
      currentTimeMql.hour = 9+expireDuration+hourShift;                                              // Zeit finden, bis wann eine neue Order gueltig sein soll
      int found  = iBarShift(Symbol(),PERIOD_H1,searchTime);                          // Wir suchen den Index der 9 Uhr Kerze
      expireTime = StructToTime(currentTimeMql);                                      // bis wann sind ggf. neue Orders heute gueltig?
      if(found<1) return;                                                             // Fehler, weil unerwarteter Wert
      
      if (iHighest(Symbol(),PERIOD_H1,MODE_HIGH,found+1) == found                       // Wurde das Hoch der 9 Uhr Kerze noch nicht überschritten 
       && iLowest (Symbol(),PERIOD_H1,MODE_LOW ,found+1) == found){                     // und das Tief noch nicht unterschritten? Nur dann ist Signal noch scharf.
                
         // Ermitteln der Trademarken / Hoch und Tief der Signalkerze jeweils         
         newBuyOpen = NormalizeDouble(iHigh(Symbol(),PERIOD_H1,found),MarketInfo(Symbol(),MODE_DIGITS));  // Stop Buy Level
         newSellOpen =  NormalizeDouble(iLow(Symbol(),PERIOD_H1,found),MarketInfo(Symbol(),MODE_DIGITS)); // Stop Sell Level
         
         candleSize = newBuyOpen - newSellOpen;                                         // Spanne der Signalkerze
         
         newBuyStopLoss = newBuyOpen - (candleSize*stopLoss);                           // Stop Loss Level der Kauforder
         newSellStopLoss = newSellOpen + (candleSize*stopLoss);                         // Stop Loss Level der Verkaufsorder
         newBuyTakeProfit = newBuyOpen + (candleSize*stopLoss*takeProfit);                       // TP Level der Kauforder
         newSellTakeProfit = newSellOpen - (candleSize*stopLoss*takeProfit);                     // TP Level der Verkaufsorder
         
         if(candleSize ==0 || lotSize ==0) return;
         size = (rSize*balance/100) / (candleSize*stopLoss*lotSize) ;                         // Positionsgroesse ist 1% der Balance geteilt durch die Kerzengröße multipliziert mit SL Faktor und der Größe eines Lots
         
         size=NormalizeDouble(size,1); // nachkommastellen abschneiden (Losgröße bei JFD ist 0.1
         
         double ss = iStochastic(Symbol(),PERIOD_H1,7,3,3,MODE_SMA,0,MODE_MAIN,found);       // Das ist der Stochastik bei der Signalkerze
         //double ssPrev= iStochastic(Symbol(),PERIOD_H1,7,3,3,MODE_SMA,0,MODE_MAIN,found+1);  // Das ist der Stochastik bei der Kerze vor der Signalkerze
         //double ssPrev2= iStochastic(Symbol(),PERIOD_H1,7,3,3,MODE_SMA,0,MODE_MAIN,found+2); // Das ist der Stochastik bei 2 Kerzen vor der Signalkerze
         double rsi = iRSI(Symbol(),PERIOD_H1,12,PRICE_CLOSE,found);                         // RSI bei der Signalkerze
         
         double ssS = 100-ssThreshold;    // Oberer WErt für Stochastik (normal 80)
         double ssL = ssThreshold;        // Unterer Wert, normal 20
         
         //if((ssPrev2>=ssS || ssPrev>=ssS) && ss<ssS && rsi>=rsiL && rsi<rsiU){  // Note 1 Filter mit RSI und SS
         if(   ssMaxMin(Symbol(),PERIOD_H1,7,3,3,MODE_SMA,0,MODE_MAIN,found,ssCountShort,TRUE)>ssS // War der Stochastik in den letzten ssCountShort Kerzen im Extrembereich
            && ss  <  ssS                                                                              // und ist er jetzt nicht mehr im Extrembereich
            && rsi <= rsiUpperShort                                                                 // ist der RSI unter der oberen Schwelle für Short
            && rsi >= rsiLowerShort                                                              // ist der RSI über der unteren Schwelle für Short
            ){
            // StopSell Order mit angehängtem SL und TP erstellen. Die Order läuft automatisch nach der eingestellten Anzahl Stunden ab, wenn sie nicht gefillt wird
            currentTicketNumberShort=OrderSend(Symbol(),OP_SELLSTOP,size,newSellOpen,5,newSellStopLoss,newSellTakeProfit,NULL,0,expireTime,clrRed);   
                        Print("Short");
            Print(rsi);
         }
         if(    ssMaxMin(Symbol(),PERIOD_H1,7,3,3,MODE_SMA,0,MODE_MAIN,found,ssCountLong,FALSE)<ssL
             && ss  >  ssL 
             && rsi <= rsiUpperLong
             && rsi >= rsiLowerLong){
         //if((ssPrev2<=ssL || ssPrev<=ssL) && ss>ssL && rsi>=rsiL && rsi<rsiU){  // Note 1 Filter mit RSI und SS
            
            // StopBuy Order mit angehängtem SL und TP erstellen. Die Order läuft automatisch nach der eingestellten Anzahl Stunden ab, wenn sie nicht gefillt wird
            currentTicketNumberLong =OrderSend(Symbol(),OP_BUYSTOP ,size,newBuyOpen ,5,newBuyStopLoss, newBuyTakeProfit,NULL,0,expireTime,clrGreen);  
            Print("Long");
            Print(rsi);
         }
         
      }
     
   }
   
//+------------------------------------------------------------------+
}

double ssMaxMin(const string symbol, int timezone, int K_period, int d_period,int slowing,ENUM_MA_METHOD method,ENUM_STO_PRICE priceField,int mode, int shift, int count, bool max=TRUE, int buffer=50){
   int result;
   int temp;
   while(count>0){
      result=iStochastic(symbol,timezone,K_period,d_period,slowing,method,priceField,mode,shift+count--);
      if(max==TRUE && result>buffer) buffer=result;
      if(max==FALSE && buffer<result) buffer=result;
   }
   return buffer;
}
 