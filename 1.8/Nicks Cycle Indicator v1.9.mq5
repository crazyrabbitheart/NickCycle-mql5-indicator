//+------------------------------------------------------------------+
//|                                        Nicks Cycle Indicator.mq5 |
//|                                     Copyright 2023, Leo Korhonen |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Leo Korhonen"
#property version   "1.9"

#property indicator_chart_window
#property indicator_buffers 10
#property indicator_plots 8
#property indicator_label1 "Support and Resistance - S3"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrCoral
#property indicator_width1  2
#property indicator_label2 "Support and Resistance - S2"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrCoral
#property indicator_width2  2
#property indicator_label3 "Support and Resistance - S1"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrCoral
#property indicator_width3  2
#property indicator_label4 "Support and Resistance - MP"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrMediumPurple
#property indicator_width4  2
#property indicator_label5 "Support and Resistance - R1"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrViolet
#property indicator_width5  2
#property indicator_label6 "Support and Resistance - R2"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrViolet
#property indicator_width6  2
#property indicator_label7 "Support and Resistance - R3"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrViolet
#property indicator_width7  2

#property indicator_label8  "EMA"
#property indicator_type8   DRAW_COLOR_LINE
#property indicator_color8  clrDeepSkyBlue, clrOrange
#property indicator_style8  STYLE_SOLID
#property indicator_width8  2

enum ENUM_ACTIVE_INTERVAL
{
   QUARTER = 0,      // 15 minutes
   HALF_HOUR = 1,    // 30 minutes    
   ONE_HOUR  = 2,    // 1 hour
   TWO_HOUR = 3,     // 2 hours
   FOUR_HOUR = 4,    // 4 hours
};


input group "--- [1] Support and Resistance Levels ---";
//input double in_d_base_line = 17080.0;  // Base Level
input bool applySR = true;                //Turn On/Off S&R Rule
input double in_d_gap_of_levels = 10;     // Gap between Levels

input group "--- [2] EMA ---";
input int in_i_ema_period = 20;        // EMA period
input bool shortTrigger = false;       // Turn On/Off MA Trigger
input bool setEmaAngle = true;        // Turn On/Off MA Angle Trigger
input double emaAngleThreshold = 5.0;  // Angle Value For MA Trigger

input group "--- [3] RSI ---";
input int in_i_rsi_period = 14;        // RSI period

input group "--- [4] TRIX ---";
input double trixSense = 5.0;          // TrixSensitivity
input double trixRSIHigh = 55.0;       // RSI High value for Trix
input double trixRSILow = 45.0;        // RSI Low value for Trix

input group "--- [5] Soldier ---";
input bool soldier = false;            // Turn On/Off Soldier
input double soldierRSIHigh = 55.0;    // RSI High value for Soldier
input double soldierRSILow = 45.0;     // RSI Low value for Soldier
input int soldierCount = 2;            // solider Candle Count

input group "--- [6] Time Range ---";
input ENUM_ACTIVE_INTERVAL enai_current = HALF_HOUR;  // Active Interval
input int timeOption = 5;                             //Bar Count

input group "--- [7] Notify ---";
input bool emailAlert = true;          //Turn on/off Email Alert
input bool SMSAlert = true;            //Turn on/off SMS Alert
input bool soundAlert = true;          //Turn on/off Sound Alert

input group "--- [8] Display ---";
input bool autoSRLine = true;          // Show S&R Line
//input bool emaLine = false;             // Show EMA Line
input bool showTimeLine = true;       // Show Time Line
input int setDayforShowTimeLine = 5;   // Set days For History
input int arrowSize = 5;               // Set Arrow Size
input color arrowBuyColor = clrGreen;  // Set Buy Arrow Color
input color arrowSellColor = clrRed;   //Set Sell Arrow Color


double bufferSnrS3[];
double bufferSnrS2[];
double bufferSnrS1[];
double bufferSnrMP[];
double bufferSnrR1[];
double bufferSnrR2[];
double bufferSnrR3[];

