//+------------------------------------------------------------------+
//|                                                        First.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\trade.mqh>
#include <Trade\PositionInfo.mqh>

//--- input parameters
input double volumeSet= 0.01;
input double stopLosePercent =0.05;
input double takeProfitPercent =0.05;

datetime nextDate;
datetime lastBarTime;
double high =0;
double low =0;
double originalBalance = 0;
bool unTrend=true;
double      stopLose=0;
double      takeProfit=0;
CTrade trade;     


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
  
   originalBalance=AccountInfoDouble(ACCOUNT_BALANCE);
   Print(originalBalance);
   setTrendTime();
   setEntry();
   setOffset();
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   Print("End");
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
     if (IsNewDay(TimeCurrent(),nextDate)){
         setTrendTime();
         setEntry();
         unTrend=true;
     }
     double bid =SymbolInfoDouble(Symbol(),SYMBOL_BID);
     double ask =SymbolInfoDouble(Symbol(),SYMBOL_ASK);
     if (unTrend){
        doTrend(bid,ask);
     }
  }
//+------------------------------------------------------------------+
void setTrendTime(){
   datetime currentTime= TimeCurrent();
   datetime dtEvent = StringToTime(TimeToString(currentTime,TIME_DATE)+" 10:00");//need to change when summer/winter
   Print("Next Date",dtEvent);
   if (currentTime<dtEvent+3600){
      nextDate=dtEvent+3600;
      lastBarTime=dtEvent-86400; 
   }
   else{
   // the next date is after London opening one hour 
      nextDate=dtEvent+90000;
      lastBarTime=dtEvent;
   }
}

void setEntry(){
   int bar_index;   
   bar_index=iBarShift(NULL,PERIOD_H1,lastBarTime,false);
   high=iHigh(NULL,PERIOD_H1,bar_index);
   low=iLow(NULL,PERIOD_H1,bar_index);
   Print(high,", ",low,", ",bar_index,", bartime",lastBarTime," next:",nextDate);
   return  ;  
}

void doTrend(double bid,double ask){
      //if have position than close all position
     if (PositionSelect(Symbol())){
     if(!trade.PositionClose(_Symbol))
     {
      Print("PositionClose() method failed. Return code=",trade.ResultRetcode(),
            ". Code description: ",trade.ResultRetcodeDescription());  
            }else{
      Print("PositionClose() method executed successfully. Return code=",trade.ResultRetcode(),
            " (",trade.ResultRetcodeDescription(),")");
     }
      }
      //do trend
      if (ask>high){
      Print("Going Long");
        MarketOrder(ORDER_TYPE_BUY,volumeSet);
         unTrend=false;
      }else if (bid<low){
      Print("Going short");
        MarketOrder(ORDER_TYPE_SELL,volumeSet);
         unTrend=false;
      }
      return ;
      
}

void setOffset(){
   stopLose=originalBalance *stopLosePercent;
   takeProfit=originalBalance*takeProfitPercent;
}

bool IsNewDay(datetime aTimeCur,datetime aTimePre)
{
   return((aTimeCur)>=(aTimePre));
}


bool MarketOrder(ENUM_ORDER_TYPE type,double volume)
  {
   ulong pos_ticket=0;
   MqlTradeRequest request={};
   MqlTradeResult  result={};
   
   //base tick value
   double base = SymbolInfoDouble(Symbol(),SYMBOL_TRADE_TICK_VALUE);
   Print(base);
   
   //take price point 
   double dottp=(takeProfit/(base*volume))*SymbolInfoDouble(Symbol(),SYMBOL_POINT);
   
   //stop loose point 
   double dotsl=(stopLose/(base*volume))*SymbolInfoDouble(Symbol(),SYMBOL_POINT);
   
   int digits=(int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS);
   double price=SymbolInfoDouble(Symbol(),SYMBOL_BID);
   double sl=NormalizeDouble(price+dotsl,digits);
   double tp=NormalizeDouble(price-dottp,digits);
   
   if(type==ORDER_TYPE_BUY){
    price=SymbolInfoDouble(Symbol(),SYMBOL_ASK);
    sl=NormalizeDouble(price-dotsl,digits);
    tp=NormalizeDouble(price+dottp,digits); 
   }
   
   request.action   =TRADE_ACTION_DEAL;                     
   request.position =pos_ticket;                            
   request.symbol   =Symbol();                              
   request.volume   =volume;                               
   request.type     =type;                                  
   request.price    =price;                                                                 
   request.sl=sl;                                
   request.tp=tp;                                                       
   if(!OrderSend(request,result))
     {
      PrintFormat("OrderSend %s %s %.2f at %.5f sl %.5f tp %.5f error %d",
                  request.symbol,EnumToString(type),volume,request.price,sl,tp,GetLastError());
      return (false);
     }
   PrintFormat("retcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order);
   return (true);
  }
