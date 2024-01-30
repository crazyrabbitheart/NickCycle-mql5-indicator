//+------------------------------------------------------------------+
//|                                        Nicks Cycle Indicator.mq5 |
//|                                     Copyright 2023, Leo Korhonen |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Leo Korhonen"
#property version   "1.11"

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots 2

#property indicator_label1  "Stochastic-Main"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "Stochastic-Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

enum ENUM_ACTIVE_INTERVAL{
   QUARTER = 0,      // 15 minutes
   HALF_HOUR = 1,    // 30 minutes    
   ONE_HOUR  = 2,    // 1 hour
   TWO_HOUR = 3,     // 2 hours
   FOUR_HOUR = 4,    // 4 hours
};

//enum ENUM_TIME{
//   FIVE = PERIOD_M5,         // 5 minutes
//   FIFTH = PERIOD_M15,       // 15 minutes
//   THIRTY = PERIOD_M30,      // 30 minutes
//};

enum Price {
   a,//Low/High
   b //Close/Close
};

input group "--- [1] Support and Resistance Levels ---";
//input double baseValue = 17080.0;  // Base Level
input bool applySR = true;                //Turn On/Off S&R Rule
input double in_d_gap_of_levels = 10;     // Gap between Levels

input group "--- [2] EMA ---";
input int emaPeriod = 20;        // EMA period
input bool shortTrigger = false;       // Turn On/Off MA Trigger
input bool setEmaAngle = false;        // Turn On/Off MA Angle Trigger
input double emaAngleThreshold = 5.0;  // Angle Value For MA Trigger
input bool reserveEma = false;         // Turn On/Off Reserve Rule

input group "--- [3] RSI ---";
input int rsiPeriod = 14;        // RSI period

input group "--- [4] TRIX ---";
input double trixSense = 5.0;          // TrixSensitivity
input double trixRSIHigh = 55.0;       // RSI High value for Trix
input double trixRSILow = 45.0;        // RSI Low value for Trix

input group "--- [5] solider ---";
input bool solider = false;            // Turn On/Off solider
input double soliderRSIHigh = 55.0;    // RSI High value for solider
input double soliderRSILow = 45.0;     // RSI Low value for solider
input int soliderCount = 2;            // solider Candle Count

input group "--- [6] MTF Stochastic ---";
input bool stochastic = false;               // Turn On/Off MTF Stochastic
input ENUM_TIMEFRAMES tf = 5;                // Time Frame 
input int InpKPeriod = 5;                    // K period
input int InpDPeriod = 3;                    // D period
input int InpSlowing = 3;                    // Slowing
input ENUM_MA_METHOD InpMethod = MODE_SMA;   // Moving average method
input Price InpAppliedPrice = a;             // Applied price
input int Bars_Calculated = 500;             // Stochastic slowing
input double MTFHigh = 70;                   // MTF High Threshold
input double MTFLow = 30;                    // MTF Low Threshold

input group "--- [7] Time Range ---";
input ENUM_ACTIVE_INTERVAL enai_current = HALF_HOUR;  // Active Interval
input int timeOption = 5;                             // Bar Count

input group "--- [8] Notify ---";
input bool emailAlert = true;          // Turn on/off Email Alert
input bool SMSAlert = true;            // Turn on/off SMS Alert
input bool soundAlert = true;          // Turn on/off Sound Alert

input group "--- [9] Display ---";
input bool showSRLine = true;          // Show S&R Line
//input bool emaLine = false;          // Show EMA Line
input bool showTimeLine = true;        // Show Time Line
input datetime setDayforShowTimeLine = D'2024.01.01';   // Set days For History
input int arrowSize = 5;               // Set Arrow Size
input color arrowBuyColor = clrGreen;  // Set Buy Arrow Color
input color arrowSellColor = clrRed;   // Set Sell Arrow Color

double bufferEma[];
double bufferEmaColor[];
double bufferRsi[];
double bufferTema[];
double bufferStochMain[];
double bufferStochSignal[];

double baseValue = 17080.0;
double gapSize;
bool isMSGReady = false;

int MA_handle;
int EMA_handle;
int RSI_handle;
int Stochastic_handle;

