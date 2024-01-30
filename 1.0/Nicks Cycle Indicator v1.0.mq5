//+------------------------------------------------------------------+
//|                                        Nicks Cycle Indicator.mq5 |
//|                                     Copyright 2023, Leo Korhonen |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Leo Korhonen"
#property version   "1.0"

#property indicator_chart_window
#property indicator_buffers 10
#property indicator_plots 8
#property indicator_label1 "Support and Resistance - S3"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_width1  2
#property indicator_label2 "Support and Resistance - S2"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrBlue
#property indicator_width2  2
#property indicator_label3 "Support and Resistance - S1"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrBlue
#property indicator_width3  2
#property indicator_label4 "Support and Resistance - MP"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrLime
#property indicator_width4  2
#property indicator_label5 "Support and Resistance - R1"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrCrimson
#property indicator_width5  2
#property indicator_label6 "Support and Resistance - R2"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrCrimson
#property indicator_width6  2
#property indicator_label7 "Support and Resistance - R3"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrCrimson
#property indicator_width7  2

#property indicator_label8  "EMA"
#property indicator_type8   DRAW_COLOR_LINE
#property indicator_color8  clrDeepSkyBlue, clrOrange
#property indicator_style8  STYLE_SOLID
#property indicator_width8  2

enum ENUM_ACTIVE_INTERVAL
{
    HALF_HOUR = 0,   // 30 minutes
    ONE_HOUR  = 1,   // 1 hour
};

input group "--- [1] Support and Resistance Levels ---";
input double in_d_base_line = 2050.0;  // Base Level
input double in_d_gap_of_levels = 2.5; // Gap between Levels

input group "--- [2] EMA ---";
input int in_i_ema_period = 20;      // EMA period

input group "--- [3] RSI ---";
input int in_i_rsi_period = 14;      // RSI period

input group "--- [4] Time Range ---";
input ENUM_ACTIVE_INTERVAL enai_current = HALF_HOUR;  // Active Interval

color in_clr_snr_line = clrLime;       // Support Line Color
color in_clr_sup_line = clrBlue;       // Support Line Color
color in_clr_res_line = clrCrimson;    // Resistance Line Color
ENUM_LINE_STYLE in_enls_snr = STYLE_SOLID; // Support Line Style
ENUM_LINE_STYLE in_enls_sup = STYLE_SOLID; // Support Line Style
ENUM_LINE_STYLE in_enls_res = STYLE_SOLID; // Resistance Line Style
int in_i_snr_line_width = 3; // Support Line Width
int in_i_sup_line_width = 3; // Support Line Width
int in_i_res_line_width = 3; // Resistance Line Width

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

int i_bars;
int calculated_bars = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
   CleanChart();
   
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
   /*
   ArraySetAsSeries(bufferSnrS3, true);
   ArraySetAsSeries(bufferSnrS2, true);
   ArraySetAsSeries(bufferSnrS1, true);
   ArraySetAsSeries(bufferSnrMP, true);
   ArraySetAsSeries(bufferSnrR1, true);
   ArraySetAsSeries(bufferSnrR2, true);
   ArraySetAsSeries(bufferSnrR3, true);
   */
   _ema.init(in_i_ema_period);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   CleanChart();
}

