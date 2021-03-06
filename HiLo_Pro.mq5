//+------------------------------------------------------------------+
//|                                                     HiLo_Pro.mq5 |
//|                                                             lfpm |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "lfpm"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>
CTrade trade;

enum ESTRATEGIA_ENTRADA
  {
   APENAS_COMPRA,
   APENAS_VENDA,
   COMPRA_VENDA
  };

input ESTRATEGIA_ENTRADA estrategia = COMPRA_VENDA;

input int period_hilo   = 6;         //Periodos do HiLo
input ENUM_MA_METHOD method_hilo = MODE_SMA; //Método das Medias Moveis (HiLo)
input ENUM_TIMEFRAMES timeframe_hilo = PERIOD_CURRENT; //Tempo grafico para HiLo

input int period_rsi = 9;           //Periodos do RSI
input int rsi_overbuy      = 70;    //Nivel de sobrecompra
input int rsi_oversell     = 30;    //Nivel de sobrevenda

input int num_lotes  = 1;        //Numero de lotes a serem negociados;

MqlRates rates[];
MqlTick  tick;

int magic_number = 001;

double buffer_hilo[];
double buffer_hi[];
double buffer_lo[];
double buffer_color[];
double buffer_trend[];
double buffer_rsi[];

int handle_hilo;
int handle_hi;
int handle_lo;
int handle_rsi;

//--- Chave para definicao se esta dentro do horario de operacao definido
bool time_key = false;
//--- Definicao dos horarios limites para iniciar e encerrar operacoes
input string hora_fecha_op = "17:45";  //Horario de encerramento das ordens
input string hora_comec_op = "09:30";  //Horario de inicio das operacoes
//---Chaves para definir a posicao esta comprado ou vendido
bool comprado = false;
bool vendido = false;
//--- Definicao do dia para check de abertura de um novo dia
string old_date = TimeToString(TimeCurrent(),TIME_DATE);
string current_date;
double old_balance = AccountInfoDouble(ACCOUNT_BALANCE);
double new_balance;
input double daily_profit = 300.00;
bool meta_batida = false;
double meta;
double sl_dia;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---Chamada para inicio dos indicadores
   handle_hilo = iCustom(_Symbol,timeframe_hilo,"HiLo Activator",period_hilo,method_hilo);
   handle_hi   = iMA(_Symbol,timeframe_hilo,period_hilo,0,method_hilo,PRICE_HIGH);
   handle_lo   = iMA(_Symbol,timeframe_hilo,period_hilo,0,method_hilo,PRICE_LOW);
   handle_rsi  = iRSI(_Symbol,PERIOD_CURRENT,period_rsi,PRICE_CLOSE);
   ArraySetAsSeries(rates,true);
   ArraySetAsSeries(buffer_hilo,true);
   ArraySetAsSeries(buffer_hi,true);
   ArraySetAsSeries(buffer_lo,true);
//---Plot em grafico
   ChartIndicatorAdd(0,0,handle_hilo);
   ChartIndicatorAdd(0,0,handle_hi);
   ChartIndicatorAdd(0,0,handle_lo);
   ChartIndicatorAdd(0,1,handle_rsi);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   IndicatorRelease(handle_hilo);
   IndicatorRelease(handle_hi);
   IndicatorRelease(handle_lo);
   IndicatorRelease(handle_rsi);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   CopyRates(_Symbol,_Period,0,3,rates);
   CopyBuffer(handle_hilo,0,0,3,buffer_hilo);
   CopyBuffer(handle_hi,0,0,3,buffer_hi);
   CopyBuffer(handle_lo,0,0,3,buffer_lo);
   CopyBuffer(handle_rsi,0,0,3,buffer_rsi);

//---Balance check at start of day
   current_date = TimeToString(TimeCurrent(),TIME_DATE);
   Print(current_date);
   if(old_date != current_date){
      Print("Novo dia!");
      // Voce tem um novo dia 
      old_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      old_date = TimeToString(TimeCurrent(),TIME_DATE);
      meta_batida = false;
   }
   meta = old_balance + daily_profit;
   sl_dia = old_balance - daily_profit;
   new_balance = AccountInfoDouble(ACCOUNT_EQUITY);
   if(new_balance > meta || new_balance < sl_dia){
      //Print("Meta batida");
      meta_batida = true;
      closePositions();
   }


//---Check do horario para fechar posicao ou liberar operacoes
   if(TimeToString(TimeCurrent(),TIME_MINUTES) > hora_fecha_op || TimeToString(TimeCurrent(),TIME_MINUTES) < hora_comec_op)
     {
      closePositions();
      time_key = false;
     }
   else
     {
      time_key = true;
     }

//+------------------------------------------------------------------+
//| Logica do programa                                               |
//+------------------------------------------------------------------+
   bool newcandle = habemosNewCandle();
   if(newcandle)
     {

      //Condicao de incio de operacao
      if(PositionsTotal() == 0 && OrdersTotal() == 0)
        {
         if(rates[1].close > buffer_hilo[2] && time_key == true && meta_batida == false)
           {
            if(trade.Buy(num_lotes,_Symbol,0,0,0,"Compra"))
              {
               comprado = true;
              }
           }
         if(rates[1].close < buffer_hilo[2] && time_key == true && meta_batida == false)
           {
            if(trade.Sell(num_lotes,_Symbol,0,0,0,"Venda"))
              {
               vendido = true;
              }
           }
        }

      //Condicoes para virada de mao
      if(vendido && rates[1].close > buffer_hilo[2] && time_key == true && meta_batida == false)
        {
         //closePositions();
         if(trade.Buy(2*num_lotes,_Symbol,0,0,0,"Compra"))
           {
            comprado = true;
            vendido = false;
           }
        }

      if(comprado && rates[1].close < buffer_hilo[2] && time_key == true && meta_batida == false)
        {
         //closePositions();

         if(trade.Sell(2*num_lotes,_Symbol,0,0,0,"Venda"))
           {
            vendido = true;
            comprado = false;
           }
        }

     }


  }

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void closePositions()
  {
   for(int i=PositionsTotal()-1; i>=0; i--)      //Go through all positions
     {
      int ticket = PositionGetTicket(i);        //Get the ticket number for the current position
      trade.PositionClose(ticket);               //Close the current position
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool habemosNewCandle()
  {
   static datetime last_time = 0;   //tempo de abertura da ultima vela de uma variavel
   datetime lastbar_time = (datetime) SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE); //Tempo atual
//se for a primeira chamada da funcao
   if(last_time == 0)
     {
      last_time = lastbar_time;  //atribui valor temporal e sai
      return false;
     }
//se o tempo estiver diferente
   if(last_time != lastbar_time)
     {
      last_time = lastbar_time;  //atribui valor temporal e sai
      return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