double bufferEma[];
double bufferEmaColor[];
double bufferRsi[];
double bufferTema[];

double in_d_base_line = 17080.0;
double gapSize;

int MA_handle;
bool isMSGReady = false;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
   //CleanChart();   
   SetIndexBuffer(0, bufferSnrS3, INDICATOR_DATA);
   SetIndexBuffer(1, bufferSnrS2, INDICATOR_DATA);
   SetIndexBuffer(2, bufferSnrS1, INDICATOR_DATA);
   SetIndexBuffer(3, bufferSnrMP, INDICATOR_DATA);
   SetIndexBuffer(4, bufferSnrR1, INDICATOR_DATA);
   SetIndexBuffer(5, bufferSnrR2, INDICATOR_DATA);
   SetIndexBuffer(6, bufferSnrR3, INDICATOR_DATA);   
   SetIndexBuffer(7, bufferEma, INDICATOR_DATA);   
   SetIndexBuffer(8, bufferEmaColor, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(9, bufferRsi, INDICATOR_DATA);
   
   in_d_base_line = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      
   if (in_d_base_line)
      gapSize = in_d_gap_of_levels * 10 * SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   
   if (!autoSRLine || !applySR){
      in_d_base_line = 0;
      gapSize = 0;
   }
            
   _ema.init(in_i_ema_period);   
   MA_handle=iCustom(NULL, 0, "Examples\\TRIX", trixSense, 0, MODE_EMA, PRICE_CLOSE); 
   Print("MA_handle = ",MA_handle,"  error = ",GetLastError()); 
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   CleanChart();
   ObjectsDeleteAll(0,-1,OBJ_ARROW_UP);
   ObjectsDeleteAll(0,-1,OBJ_ARROW_DOWN);
   ObjectsDeleteAll(0,-1,OBJ_VLINE);
}

//+------------------------------------------------------------------+
//| Custom indicator calculation function                            |
//+------------------------------------------------------------------+

datetime lastTickTime = 0;
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
                
   ObjectSetInteger(0, "Support and Resistance - MP", OBJPROP_COLOR, clrRed);
                
   datetime currentChartTime = iTime(_Symbol, _Period, 0);
   //datetime targetDayTime = D'2023.12.30';
   //if (currentChartTime > targetDayTime)
   //   return rates_total;
   
   MqlDateTime cmdt;
   TimeToStruct(currentChartTime, cmdt);
   
   int copy=CopyBuffer(MA_handle,0,0,rates_total,bufferTema);   