int ExtBarsMinimum;
int draw_begin1;
int draw_begin2;
ENUM_STO_PRICE price;
ENUM_TIMEFRAMES _tf;
int pf;
int bars_calculated=0;
bool Interpolate = true;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
   baseValue = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

   if (baseValue)
      gapSize = in_d_gap_of_levels * 10 * SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);   
   
   string SRLineName = "";
   for (int i = -3; i <= 3; i++){
      SRLineName = "S&R-Horizontal" + IntegerToString(i);
      if(!ObjectCreate(0, SRLineName, OBJ_HLINE, 0, 0, baseValue + gapSize * i)){ 
         Print(__FUNCTION__, ": failed to create a horizontal line! Error code = ",GetLastError()); 
         return(false); 
      } 
      if (showSRLine || applySR){
         if (i > 0)
            ObjectSetInteger(0,SRLineName,OBJPROP_COLOR,clrBlue); 
         else if (i == 0)
            ObjectSetInteger(0,SRLineName,OBJPROP_COLOR,clrLime); 
         else if (i < 0)
            ObjectSetInteger(0,SRLineName,OBJPROP_COLOR,clrCrimson); 
      }else{
         ObjectSetInteger(0,SRLineName,OBJPROP_COLOR,clrNONE); 
      }      
      ObjectSetInteger(0,SRLineName,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,SRLineName,OBJPROP_WIDTH,1);
   }
   
   //EMA handle
   EMA_handle = iCustom(NULL, 0,"Examples\\DEMA", emaPeriod, 0, MODE_EMA, PRICE_CLOSE);   
   if(EMA_handle != INVALID_HANDLE)
      Print("DEMA loads successfully");
      
   //RSI handle
   RSI_handle = iCustom(NULL, 0,"Examples\\RSI", rsiPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(RSI_handle != INVALID_HANDLE)
      Print("RSI loads successfully");   
      
   //TRIX handle
   MA_handle = iCustom(NULL, 0, "Examples\\TRIX", trixSense, 0, MODE_EMA, PRICE_CLOSE);
   if(MA_handle != INVALID_HANDLE)
      Print("TRIX loads successfully");
   
   //stochastic handle   
   SetIndexBuffer(0,bufferStochMain,INDICATOR_DATA);
   SetIndexBuffer(1,bufferStochSignal,INDICATOR_DATA);
   _tf=tf;
   ENUM_TIMEFRAMES timeframe;
   draw_begin1 = InpKPeriod + InpSlowing - 2;   // initial PLOT_DRAW_BEGIN value
   draw_begin2 = InpKPeriod + InpDPeriod;       // initial PLOT_DRAW_BEGIN value   
   
   timeframe = _Period;
   if (_tf <= timeframe)
      _tf=timeframe;// if the TF is less than or is equal to the current one, set it to PERIOD_CURRENT
   pf = (int)MathFloor(_tf / timeframe);// calculate coefficient for PLOT_DRAW_BEGIN, PLOT_SHIFT and the number of calculation bars.
   draw_begin1 = draw_begin1 * pf;// calculate PLOT_DRAW_BEGIN 1
   draw_begin2 = draw_begin2 * pf;// calculate PLOT_DRAW_BEGIN 2
   
   PlotIndexSetInteger(1,PLOT_LINE_STYLE,STYLE_DOT);   
   IndicatorSetString(INDICATOR_SHORTNAME,"MTF_Stochastic M"+string(tf)+" ("+string(InpKPeriod)+" "+string(InpDPeriod)+" "+string(InpSlowing)+")");//name for DataWindow
   PlotIndexSetString(0,PLOT_LABEL,"Main");
   PlotIndexSetString(1,PLOT_LABEL,"Signal");   
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   IndicatorSetInteger(INDICATOR_DIGITS,2);
   IndicatorSetInteger(INDICATOR_LEVELS,2);
   IndicatorSetDouble(INDICATOR_LEVELVALUE,0,30);
   IndicatorSetDouble(INDICATOR_LEVELVALUE,1,70);
   IndicatorSetDouble(INDICATOR_MINIMUM,0);
   IndicatorSetDouble(INDICATOR_MAXIMUM,100);
   
   if(InpAppliedPrice == a)
      price=STO_LOWHIGH;
   else
      price=STO_CLOSECLOSE;
   
   Stochastic_handle=iStochastic(NULL,_tf,InpKPeriod,InpDPeriod,InpSlowing,InpMethod,price); //get Stochastic's handles
   
   if(Stochastic_handle==INVALID_HANDLE){
      Print("getting Stochastic Handle is failed! Error",GetLastError());
      return(INIT_FAILED);
   }
   
   ExtBarsMinimum=(InpKPeriod+InpDPeriod+InpSlowing)*pf;// calculate the minimum required number of bars for the calculation
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {   
   ObjectsDeleteAll(0,-1,-1);
}

//+------------------------------------------------------------------+
//| Custom indicator calculation function                            |
//+------------------------------------------------------------------+

datetime lastTickTime = 0;       // Variable to store the time of the last known bar

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {
   
   datetime currentChartTime = iTime(_Symbol, _Period, 0);   
   
   CopyBuffer(MA_handle,0,0,rates_total,bufferTema);
   CopyBuffer(EMA_handle,0,0,rates_total,bufferEma);
   CopyBuffer(RSI_handle,0,0,rates_total,bufferRsi); 
   
   MqlDateTime cmdt;
   TimeToStruct(currentChartTime, cmdt);
   
   MqlDateTime nmdt;
   TimeToStruct(NotificationTime, nmdt);

   if (cmdt.min != nmdt.min)
      if (isMSGReady){
         Notify();
      }
   
   //if bar is closed, start calculate
   if (currentChartTime == lastTickTime)
      return rates_total;
   else
      currentChartTime = lastTickTime;

   //calculate and draw mtf stochastic
   if(stochastic){
      if(rates_total<ExtBarsMinimum+pf)
         return(rates_total);
      int limit;
      if(Bars_Calculated!=0){draw_begin1=Bars(NULL,0)-Bars_Calculated;draw_begin2=draw_begin1;}
   
      PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,draw_begin1+pf);
      PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,draw_begin2+pf);
   
      ArraySetAsSeries(time,true);
      ArraySetAsSeries(bufferStochMain,true);
      ArraySetAsSeries(bufferStochSignal,true);
   
      int calculated=BarsCalculated(Stochastic_handle);
   
      if(calculated<=0){
         Print("Not all data of Handle is calculated (",calculated,"bars ). Error",GetLastError());
         return(0);
      }
   
      if(prev_calculated>rates_total || prev_calculated<=0|| calculated!=bars_calculated){
         limit=rates_total-ExtBarsMinimum-1; 
      }else{
         limit=(rates_total-prev_calculated)+pf+1; // starting index for calculation of new bars
      }
      
      if(Bars_Calculated!=0)   limit=MathMin(Bars_Calculated,limit);
   
      for(int i=limit;i>=0 && !IsStopped();i--){
         int n;
         datetime t=time[i];
         bufferStochMain[i]=_CopyBuffer(Stochastic_handle,t,0);
         bufferStochSignal[i]=_CopyBuffer(Stochastic_handle,t,1);
         if(!Interpolate) continue;
         
         datetime times= _iTime(t);
         for(n = 1; i + n < limit + 1 && time[i+n] >= times; n++) 
            continue;
            
         double factor=1.0/n;
         for(int k=1; k<n; k++){
            bufferStochMain[i+k]=k*factor*bufferStochMain[i+n]+(1.0-k*factor)*bufferStochMain[i];
            bufferStochSignal[i+k]=k*factor*bufferStochSignal[i+n]+(1.0-k*factor)*bufferStochSignal[i];
         }
      }
   
      bars_calculated=calculated;
      
      ArraySetAsSeries(time,false);
      ArraySetAsSeries(bufferStochMain,false);
      ArraySetAsSeries(bufferStochSignal,false);
   }
   //printf("stochastic-----%f", bufferStochastic[rates_total-1]);
   
   int i=(int)MathMax(prev_calculated-1,1); 
   for(; i < rates_total && !_StopFlag; i++) {     
      
      if (time[i] > setDayforShowTimeLine){
      
         ObjectCreate(0,"EMALine", OBJ_TREND, 0, iTime(_Symbol,_Period, 1), bufferEma[i-1],iTime(_Symbol,_Period,0), bufferEma[i]);
         ObjectSetInteger(0, "EMALine", OBJPROP_RAY,false);
         
         if(bufferRsi[i] >= 30 && bufferRsi[i] <= 70)
            ObjectSetInteger(0, "EMALine", OBJPROP_COLOR,clrGreen);
         else
            ObjectSetInteger(0, "EMALine", OBJPROP_COLOR,clrRed);
         ObjectSetInteger(0, "EMALine", OBJPROP_WIDTH, 10);
         ObjectSetInteger(0, "EMALine", OBJPROP_STYLE, STYLE_SOLID);
         
         //printf("ema---%d--%f", i, bufferEma[i]);
         //printf("rsi---%d--%f", i, bufferRsi[i]);
         
         MqlDateTime mdt;
         TimeToStruct(time[i], mdt);            
      
         int HLineCount = ObjectsTotal(0, 0, OBJ_HLINE);         
         //printf("HLine---%d", HLineCount);
         
         double bufferSR[];
         ArrayResize(bufferSR, HLineCount);
         
         string objectName = "";
         for (int j = 0; j < ObjectsTotal(0, 0, OBJ_HLINE); j++){
            objectName = ObjectName(0, j);         
            if (StringFind(objectName, "Horizontal", 0) > 0){
               //printf("price %f", ObjectGetDouble(0, objectName, OBJPROP_PRICE));
               bufferSR[j] = ObjectGetDouble(0, objectName, OBJPROP_PRICE);
            }
         }
         
         bool in_session = false;
         if (enai_current == QUARTER){
            for (int i=-timeOption; i<=timeOption; i++)
               if (mdt.min == (60 + i) % 60 || mdt.min == (i + 15) % 60 || mdt.min == (i + 30) % 60 || mdt.min == (i + 45) % 60){
                  in_session = true;
               }
         }else if (enai_current == HALF_HOUR){
            for (int i=-timeOption; i<=timeOption; i++)
               if (mdt.min == (60 + i) % 60 || mdt.min == (i + 30) % 60){
                  in_session = true;
               }
         }else if (enai_current == ONE_HOUR){
            for (int i=-timeOption; i<=timeOption; i++)
               if (mdt.min == (60 + i) % 60){
                  in_session = true;
               }
         }else if (enai_current == TWO_HOUR) {
            for (int i=-timeOption; i<=timeOption; i++)
               if ((mdt.hour % 2 == 0 && i >= 0 && mdt.min == (60 + i) % 60) || (mdt.hour % 2 == 1 && i < 0 && mdt.min == (60 + i) % 60)){
                  in_session = true;
               }   
         }else if (enai_current == FOUR_HOUR) {
            for (int i=-timeOption; i<=timeOption; i++)
               if ((mdt.hour % 4 == 0 && i >= 0 && mdt.min == (60 + i) % 60) || (mdt.hour % 4 == 3 && i < 0 && mdt.min == (60 + i) % 60)){
                  in_session = true;
               }
         }
         if (in_session){
            if(showTimeLine){
               string line_name = "Time Range" + IntegerToString(i);
               ObjectCreate(0, line_name, OBJ_VLINE, 0, time[i], 0);
               ObjectSetInteger(0, line_name, OBJPROP_COLOR, clrGray);
               ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, line_name, OBJPROP_SELECTABLE, false);
            }
            double pipsize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
            //printf("ticksize %f", pipsize);
            
            double angle_rad = MathArctan((bufferEma[i] - bufferEma[i-1]) / (1.0 * Period()));
            double emaAngle = angle_rad * 180 / M_PI;
            //printf("angle_rad %f", angle_rad);
            //printf("emaAngle %f", emaAngle);
            if (i > 0){
               if (shortTrigger && !solider){
                  if (close[i] > close[i-1] && bufferRsi[i] <= trixRSILow){
                     if (close[i] > bufferEma[i] || (close[i] > bufferEma[i] && open[i] < bufferEma[i])){
                        if (!setEmaAngle ||
                         (!reserveEma && setEmaAngle && MathAbs(emaAngle) > emaAngleThreshold) ||
                         (reserveEma && setEmaAngle && MathAbs(emaAngle) < emaAngleThreshold && MathAbs(emaAngle) > 0)
                        )
                           if (applySR){
                              for (int j=0; j<ArraySize(bufferSR); j++){
                                 if (open[i] < bufferSR[j] && close[i] > bufferSR[j]){
                                    if(bufferTema[i] >= 0 && bufferTema[i-1] < 0){
                                       string ArrowUpName = "ArrowUp" + IntegerToString(i);
                                       ObjectCreate(0, ArrowUpName, OBJ_ARROW_UP, 0, time[i], low[i] - 3 * pipsize);
                                       ObjectSetInteger(0, ArrowUpName, OBJPROP_COLOR, arrowBuyColor);
                                       ObjectSetInteger(0, ArrowUpName, OBJPROP_STYLE, STYLE_SOLID);                        
                                       ObjectSetInteger(0, ArrowUpName, OBJPROP_WIDTH, arrowSize);
                                       if(i == rates_total - 1){
                                          NotificationLevel = bufferSR[j];
                                          if (!reserveEma)
                                             makeMSG("buy");
                                          else
                                             makeMSG("reserve");
                                       }
                                       //Print("Buy");
                                    }
                                 }
                              }
                           } else if (!applySR){
                              if(bufferTema[i] >= 0 && bufferTema[i-1] < 0){
                                 string ArrowUpName = "ArrowUp" + IntegerToString(i);
                                 ObjectCreate(0, ArrowUpName, OBJ_ARROW_UP, 0, time[i], low[i] - 3 * pipsize);
                                 ObjectSetInteger(0, ArrowUpName, OBJPROP_COLOR, arrowBuyColor);
                                 ObjectSetInteger(0, ArrowUpName, OBJPROP_STYLE, STYLE_SOLID);                        
                                 ObjectSetInteger(0, ArrowUpName, OBJPROP_WIDTH, arrowSize);
                                 if(i == rates_total - 1){
                                    NotificationLevel = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                                    if (!reserveEma)
                                       makeMSG("buy");
                                    else
                                       makeMSG("reserve");
                                 }
                                 //Print("Buy");
                              }
                           }
                     }
                  } else if (close[i] < close[i-1] && bufferRsi[i] >= trixRSIHigh){
                     if (close[i] < bufferEma[i] || (close[i] < bufferEma[i] && open[i] > bufferEma[i])){
                        if (!setEmaAngle ||
                         (!reserveEma && setEmaAngle && MathAbs(emaAngle) > emaAngleThreshold) ||
                         (reserveEma && setEmaAngle && MathAbs(emaAngle) < emaAngleThreshold && MathAbs(emaAngle) > 0)
                        )
                           if(applySR){
                              for (int j=0; j<ArraySize(bufferSR); j++){
                                 if (open[i] > bufferSR[j] && close[i] < bufferSR[j]){
                                    if (bufferTema[i] <= 0 && bufferTema[i-1] > 0){
                                       string ArrowDownName = "ArrowDown" + IntegerToString(i);
                                       ObjectCreate(0, ArrowDownName, OBJ_ARROW_DOWN, 0, time[i], high[i] + 3 * pipsize );
                                       ObjectSetInteger(0, ArrowDownName, OBJPROP_COLOR, arrowSellColor);
                                       ObjectSetInteger(0, ArrowDownName, OBJPROP_STYLE, STYLE_SOLID);
                                       ObjectSetInteger(0, ArrowDownName, OBJPROP_WIDTH, arrowSize);
                                       ObjectSetInteger(0, ArrowDownName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
                                       if(i == rates_total - 1){
                                          NotificationLevel = bufferSR[j];
                                          if (!reserveEma)
                                             makeMSG("sell");
                                          else
                                             makeMSG("reserve");
                                       }
                                       //Print("Sell");
                                    }
                                 }
                              }
                           }else if (!applySR){
                              if (bufferTema[i] <= 0 && bufferTema[i-1] > 0){
                                 string ArrowDownName = "ArrowDown" + IntegerToString(i);
                                 ObjectCreate(0, ArrowDownName, OBJ_ARROW_DOWN, 0, time[i], high[i] + 3 * pipsize );
                                 ObjectSetInteger(0, ArrowDownName, OBJPROP_COLOR, arrowSellColor);
                                 ObjectSetInteger(0, ArrowDownName, OBJPROP_STYLE, STYLE_SOLID);
                                 ObjectSetInteger(0, ArrowDownName, OBJPROP_WIDTH, arrowSize);
                                 ObjectSetInteger(0, ArrowDownName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
                                 if(i == rates_total - 1){
                                    NotificationLevel = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                                    if (!reserveEma)
                                       makeMSG("sell");
                                    else
                                       makeMSG("reserve");
                                 }
                                 //Print("Sell");
                              }
                           }   
                     }
                  }
               }else if (!shortTrigger && !solider){
                  if (close[i] > close[i-1] && bufferRsi[i] <=trixRSILow){
                     if (!setEmaAngle ||
                         (!reserveEma && setEmaAngle && MathAbs(emaAngle) > emaAngleThreshold) ||
                         (reserveEma && setEmaAngle && MathAbs(emaAngle) < emaAngleThreshold && MathAbs(emaAngle) > 0)
                        )
                        if(applySR){
                           for (int j=0; j<ArraySize(bufferSR); j++){
                              if (open[i] < bufferSR[j] && close[i] > bufferSR[j]){
                                 if(bufferTema[i] >= 0 && bufferTema[i-1] < 0){
                                    if (!reserveEma || (reserveEma && bufferEma[i] > close[i])){
                                       string ArrowUpName = "ArrowUp" + IntegerToString(i);
                                       ObjectCreate(0, ArrowUpName, OBJ_ARROW_UP, 0, time[i], low[i] - 3 * pipsize);
                                       ObjectSetInteger(0, ArrowUpName, OBJPROP_COLOR, arrowBuyColor);
                                       ObjectSetInteger(0, ArrowUpName, OBJPROP_STYLE, STYLE_SOLID);                        
                                       ObjectSetInteger(0, ArrowUpName, OBJPROP_WIDTH, arrowSize);
                                       //ObjectSetInteger(0, ArrowUpName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
                                       if(i == rates_total - 1){
                                          NotificationLevel = bufferSR[j];
                                          if (!reserveEma)
                                             makeMSG("buy");
                                          else
                                             makeMSG("reserve");
                                       }
                                    }                                    
                                 }
                              }
                           }
                        }else if (!applySR){
                           if(bufferTema[i] >= 0 && bufferTema[i-1] < 0){
                              if (!reserveEma || (reserveEma && bufferEma[i] > close[i])){
                                 string ArrowUpName = "ArrowUp" + IntegerToString(i);
                                 ObjectCreate(0, ArrowUpName, OBJ_ARROW_UP, 0, time[i], low[i] - 3 * pipsize);
                                 ObjectSetInteger(0, ArrowUpName, OBJPROP_COLOR, arrowBuyColor);
                                 ObjectSetInteger(0, ArrowUpName, OBJPROP_STYLE, STYLE_SOLID);                        
                                 ObjectSetInteger(0, ArrowUpName, OBJPROP_WIDTH, arrowSize);
                                 //ObjectSetInteger(0, ArrowUpName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
                                 if(i == rates_total - 1){
                                    NotificationLevel = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                                    if (!reserveEma)
                                       makeMSG("buy");
                                    else
                                       makeMSG("reserve");
                                 }
                              }
                           }
                        }
                  } else if (close[i] < close[i-1] && bufferRsi[i] >= trixRSIHigh){
                     if (!setEmaAngle ||
                         (!reserveEma && setEmaAngle && MathAbs(emaAngle) > emaAngleThreshold) ||
                         (reserveEma && setEmaAngle && MathAbs(emaAngle) < emaAngleThreshold && MathAbs(emaAngle) > 0)
                        )
                        if(applySR){
                           for (int j=0; j<ArraySize(bufferSR); j++){
                              if (open[i] > bufferSR[j] && close[i] < bufferSR[j]){
                                 if (bufferTema[i] <= 0 && bufferTema[i-1] > 0){
                                    if (!reserveEma || (reserveEma && bufferEma[i] < close[i])){
                                       string ArrowDownName = "ArrowDown" + IntegerToString(i);
                                       ObjectCreate(0, ArrowDownName, OBJ_ARROW_DOWN, 0, time[i], high[i] + 3 * pipsize );
                                       ObjectSetInteger(0, ArrowDownName, OBJPROP_COLOR, arrowSellColor);
                                       ObjectSetInteger(0, ArrowDownName, OBJPROP_STYLE, STYLE_SOLID);
                                       ObjectSetInteger(0, ArrowDownName, OBJPROP_WIDTH, arrowSize);
                                       ObjectSetInteger(0, ArrowDownName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
                                       if(i == rates_total - 1){
                                          NotificationLevel = bufferSR[j];
                                          if (!reserveEma)
                                             makeMSG("sell");
                                          else
                                             makeMSG("reserve");
                                       }
                                    }
                                 }
                              }
                           }
                        }else if (!applySR){
                           if (bufferTema[i] <= 0 && bufferTema[i-1] > 0){
                              if (!reserveEma || (reserveEma && bufferEma[i] < close[i])){
                                 string ArrowDownName = "ArrowDown" + IntegerToString(i);
                                 ObjectCreate(0, ArrowDownName, OBJ_ARROW_DOWN, 0, time[i], high[i] + 3 * pipsize );
                                 ObjectSetInteger(0, ArrowDownName, OBJPROP_COLOR, arrowSellColor);
                                 ObjectSetInteger(0, ArrowDownName, OBJPROP_STYLE, STYLE_SOLID);
                                 ObjectSetInteger(0, ArrowDownName, OBJPROP_WIDTH, arrowSize);
                                 ObjectSetInteger(0, ArrowDownName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
                                 if(i == rates_total - 1){
                                    NotificationLevel = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                                    if (!reserveEma)
                                       makeMSG("sell");
                                    else
                                       makeMSG("reserve");
                                 }
                              }
                           }
                        }
                  }
               }else if (shortTrigger && solider){
                  if (close[i] > close[i-1] && bufferRsi[i] <= soliderRSILow){
                     if (close[i] > bufferEma[i] || (close[i] > bufferEma[i] && open[i] < bufferEma[i])){
                        if (!setEmaAngle ||
                            (!reserveEma && setEmaAngle && MathAbs(emaAngle) > emaAngleThreshold) ||
                            (reserveEma && setEmaAngle && MathAbs(emaAngle) < emaAngleThreshold && MathAbs(emaAngle) > 0)
                           )
                           if(applySR){
                              for (int j=0; j<ArraySize(bufferSR); j++){
                                 if (open[i] < bufferSR[j] && close[i] > bufferSR[j]){
                                    if (rates_total > soliderCount){
                                       bool areLastThreeBarsBearish = true;
                                       for (int j = 1; j <= soliderCount; ++j){
                                          if (close[i-j] >= open[i-j]) {
                                             areLastThreeBarsBearish = false;
                                             break;  // At least one of the last three bars is not bullish
                                          }
                                       }
                                       if (areLastThreeBarsBearish && close[i] > open[i] && MathAbs(open[i]-close[i]) > MathAbs(open[i-1]-close[i-1])){
                                          if (!stochastic || (stochastic && bufferStochMain[i] < MTFLow)){
                                             string ArrowUpName = "ArrowUp" + IntegerToString(i);
                                             ObjectCreate(0, ArrowUpName, OBJ_ARROW_UP, 0, time[i], low[i] - 3 * pipsize);
                                             ObjectSetInteger(0, ArrowUpName, OBJPROP_COLOR, arrowBuyColor);
                                             ObjectSetInteger(0, ArrowUpName, OBJPROP_STYLE, STYLE_SOLID);                        
                                             ObjectSetInteger(0, ArrowUpName, OBJPROP_WIDTH, arrowSize);
                                             if(i == rates_total - 1){
                                                NotificationLevel = bufferSR[j];
                                                if (!reserveEma)
                                                   makeMSG("buy");
                                                else
                                                   makeMSG("reserve");
                                             }
                                          }
                                       }
                                    }                              
                                 }
                              }
                           }else if (!applySR){
                              if (rates_total > soliderCount){
                                 bool areLastThreeBarsBearish = true;
                                 for (int j = 1; j <= soliderCount; ++j){
                                    if (close[i-j] >= open[i-j]) {
                                       areLastThreeBarsBearish = false;
                                       break;  // At least one of the last three bars is not bullish
                                    }
                                 }
                                 if (areLastThreeBarsBearish && close[i] > open[i] && MathAbs(open[i]-close[i]) > MathAbs(open[i-1]-close[i-1])){
                                    if (!stochastic || (stochastic && bufferStochMain[i] < MTFLow)){
                                       string ArrowUpName = "ArrowUp" + IntegerToString(i);
                                       ObjectCreate(0, ArrowUpName, OBJ_ARROW_UP, 0, time[i], low[i] - 3 * pipsize);
                                       ObjectSetInteger(0, ArrowUpName, OBJPROP_COLOR, arrowBuyColor);
                                       ObjectSetInteger(0, ArrowUpName, OBJPROP_STYLE, STYLE_SOLID);                        
                                       ObjectSetInteger(0, ArrowUpName, OBJPROP_WIDTH, arrowSize);
                                       if(i == rates_total - 1){
                                          NotificationLevel = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                                          if (!reserveEma)
                                             makeMSG("buy");
                                          else
                                             makeMSG("reserve");
                                       }
                                    }
                                 }
                              }
                           }
                     }
                  }else if (close[i] < close[i-1] && bufferRsi[i] >= soliderRSIHigh){
                     if (close[i] < bufferEma[i] || (close[i] < bufferEma[i] && open[i] > bufferEma[i])){
                        if (!setEmaAngle ||
                            (!reserveEma && setEmaAngle && MathAbs(emaAngle) > emaAngleThreshold) ||
                            (reserveEma && setEmaAngle && MathAbs(emaAngle) < emaAngleThreshold && MathAbs(emaAngle) > 0)
                           )
                           if(applySR){
                              for (int j=0; j<ArraySize(bufferSR); j++){
                                 if (open[i] > bufferSR[j] && close[i] < bufferSR[j]){
                                    if (rates_total > soliderCount){
                                       bool areLastThreeBarsBullish = true;
                                       for (int j = 1; j <= soliderCount; ++j){
                                          if (close[i-j] <= open[i-j]) {
                                             areLastThreeBarsBullish = false;
                                             break;  // At least one of the last three bars is not bullish
                                          }
                                       }
                                       if (areLastThreeBarsBullish && close[i] < open[i] && MathAbs(open[i]-close[i]) > MathAbs(open[i-1]-close[i-1])){
                                          if (!stochastic || (stochastic && bufferStochMain[i] > MTFHigh)){
                                             string ArrowDownName = "ArrowDown" + IntegerToString(i);
                                             ObjectCreate(0, ArrowDownName, OBJ_ARROW_DOWN, 0, time[i], high[i] + 3 * pipsize);
                                             ObjectSetInteger(0, ArrowDownName, OBJPROP_COLOR, arrowSellColor);
                                             ObjectSetInteger(0, ArrowDownName, OBJPROP_STYLE, STYLE_SOLID);                        
                                             ObjectSetInteger(0, ArrowDownName, OBJPROP_WIDTH, arrowSize);
                                             ObjectSetInteger(0, ArrowDownName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
                                             if(i == rates_total - 1){
                                                NotificationLevel = bufferSR[j];
                                                if (!reserveEma)
                                                   makeMSG("sell");
                                                else
                                                   makeMSG("reserve");
                                             }
                                          }
                                       }
                                    }
                                 }
                              }
                           }else if (!applySR){
                              if (rates_total > soliderCount){
                                 bool areLastThreeBarsBullish = true;
                                 for (int j = 1; j <= soliderCount; ++j){
                                    if (close[i-j] <= open[i-j]) {
                                       areLastThreeBarsBullish = false;
                                       break;  // At least one of the last three bars is not bullish
                                    }
                                 }
                                 if (areLastThreeBarsBullish && close[i] < open[i] && MathAbs(open[i]-close[i]) > MathAbs(open[i-1]-close[i-1])){
                                    if (!stochastic || (stochastic && bufferStochMain[i] > MTFHigh)){
                                       string ArrowDownName = "ArrowDown" + IntegerToString(i);
                                       ObjectCreate(0, ArrowDownName, OBJ_ARROW_DOWN, 0, time[i], high[i] + 3 * pipsize);
                                       ObjectSetInteger(0, ArrowDownName, OBJPROP_COLOR, arrowSellColor);
                                       ObjectSetInteger(0, ArrowDownName, OBJPROP_STYLE, STYLE_SOLID);                        
                                       ObjectSetInteger(0, ArrowDownName, OBJPROP_WIDTH, arrowSize);
                                       ObjectSetInteger(0, ArrowDownName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
                                       if(i == rates_total - 1){
                                          NotificationLevel = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                                          if (!reserveEma)
                                             makeMSG("sell");
                                          else
                                             makeMSG("reserve");
                                       }
                                    }
                                 }
                              }
                           }   
                     }
                  }               
               }else if (!shortTrigger && solider){                  
                  if (close[i] > close[i-1] && bufferRsi[i] <= soliderRSILow){
                     if (!setEmaAngle ||
                         (!reserveEma && setEmaAngle && MathAbs(emaAngle) > emaAngleThreshold) ||
                         (reserveEma && setEmaAngle && MathAbs(emaAngle) < emaAngleThreshold && MathAbs(emaAngle) > 0)
                        )
                        if(applySR){
                           for (int j=0; j<ArraySize(bufferSR); j++){
                              if (open[i] < bufferSR[j] && close[i] > bufferSR[j]){
                              //printf("index----%f", bufferSR[j]);
                                 if (rates_total > soliderCount){
                                    bool areLastThreeBarsBearish = true;
                                    for (int j = 1; j <= soliderCount; ++j){
                                       if (close[i-j] >= open[i-j]) {
                                          areLastThreeBarsBearish = false;
                                          break;  // At least one of the last three bars is not bullish
                                       }
                                    }
                                    if (areLastThreeBarsBearish && close[i] > open[i] && MathAbs(open[i]-close[i]) > MathAbs(open[i-1]-close[i-1])){
                                       if (!reserveEma || (reserveEma && bufferEma[i] > close[i])){
                                          if (!stochastic || (stochastic && bufferStochMain[i] < MTFLow)){
                                             string ArrowUpName = "ArrowUp" + IntegerToString(i);
                                             ObjectCreate(0, ArrowUpName, OBJ_ARROW_UP, 0, time[i], low[i] - 3 * pipsize);
                                             ObjectSetInteger(0, ArrowUpName, OBJPROP_COLOR, arrowBuyColor);
                                             ObjectSetInteger(0, ArrowUpName, OBJPROP_STYLE, STYLE_SOLID);                        
                                             ObjectSetInteger(0, ArrowUpName, OBJPROP_WIDTH, arrowSize);
                                             if(i == rates_total - 1){
                                                NotificationLevel = bufferSR[j];
                                                if (!reserveEma)
                                                   makeMSG("buy");
                                                else
                                                   makeMSG("reserve");
                                             }
                                          }   
                                       }
                                    }
                                 }                              
                              }
                           }
                        }else if (!applySR){
                           if (rates_total > soliderCount){
                              bool areLastThreeBarsBearish = true;
                              for (int j = 1; j <= soliderCount; ++j){
                                 if (close[i-j] >= open[i-j]) {
                                    areLastThreeBarsBearish = false;
                                    break;  // At least one of the last three bars is not bullish
                                 }
                              }
                              if (areLastThreeBarsBearish && close[i] > open[i] && MathAbs(open[i]-close[i]) > MathAbs(open[i-1]-close[i-1])){
                                 if (!reserveEma || (reserveEma && bufferEma[i] > close[i])){
                                    if (!stochastic || (stochastic && bufferStochMain[i] < MTFLow)){
                                       string ArrowUpName = "ArrowUp" + IntegerToString(i);
                                       ObjectCreate(0, ArrowUpName, OBJ_ARROW_UP, 0, time[i], low[i] - 3 * pipsize);
                                       ObjectSetInteger(0, ArrowUpName, OBJPROP_COLOR, arrowBuyColor);
                                       ObjectSetInteger(0, ArrowUpName, OBJPROP_STYLE, STYLE_SOLID);                        
                                       ObjectSetInteger(0, ArrowUpName, OBJPROP_WIDTH, arrowSize);
                                       if(i == rates_total - 1){
                                          NotificationLevel = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                                          if (!reserveEma)
                                          makeMSG("buy");
                                       else
                                          makeMSG("reserve");
                                       }
                                    }   
                                 }
                              }
                           }   
                        }
                  }else if (close[i] < close[i-1] && bufferRsi[i] >= soliderRSIHigh){
                     if (!setEmaAngle ||
                         (!reserveEma && setEmaAngle && MathAbs(emaAngle) > emaAngleThreshold) ||
                         (reserveEma && setEmaAngle && MathAbs(emaAngle) < emaAngleThreshold && MathAbs(emaAngle) > 0)
                        )
                        if(applySR){
                           for (int j=0; j<ArraySize(bufferSR); j++){
                              if (open[i] > bufferSR[j] && close[i] < bufferSR[j]){
                              //printf("index----%f", bufferSR[j]);
                                 if (rates_total > soliderCount){
                                    bool areLastThreeBarsBullish = true;
                                    for (int j = 1; j <= soliderCount; ++j){
                                       if (close[i-j] <= open[i-j]) {
                                          areLastThreeBarsBullish = false;
                                          break;  // At least one of the last three bars is not bullish
                                       }
                                    }
                                    if (areLastThreeBarsBullish && close[i] < open[i] && MathAbs(open[i]-close[i]) > MathAbs(open[i-1]-close[i-1])){
                                       if (!reserveEma || (reserveEma && bufferEma[i] < close[i])){
                                          if (!stochastic || (stochastic && bufferStochMain[i] > MTFHigh)){
                                             string ArrowDownName = "ArrowDown" + IntegerToString(i);
                                             ObjectCreate(0, ArrowDownName, OBJ_ARROW_DOWN, 0, time[i], high[i] + 3 * pipsize);
                                             ObjectSetInteger(0, ArrowDownName, OBJPROP_COLOR, arrowSellColor);
                                             ObjectSetInteger(0, ArrowDownName, OBJPROP_STYLE, STYLE_SOLID);                        
                                             ObjectSetInteger(0, ArrowDownName, OBJPROP_WIDTH, arrowSize);
                                             ObjectSetInteger(0, ArrowDownName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
                                             if(i == rates_total - 1){
                                                NotificationLevel = bufferSR[j];
                                                if (!reserveEma)
                                                   makeMSG("sell");
                                                else
                                                   makeMSG("reserve");
                                             }
                                          }   
                                       }
                                    }
                                 }
                              }                     
                           }
                        }else if (!applySR){
                           if (rates_total > soliderCount){
                              bool areLastThreeBarsBullish = true;
                              for (int j = 1; j <= soliderCount; ++j){
                                 if (close[i-j] <= open[i-j]) {
                                    areLastThreeBarsBullish = false;
                                    break;  // At least one of the last three bars is not bullish
                                 }
                              }
                              if (areLastThreeBarsBullish && close[i] < open[i] && MathAbs(open[i]-close[i]) > MathAbs(open[i-1]-close[i-1])){
                                 if (!reserveEma || (reserveEma && bufferEma[i] < close[i])){
                                    if (!stochastic || (stochastic && bufferStochMain[i] > MTFHigh)){
                                       string ArrowDownName = "ArrowDown" + IntegerToString(i);
                                       ObjectCreate(0, ArrowDownName, OBJ_ARROW_DOWN, 0, time[i], high[i] + 3 * pipsize);
                                       ObjectSetInteger(0, ArrowDownName, OBJPROP_COLOR, clrYellow);
                                       ObjectSetInteger(0, ArrowDownName, OBJPROP_STYLE, STYLE_SOLID);                        
                                       ObjectSetInteger(0, ArrowDownName, OBJPROP_WIDTH, arrowSize);
                                       ObjectSetInteger(0, ArrowDownName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
                                       if(i == rates_total - 1){
                                          NotificationLevel = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                                          if (!reserveEma)
                                             makeMSG("sell");
                                          else
                                             makeMSG("reserve");
                                       }
                                    }
                                 }
                              }
                           }
                        }
                  }
               }
            }
         }
      }
   }
   return rates_total;
}


string EmailSubject = "";
string EmailBody = "";
string AlertText = "";
string AppText = "";
double NotificationLevel = 0;
datetime NotificationTime;

void makeMSG(string type){
    if ((!emailAlert) && (!SMSAlert) && (!soundAlert)) return;
    
    if (!reserveEma){
       EmailSubject = "MT5" + " " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + " Notification";
       EmailBody = AccountInfoString(ACCOUNT_COMPANY) + " - " + AccountInfoString(ACCOUNT_NAME) + " - " + "\r\n" + "MT5" + " Notification for " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + "\r\n";
       if (type == "buy") 
         EmailBody += "The price is approaching a support/resistance level: " + DoubleToString(NotificationLevel, _Digits);
       else if (type == "sell") 
         EmailBody += "The price is at a safe distance from the closest support/resistance level: " + DoubleToString(NotificationLevel, _Digits);
       
       if (type == "buy") 
         AlertText = Symbol() + " Long";
       else if (type == "sell") 
         AlertText = Symbol() + " Short";
       
       AppText = AccountInfoString(ACCOUNT_COMPANY) + " - " + AccountInfoString(ACCOUNT_NAME) + " - " + "MT5" + " - " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + ": ";
       if (type == "buy") 
         AppText += "Price is in Danger Zone of " + DoubleToString(NotificationLevel, _Digits);
       else if (type == "sell") 
         AppText += "Price is in Safe Zone from " + DoubleToString(NotificationLevel, _Digits);
   }else{
       EmailSubject = "MT5" + " " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + " Notification";
       EmailBody = AccountInfoString(ACCOUNT_COMPANY) + " - " + AccountInfoString(ACCOUNT_NAME) + " - " + "\r\n" + "MT5" + " Notification for " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + "\r\n";
       EmailBody += " CLOSE_POSITION";
       
       AlertText = Symbol() + " CLOSE_POSITION";
       
       AppText = AccountInfoString(ACCOUNT_COMPANY) + " - " + AccountInfoString(ACCOUNT_NAME) + " - " + "MT5" + " - " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + ": ";
       AppText += " CLOSE_POSITION";
   }      
   
   isMSGReady = true;
   NotificationTime = iTime(_Symbol, _Period, 0);
}

void Notify(){
    if ((!emailAlert) && (!SMSAlert) && (!soundAlert)) return;
    if (emailAlert){
      if (!SendMail(EmailSubject, EmailBody)) 
         Print("Error sending email " + IntegerToString(GetLastError()));
    }
    if (SMSAlert){
      if (!SendNotification(AppText)) 
         Print("Error sending notification " + IntegerToString(GetLastError()));
    }
    if (soundAlert){
       PlaySound("alert.wav");
       Alert(AlertText);
    }
   EmailSubject = "";
   EmailBody = "";
   AlertText = "";
   AppText = "";
   NotificationLevel = 0;
   isMSGReady = false;   
}

//CopyBuffer Time
datetime _iTime(datetime start_time){
   if(start_time < 0) return(-1);
   datetime Arr[];
   if(CopyTime(NULL,_tf, start_time, 1, Arr)>0)
      return(Arr[0]);
   else
      return(-1);
}

//CopyBuffer Stochastic_handle
double _CopyBuffer(int handle, datetime start_time, int r) {
   double buf[];
   if (CopyBuffer(handle,r,start_time,1,buf) > 0)
      return(buf[0]);
   return(EMPTY_VALUE);
}