//+------------------------------------------------------------------+
//| Custom indicator calculation function                              |
//+------------------------------------------------------------------+
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
   if (calculated_bars != prev_calculated)
   {
      calculated_bars = prev_calculated;
   }
   calculated_bars = prev_calculated;
   /*
   ObjectsDeleteAll(0, "S&R");
   
   string line_name = "S&R" + "-Support/Resistance";
   ObjectCreate(0, "S&R" + "-Support/Resistance", OBJ_HLINE, 0, 0, in_d_base_line);
   ObjectSetInteger(0, line_name, OBJPROP_COLOR, in_clr_snr_line);
   ObjectSetInteger(0, line_name, OBJPROP_WIDTH, in_i_snr_line_width);
   ObjectSetInteger(0, line_name, OBJPROP_SELECTABLE, false);
   
   for (int i = 0; i < in_i_num_of_levels; i++)
   {
      line_name = "S&R" + "-Support-" + IntegerToString(i + 1);
      ObjectCreate(0, line_name, OBJ_HLINE, 0, 0, in_d_base_line + in_d_gap_of_levels * (i + 1));
      ObjectSetInteger(0, line_name, OBJPROP_COLOR, in_clr_sup_line);
      ObjectSetInteger(0, line_name, OBJPROP_WIDTH, in_i_sup_line_width);
      ObjectSetInteger(0, line_name, OBJPROP_SELECTABLE, false);
   }
   
   for (int i = 0; i < in_i_num_of_levels; i++)
   {
      line_name = "S&R" + "-Resistance-" + IntegerToString(i + 1);
      ObjectCreate(0, line_name, OBJ_HLINE, 0, 0, in_d_base_line - in_d_gap_of_levels * (i + 1));
      ObjectSetInteger(0, line_name, OBJPROP_COLOR, in_clr_res_line);
      ObjectSetInteger(0, line_name, OBJPROP_WIDTH, in_i_res_line_width);
      ObjectSetInteger(0, line_name, OBJPROP_SELECTABLE, false);
   } */
   
   int i=(int)MathMax(prev_calculated-1,0); for(; i<rates_total && !_StopFlag; i++) {
      bufferSnrS3[i] = NormalizeDouble(in_d_base_line + in_d_gap_of_levels * 6, Digits());
      bufferSnrS2[i] = NormalizeDouble(in_d_base_line + in_d_gap_of_levels * 5, Digits());
      bufferSnrS1[i] = NormalizeDouble(in_d_base_line + in_d_gap_of_levels * 4, Digits());
      bufferSnrMP[i] = NormalizeDouble(in_d_base_line + in_d_gap_of_levels * 3, Digits());
      bufferSnrR1[i] = NormalizeDouble(in_d_base_line + in_d_gap_of_levels * 2, Digits());
      bufferSnrR2[i] = NormalizeDouble(in_d_base_line + in_d_gap_of_levels * 1, Digits());
      bufferSnrR3[i] = NormalizeDouble(in_d_base_line, Digits());
      
      bufferEma[i] = _ema.calculate(close[i],i,rates_total);
      
      bufferRsi[i] = iRsi(close[i],in_i_rsi_period,i,rates_total,3);
      bufferEmaColor[i] = (bufferRsi[i]>=30 && bufferRsi[i]<=70) ? 0 : 1;
      
      MqlDateTime mdt;
      TimeToStruct(time[i], mdt);
      bool in_session = false;
      if (enai_current == HALF_HOUR)
      {
         if (mdt.min == 58 || mdt.min == 59 || mdt.min == 0 || mdt.min == 1 || mdt.min == 2 || mdt.min == 28 || mdt.min == 29 || mdt.min == 30 || mdt.min == 31 || mdt.min == 32)
         {
            in_session = true;
         }
      }
      else
      {
         if (mdt.min == 58 || mdt.min == 59 || mdt.min == 0 || mdt.min == 1 || mdt.min == 2)
         {
            in_session = true;
         }
      }
      if (in_session)
      {
         string line_name = "Time Range" + IntegerToString(i);
         ObjectCreate(0, line_name, OBJ_VLINE, 0, time[i], 0);
         ObjectSetInteger(0, line_name, OBJPROP_COLOR, clrMagenta);
         ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, line_name, OBJPROP_SELECTABLE, false);
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
      workRsi[r][z+_changa] =                                         sum/MathMax(k,1);
     }
   else
     {
      double change=workRsi[r][z+_price]-workRsi[r-1][z+_price];
      workRsi[r][z+_change] = workRsi[r-1][z+_change] + alpha*(        change  - workRsi[r-1][z+_change]);
      workRsi[r][z+_changa] = workRsi[r-1][z+_changa] + alpha*(MathAbs(change) - workRsi[r-1][z+_changa]);
     }
   return(50.0*(workRsi[r][z+_change]/MathMax(workRsi[r][z+_changa],DBL_MIN)+1));
}

class CEma
{
   private:
      double m_period;
      double m_alpha;
      double m_array[];
      int    m_arraySize;
   public:
      CEma(): m_period(1), m_alpha(1), m_arraySize(-1) { return; }
      ~CEma() { return; }
     
      void init(int period)
      {
         m_period = (period>1) ? period : 1;
         m_alpha  = 2.0/(1.0+m_period);
      }
      
      double calculate(double value, int i, int bars)
      {
         if (m_arraySize<bars)
         {
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