//   for(int j=prev_calculated+1; j<rates_total; j++){
//      printf("tema %f", bufferTema[j]);
//   }

   MqlDateTime nmdt;
   TimeToStruct(NotificationTime, nmdt);

   if (cmdt.min != nmdt.min)
      if (isMSGReady){
         Notify();
      }
   //   lastTickTime = time[0];
      //isMSGReady = false;
  // }
   
   int i=(int)MathMax(prev_calculated-1,1); 
   for(; i < rates_total && !_StopFlag; i++) {   
      MqlDateTime mdt;
      TimeToStruct(time[i], mdt);         
      int daysDifference = MathAbs(cmdt.day - mdt.day);
      
      if (daysDifference <= setDayforShowTimeLine){
         double bufferSR[8];
         //if (autoSRLine) {
            bufferSnrS3[i] = NormalizeDouble(in_d_base_line + gapSize * 3, Digits());
            bufferSnrS2[i] = NormalizeDouble(in_d_base_line + gapSize * 2, Digits());
            bufferSnrS1[i] = NormalizeDouble(in_d_base_line + gapSize * 1, Digits());
            bufferSnrMP[i] = NormalizeDouble(in_d_base_line, Digits());
            bufferSnrR1[i] = NormalizeDouble(in_d_base_line + gapSize * -1, Digits());
            bufferSnrR2[i] = NormalizeDouble(in_d_base_line + gapSize * -2, Digits());
            bufferSnrR3[i] = NormalizeDouble(in_d_base_line + gapSize * -3, Digits());
            
            bufferSR[0] = bufferSnrS3[i];
            bufferSR[1] = bufferSnrS2[i];
            bufferSR[2] = bufferSnrS1[i];
            bufferSR[3] = bufferSnrMP[i];
            bufferSR[4] = bufferSnrR1[i];
            bufferSR[5] = bufferSnrR2[i];
            bufferSR[6] = bufferSnrR3[i];
            //printf("bufferSR: %f", bufferSR[0]);
         //}
         
         string objectName = "";
         for (int j = 0; j < ObjectsTotal(0, 0, OBJ_HLINE); j++){
            objectName = ObjectName(0, 0, -1, OBJ_HLINE);         
            if (StringFind(objectName, "Horizontal", 0) > 0){
               //printf("price %f", ObjectGetDouble(0, objectName, OBJPROP_PRICE));
               bufferSR[7] = ObjectGetDouble(0, objectName, OBJPROP_PRICE);
            }
         }
         
         bufferEma[i] = _ema.calculate(close[i],i,rates_total);         
         bufferRsi[i] = iRsi(close[i],in_i_rsi_period,i,rates_total,3);
         bufferEmaColor[i] = 1;
         bufferEmaColor[i] = (bufferRsi[i]>=30 && bufferRsi[i]<=70) ? 0 : 1;
                  
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
            
            double emaAngle = MathArctan((bufferEma[i] - bufferEma[1]) / (1.0 * PeriodSeconds()));
            
            if (i > 0){
               if (shortTrigger && !soldier){
                  if (close[i] > close[i-1] && bufferRsi[i] <= trixRSILow){
                     if (close[i] > bufferEma[i] || (close[i] > bufferEma[i] && open[i] < bufferEma[i])){
                        if ((setEmaAngle && MathAbs(emaAngle) > emaAngleThreshold) || !setEmaAngle)
                           if (applySR){
                              for (int j=0; j<ArraySize(bufferSR); j++){
                                 if (open[i] < bufferSR[j] && close[i] > bufferSR[j]){
                                    if(bufferTema[i] >= 0 && bufferTema[i-1] < 0){
                                       string ArrowUpName = "ArrowUp" + IntegerToString(i);
                                       ObjectCreate(0, ArrowUpName, OBJ_ARROW_UP, 0, time[i], low[i] - 3 * pipsize);
                                       ObjectSetInteger(0, ArrowUpName, OBJPROP_COLOR, arrowBuyColor);
                                       ObjectSetInteger(0, ArrowUpName, OBJPROP_STYLE, STYLE_SOLID);                        
                                       ObjectSetInteger(0, ArrowUpName, OBJPROP_WIDTH, arrowSize);
                                       //if(i == rates_total - 1){
                                          NotificationLevel = bufferSR[j];
                                          makeMSG("buy");
                                          isMSGReady = true;
                                       //}
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
                                 //if(i == rates_total - 1){
                                    NotificationLevel = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                                    makeMSG("buy");
                                    isMSGReady = true;
                                 //}
                                 //Print("Buy");
                              }
                           }
                     }
                  } else if (close[i] < close[i-1] && bufferRsi[i] >= trixRSIHigh){
                     if (close[i] < bufferEma[i] || (close[i] < bufferEma[i] && open[i] > bufferEma[i])){
                        if ((setEmaAngle && MathAbs(emaAngle) > emaAngleThreshold) || !setEmaAngle)
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
                                       //if(i == rates_total - 1){
                                          NotificationLevel = bufferSR[j];
                                          makeMSG("sell");
                                          isMSGReady = true;
                                       //}
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
                                 //if(i == rates_total - 1){
                                    NotificationLevel = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                                    makeMSG("sell");
                                    isMSGReady = true;
                                 //}
                                 //Print("Sell");
                              }
                           }   
                     }
                  }
               }else if (!shortTrigger && !soldier){
                  if (close[i] > close[i-1] && bufferRsi[i] <=trixRSILow){
                     if(applySR){
                        for (int j=0; j<ArraySize(bufferSR); j++){
                           if (open[i] < bufferSR[j] && close[i] > bufferSR[j]){
                              if(bufferTema[i] >= 0 && bufferTema[i-1] < 0){
                                 string ArrowUpName = "ArrowUp" + IntegerToString(i);
                                 ObjectCreate(0, ArrowUpName, OBJ_ARROW_UP, 0, time[i], low[i] - 3 * pipsize);
                                 ObjectSetInteger(0, ArrowUpName, OBJPROP_COLOR, arrowBuyColor);
                                 ObjectSetInteger(0, ArrowUpName, OBJPROP_STYLE, STYLE_SOLID);                        
                                 ObjectSetInteger(0, ArrowUpName, OBJPROP_WIDTH, arrowSize);
                                 //ObjectSetInteger(0, ArrowUpName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
                                 //if(i == rates_total - 1){
                                    NotificationLevel = bufferSR[j];
                                    makeMSG("buy");
                                    isMSGReady = true;
                                 //}
                                 //Print("Buy");
                              }
                           }
                        }
                     }else if (!applySR){
                        if(bufferTema[i] >= 0 && bufferTema[i-1] < 0){
                           string ArrowUpName = "ArrowUp" + IntegerToString(i);
                           ObjectCreate(0, ArrowUpName, OBJ_ARROW_UP, 0, time[i], low[i] - 3 * pipsize);
                           ObjectSetInteger(0, ArrowUpName, OBJPROP_COLOR, arrowBuyColor);
                           ObjectSetInteger(0, ArrowUpName, OBJPROP_STYLE, STYLE_SOLID);                        
                           ObjectSetInteger(0, ArrowUpName, OBJPROP_WIDTH, arrowSize);
                           //ObjectSetInteger(0, ArrowUpName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
                           //if(i == rates_total - 1){
                              NotificationLevel = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                              makeMSG("buy");
                              isMSGReady = true;
                           //}
                           //Print("Buy");
                        }
                     }   
                  } else if (close[i] < close[i-1] && bufferRsi[i] >= trixRSIHigh){
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
                                 //if(i == rates_total - 1){
                                    NotificationLevel = bufferSR[j];
                                    makeMSG("sell");
                                    isMSGReady = true;
                                 //}
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
                           //if(i == rates_total - 1){
                              NotificationLevel = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                              makeMSG("sell");
                              isMSGReady = true;
                           //}
                           //Print("Sell");
                        }
                     }
                  }
               }else if (shortTrigger && soldier){
                  if (close[i] > close[i-1] && bufferRsi[i] <= soldierRSILow){
                     if (close[i] > bufferEma[i] || (close[i] > bufferEma[i] && open[i] < bufferEma[i])){
                        if ((setEmaAngle && MathAbs(emaAngle) > emaAngleThreshold) || !setEmaAngle)
                           if(applySR){
                              for (int j=0; j<ArraySize(bufferSR); j++){
                                 if (open[i] < bufferSR[j] && close[i] > bufferSR[j]){
                                    if (rates_total > soldierCount){
                                       bool areLastThreeBarsBearish = true;
                                       for (int j = 1; j <= soldierCount; ++j){
                                          if (close[i-j] >= open[i-j]) {
                                             areLastThreeBarsBearish = false;
                                             break;  // At least one of the last three bars is not bullish
                                          }
                                       }
                                       if (areLastThreeBarsBearish && close[i] > open[i] && MathAbs(open[i]-close[i]) > MathAbs(open[i-1]-close[i-1])){
                                          string ArrowUpName = "ArrowUp" + IntegerToString(i);
                                          ObjectCreate(0, ArrowUpName, OBJ_ARROW_UP, 0, time[i], low[i] - 3 * pipsize);
                                          ObjectSetInteger(0, ArrowUpName, OBJPROP_COLOR, arrowBuyColor);
                                          ObjectSetInteger(0, ArrowUpName, OBJPROP_STYLE, STYLE_SOLID);                        
                                          ObjectSetInteger(0, ArrowUpName, OBJPROP_WIDTH, arrowSize);
                                          //if(i == rates_total - 1){
                                             NotificationLevel = bufferSR[j];
                                             makeMSG("buy");
                                             isMSGReady = true;
                                          //}
                                          //Print("Buy");
                                       }
                                    }                              
                                 }
                              }
                           }else if (!applySR){
                              if (rates_total > soldierCount){
                                 bool areLastThreeBarsBearish = true;
                                 for (int j = 1; j <= soldierCount; ++j){
                                    if (close[i-j] >= open[i-j]) {
                                       areLastThreeBarsBearish = false;
                                       break;  // At least one of the last three bars is not bullish
                                    }
                                 }
                                 if (areLastThreeBarsBearish && close[i] > open[i] && MathAbs(open[i]-close[i]) > MathAbs(open[i-1]-close[i-1])){
                                    string ArrowUpName = "ArrowUp" + IntegerToString(i);
                                    ObjectCreate(0, ArrowUpName, OBJ_ARROW_UP, 0, time[i], low[i] - 3 * pipsize);
                                    ObjectSetInteger(0, ArrowUpName, OBJPROP_COLOR, arrowBuyColor);
                                    ObjectSetInteger(0, ArrowUpName, OBJPROP_STYLE, STYLE_SOLID);                        
                                    ObjectSetInteger(0, ArrowUpName, OBJPROP_WIDTH, arrowSize);
                                    //if(i == rates_total - 1){
                                       NotificationLevel = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                                       makeMSG("buy");
                                       isMSGReady = true;
                                    //}
                                    //Print("Buy");
                                 }
                              }
                           }
                     }
                  }else if (close[i] < close[i-1] && bufferRsi[i] >= soldierRSIHigh){
                     if (close[i] < bufferEma[i] || (close[i] < bufferEma[i] && open[i] > bufferEma[i])){
                        if ((setEmaAngle && MathAbs(emaAngle) > emaAngleThreshold) || !setEmaAngle)
                           if(applySR){
                              for (int j=0; j<ArraySize(bufferSR); j++){
                                 if (open[i] > bufferSR[j] && close[i] < bufferSR[j]){
                                    if (rates_total > soldierCount){
                                       bool areLastThreeBarsBullish = true;
                                       for (int j = 1; j <= soldierCount; ++j){
                                          if (close[i-j] <= open[i-j]) {
                                             areLastThreeBarsBullish = false;
                                             break;  // At least one of the last three bars is not bullish
                                          }
                                       }
                                       if (areLastThreeBarsBullish && close[i] < open[i] && MathAbs(open[i]-close[i]) > MathAbs(open[i-1]-close[i-1])){
                                          string ArrowDownName = "ArrowDown" + IntegerToString(i);
                                          ObjectCreate(0, ArrowDownName, OBJ_ARROW_DOWN, 0, time[i], high[i] + 3 * pipsize);
                                          ObjectSetInteger(0, ArrowDownName, OBJPROP_COLOR, arrowSellColor);
                                          ObjectSetInteger(0, ArrowDownName, OBJPROP_STYLE, STYLE_SOLID);                        
                                          ObjectSetInteger(0, ArrowDownName, OBJPROP_WIDTH, arrowSize);
                                          ObjectSetInteger(0, ArrowDownName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
                                          //if(i == rates_total - 1){
                                             NotificationLevel = bufferSR[j];
                                             makeMSG("sell");
                                             isMSGReady = true;
                                          //}
                                          //Print("sell");
                                       }
                                    }
                                 }
                              }
                           }else if (!applySR){
                              if (rates_total > soldierCount){
                                 bool areLastThreeBarsBullish = true;
                                 for (int j = 1; j <= soldierCount; ++j){
                                    if (close[i-j] <= open[i-j]) {
                                       areLastThreeBarsBullish = false;
                                       break;  // At least one of the last three bars is not bullish
                                    }
                                 }
                                 if (areLastThreeBarsBullish && close[i] < open[i] && MathAbs(open[i]-close[i]) > MathAbs(open[i-1]-close[i-1])){
                                    string ArrowDownName = "ArrowDown" + IntegerToString(i);
                                    ObjectCreate(0, ArrowDownName, OBJ_ARROW_DOWN, 0, time[i], high[i] + 3 * pipsize);
                                    ObjectSetInteger(0, ArrowDownName, OBJPROP_COLOR, arrowSellColor);
                                    ObjectSetInteger(0, ArrowDownName, OBJPROP_STYLE, STYLE_SOLID);                        
                                    ObjectSetInteger(0, ArrowDownName, OBJPROP_WIDTH, arrowSize);
                                    ObjectSetInteger(0, ArrowDownName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
                                    //if(i == rates_total - 1){
                                       NotificationLevel = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                                       makeMSG("sell");
                                       isMSGReady = true;
                                    //}
                                    //Print("Sell");
                                 }
                              }
                           }   
                     }
                  }               
               }else if (!shortTrigger && soldier){                  
                  if (close[i] > close[i-1] && bufferRsi[i] <= soldierRSILow){
                     if(applySR){
                        for (int j=0; j<ArraySize(bufferSR); j++){
                           if (open[i] < bufferSR[j] && close[i] > bufferSR[j]){
                           printf("index----%f", bufferSR[j]);
                              if (rates_total > soldierCount){
                                 bool areLastThreeBarsBearish = true;
                                 for (int j = 1; j <= soldierCount; ++j){
                                    if (close[i-j] >= open[i-j]) {
                                       areLastThreeBarsBearish = false;
                                       break;  // At least one of the last three bars is not bullish
                                    }
                                 }
                                 if (areLastThreeBarsBearish && close[i] > open[i] && MathAbs(open[i]-close[i]) > MathAbs(open[i-1]-close[i-1])){
                                    string ArrowUpName = "ArrowUp" + IntegerToString(i);
                                    ObjectCreate(0, ArrowUpName, OBJ_ARROW_UP, 0, time[i], low[i] - 3 * pipsize);
                                    ObjectSetInteger(0, ArrowUpName, OBJPROP_COLOR, arrowBuyColor);
                                    ObjectSetInteger(0, ArrowUpName, OBJPROP_STYLE, STYLE_SOLID);                        
                                    ObjectSetInteger(0, ArrowUpName, OBJPROP_WIDTH, arrowSize);
                                    //if(i == rates_total - 1){
                                       NotificationLevel = bufferSR[j];
                                       makeMSG("buy");
                                       isMSGReady = true;
                                    //}
                                    //Print("Buy");
                                 }
                              }                              
                           }
                        }
                     }else if (!applySR){
                        if (rates_total > soldierCount){
                           bool areLastThreeBarsBearish = true;
                           for (int j = 1; j <= soldierCount; ++j){
                              if (close[i-j] >= open[i-j]) {
                                 areLastThreeBarsBearish = false;
                                 break;  // At least one of the last three bars is not bullish
                              }
                           }
                           if (areLastThreeBarsBearish && close[i] > open[i] && MathAbs(open[i]-close[i]) > MathAbs(open[i-1]-close[i-1])){
                              string ArrowUpName = "ArrowUp" + IntegerToString(i);
                              ObjectCreate(0, ArrowUpName, OBJ_ARROW_UP, 0, time[i], low[i] - 3 * pipsize);
                              ObjectSetInteger(0, ArrowUpName, OBJPROP_COLOR, arrowBuyColor);
                              ObjectSetInteger(0, ArrowUpName, OBJPROP_STYLE, STYLE_SOLID);                        
                              ObjectSetInteger(0, ArrowUpName, OBJPROP_WIDTH, arrowSize);
                              //if(i == rates_total - 1){
                                 NotificationLevel = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                                 makeMSG("buy");
                                 isMSGReady = true;
                              //}
                              //Print("Buy");
                           }
                        }   
                     }                     
                  }else if (close[i] < close[i-1] && bufferRsi[i] >= soldierRSIHigh){
                     if(applySR){
                        for (int j=0; j<ArraySize(bufferSR); j++){
                           if (open[i] > bufferSR[j] && close[i] < bufferSR[j]){
                           printf("index----%f", bufferSR[j]);
                              if (rates_total > soldierCount){
                                 bool areLastThreeBarsBullish = true;
                                 for (int j = 1; j <= soldierCount; ++j){
                                    if (close[i-j] <= open[i-j]) {
                                       areLastThreeBarsBullish = false;
                                       break;  // At least one of the last three bars is not bullish
                                    }
                                 }
                                 if (areLastThreeBarsBullish && close[i] < open[i] && MathAbs(open[i]-close[i]) > MathAbs(open[i-1]-close[i-1])){
                                    string ArrowDownName = "ArrowDown" + IntegerToString(i);
                                    ObjectCreate(0, ArrowDownName, OBJ_ARROW_DOWN, 0, time[i], high[i] + 3 * pipsize);
                                    ObjectSetInteger(0, ArrowDownName, OBJPROP_COLOR, arrowSellColor);
                                    ObjectSetInteger(0, ArrowDownName, OBJPROP_STYLE, STYLE_SOLID);                        
                                    ObjectSetInteger(0, ArrowDownName, OBJPROP_WIDTH, arrowSize);
                                    ObjectSetInteger(0, ArrowDownName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
                                    //if(i == rates_total - 1){
                                       NotificationLevel = bufferSR[j];
                                       makeMSG("Sell");
                                       isMSGReady = true;
                                    //}
                                    //Print("Sell");
                                 }
                              }
                           }                     
                        }
                     }else if (!applySR){
                        if (rates_total > soldierCount){
                           bool areLastThreeBarsBullish = true;
                           for (int j = 1; j <= soldierCount; ++j){
                              if (close[i-j] <= open[i-j]) {
                                 areLastThreeBarsBullish = false;
                                 break;  // At least one of the last three bars is not bullish
                              }
                           }
                           if (areLastThreeBarsBullish && close[i] < open[i] && MathAbs(open[i]-close[i]) > MathAbs(open[i-1]-close[i-1])){
                              string ArrowDownName = "ArrowDown" + IntegerToString(i);
                              ObjectCreate(0, ArrowDownName, OBJ_ARROW_DOWN, 0, time[i], high[i] + 3 * pipsize);
                              ObjectSetInteger(0, ArrowDownName, OBJPROP_COLOR, arrowSellColor);
                              ObjectSetInteger(0, ArrowDownName, OBJPROP_STYLE, STYLE_SOLID);                        
                              ObjectSetInteger(0, ArrowDownName, OBJPROP_WIDTH, arrowSize);
                              ObjectSetInteger(0, ArrowDownName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
                              //if(i == rates_total - 1){
                                 NotificationLevel = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                                 makeMSG("Sell");
                                 isMSGReady = true;
                              //}
                              //Print("Sell");
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

//------------------------------------------------------------------
// Custom functions
//------------------------------------------------------------------
#define rsiInstances 4
#define rsiInstancesSize 3
double workRsi[][rsiInstances*rsiInstancesSize];
#define _price  0
#define _change 1
#define _changa 2

double iRsi(double price,double period,int r,int bars,int instanceNo=0)
  {
   if(ArrayRange(workRsi,0)!=bars) ArrayResize(workRsi,bars);
   int z=instanceNo*rsiInstancesSize;   
   workRsi[r][z+_price]=price;
   double alpha=1.0/MathMax(period,1);
   if(r<period)
     {
      int k; double sum=0; for(k=0; k<period && (r-k-1)>=0; k++) sum+=MathAbs(workRsi[r-k][z+_price]-workRsi[r-k-1][z+_price]);
      workRsi[r][z+_change] = (workRsi[r][z+_price]-workRsi[0][z+_price])/MathMax(k,1);
      workRsi[r][z+_changa] = sum/MathMax(k,1);
     }
   else
     {
      double change=workRsi[r][z+_price]-workRsi[r-1][z+_price];
      workRsi[r][z+_change] = workRsi[r-1][z+_change] + alpha*(        change  - workRsi[r-1][z+_change]);
      workRsi[r][z+_changa] = workRsi[r-1][z+_changa] + alpha*(MathAbs(change) - workRsi[r-1][z+_changa]);
     }
   return(50.0*(workRsi[r][z+_change]/MathMax(workRsi[r][z+_changa],DBL_MIN)+1));
}

class CEma{
   private:
      double m_period;
      double m_alpha;
      double m_array[];
      int    m_arraySize;
   public:
      CEma(): m_period(1), m_alpha(1), m_arraySize(-1) { 
         return; 
      }
      ~CEma() { 
         return; 
      }
     
      void init(int period){
         m_period = (period>1) ? period : 1;
         m_alpha  = 2.0/(1.0+m_period);
      }
      
      double calculate(double value, int i, int bars){
         if (m_arraySize<bars){
            m_arraySize=ArrayResize(m_array,bars+500); if (m_arraySize<bars) return(0);
         }
         if (i>0)
            m_array[i] = m_array[i-1]+m_alpha*(value-m_array[i-1]); 
         else
            m_array[i] = value;
         return (m_array[i]);
      }   
};
CEma _ema;

void CleanChart()
{
   ObjectsDeleteAll(0, "Time Range");
}

string EmailSubject = "";
string EmailBody = "";
string AlertText = "";
string AppText = "";
double NotificationLevel = 0;
datetime NotificationTime;

void makeMSG(string type){
    if ((!emailAlert) && (!SMSAlert) && (!soundAlert)) return;
    EmailSubject = "MT5" + " " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + " Notification";
    EmailBody = AccountInfoString(ACCOUNT_COMPANY) + " - " + AccountInfoString(ACCOUNT_NAME) + " - " + IntegerToString( AccountInfoString(ACCOUNT_NAME)) + "\r\n" + "MT5" + " Notification for " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + "\r\n";
    if (type == "buy") 
      EmailBody += "The price is approaching a support/resistance level: " + DoubleToString(NotificationLevel, _Digits);
    else if (type == "sell") 
      EmailBody += "The price is at a safe distance from the closest support/resistance level: " + DoubleToString(NotificationLevel, _Digits);
    
    if (type == "buy") 
      AlertText += Symbol() + " Long";
    else if (type == "sell") 
      AlertText += Symbol() + " Short";
    
    AppText = AccountInfoString(ACCOUNT_COMPANY) + " - " + AccountInfoString(ACCOUNT_NAME) + " - " + IntegerToString( AccountInfoString(ACCOUNT_NAME)) + " - " + "MT5" + " - " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + ": ";
    if (type == "buy") 
      AppText += "Price is in Danger Zone of " + DoubleToString(NotificationLevel, _Digits);
    else if (type == "sell") 
      AppText += "Price is in Safe Zone from " + DoubleToString(NotificationLevel, _Digits);    
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
   NotificationTime = iTime(_Symbol, _Period, 0);
}