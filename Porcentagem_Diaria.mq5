//+------------------------------------------------------------------+
//|                                                       GridEA.mq5 |
//|                               Copyright 2019, Charles F. Santana |
//|                                                                  |
//|                                    rafaelfenerick.mql5@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Charles F. Santana"
#property link      ""
#property version   "1.50"
#property strict

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Controls/Dialog.mqh>
#include <Controls/Label.mqh>
#include <Controls/Panel.mqh>


//+------------------------------------------------------------------+
//| Enumeradores                                                     |
//+------------------------------------------------------------------+

//--- cálculos
enum CALCULATIONS
  {
   POINTS = 0,    // Pontos
   PIPS = 1       // Pips
  };

//--- tipo de operação
enum TRADESIDE
  {
   BUY = 0, // Compra
   SELL = 1 // Venda
  };
  

//--- booleano
enum BOOL
  {
   NAO = 0,    // Não
   SIM = 1     // Sim
  };
  
//--- Media Movel


//--- limites financeiros
enum ENUM_LIMIT_TYPES
  {
   LIMIT_MAX_LOSS_IN     =0,
   LIMIT_MAX_LOSS_OUT    =1,
   LIMIT_MAX_GAIN_IN     =2,
   LIMIT_MAX_GAIN_OUT    =3,
   LIMIT_MAX_OPERATIONS  =4,
   LIMIT_NONE            =5
  };

//+------------------------------------------------------------------+
//| Classes                                                          |
//+------------------------------------------------------------------+

//--- reentradas
class CReentrada
  {
protected:

   double            m_distance[];
   double            m_contract[];
   double            m_takeprofit[];
   double            m_done[];

   double            m_priceopen;
   bool              m_drawn;
   double            m_mult;
   

   CTrade            m_trade;
   CSymbolInfo       m_symbol;

public:
                     CReentrada(void);
                    ~CReentrada(void);
   void              AdicionarReentrada(double distance, double contract, double takeprofit);
   void              Magic_(ulong value) {m_trade.SetExpertMagicNumber(value);}
   void              Mult(double value)  {m_mult=value;                       }
   void              ChecarReentrada(void);
   void              ChecarPosicao(void);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CFinance
  {
protected:
   //--- input parameters
   double            m_max_loss_in;
   double            m_max_loss_out;
   double            m_max_gain_in;
   double            m_max_gain_out;
   int               m_max_operations;
   int               m_max_gain_operations;
   int               m_max_loss_operations;
   ulong             m_magic;
   double            m_initialBalance;

public:
                     CFinance(void);
                    ~CFinance(void);
   //--- methods of initialization of protected data
   void              InitialBalance(double value)    { m_initialBalance=value;         }
   void              MaxLossIn(double value)         { m_max_loss_in=value;            }
   void              MaxLossOut(double value)        { m_max_loss_out=value;           }
   void              MaxGainIn(double value)         { m_max_gain_in=value;            }
   void              MaxGainOut(double value)        { m_max_gain_out=value;           }
   void              MaxOperations(int value)        { m_max_operations=value;         }
   void              MaxGainOperations(int value)    { m_max_gain_operations=value;    }
   void              MaxLossOperations(int value)    { m_max_loss_operations=value;    }
   void              Magic_(ulong value)             { m_magic=value;                  }
   //---
   virtual bool      CheckLimit(ENUM_LIMIT_TYPES &type);

protected:
   //---
   void              GetCurrentProfit(double &profit, int &total, int &gain_total, int &loss_total);
   double            GetLastProfit(void);
  };

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input group                   "Configurações operacionais"
input ulong                   Magic                         = 71894;      // Número mágico
/*input TRADESIDE               FirstSide                     = BUY;        // Entrada inicial*/
input double                  ManterTendencia               = 100;          // Manter tendência (0 -> desativar)
input int                     Vol                           = 0;      // Maior q 1 Aumenta Volume e 0 não varia volume
input int                     Delay                         = 10;          // Delay para entrada (segundos)
input double                  InitialVolume                 = 1;          // Volume inicial
input double                  Multiplicador                 = 4;          // Multiplicador
input double                  Quant                         = 0;          // Quantidade
input CALCULATIONS            Calculos                      = POINTS;     // Cálculo
input double                  Step                          = 150;          // Passo
input double                  TP                            = 600;          // Take Profit (zero -> desativar)
input double                  SL                            = 300;          // Stop Loss
input group                   "Trailing Stop"
input double                  TSDistance                    = 50;         // Distância de disparo (-1 -> Desativar)
input double                  TSGain                        = 30;          // Distância de ajuste (relação a entrada)
input group                   "Metas Financeiras"
input double                  Finance_MaxLossIn             = 300;          // Perda para entradas

input double                  porcentagem_diaria            = 0.02;        // Porcentagem de ganho diario em cima do saldo total

double saldo = AccountInfoDouble(ACCOUNT_BALANCE);
double                  Finance_MaxLossOut            = porcentagem_diaria*saldo*2;          // Perda para fechamento
double                        saldo_lucro                   = saldo*porcentagem_diaria;
double                        Finance_MaxGainIn             = saldo_lucro;          // Ganho para entradas
double                  Finance_MaxGainOut            = porcentagem_diaria*saldo*2;          // Ganho para fechamento
input int                     Finance_MaxOperations         = 0;          // Quantidade de operações
input int                     Finance_MaxOperationsGain     = 0;          // Quantidade de operações com lucro
input int                     Finance_MaxOperationsLoss     = 0;          // Quantidade de operações com prejuízo
input int                     FechaOperacao                 = 0;          // Pontos para a Média Movel Fechar a Operação
input group                   "Horários"
input string                  Time_Start                    = "09:16";    // Horário de início das entradas
input string                  Time_End                      = "16:45";    // Horário de término das entradas
input string                  Time_Close                    = "17:45";    // Horário de fechamento
//+------------------------------------------------------------------+
//| Variáveis Globais                                                |
//+------------------------------------------------------------------+
CSymbolInfo    *ea_symbol;
CTrade         *ea_trade;
CReentrada     *ea_reentrada;
CFinance       *ea_finance;

string          ea_comment          = "GridEA";
TRADESIDE       ea_tradeside;
datetime        ea_entrytime        = 0;
bool            ea_tradedone        = false;
double          ea_ts_distance      = -1;
bool            ea_ts_deleted       = false;
bool            ea_ts_triggered     = false;

//+------------------------------------------------------------------+
//| Configurações de conta e validade                                |
//+------------------------------------------------------------------+
int numero_da_conta = 0; // 0 -> Desativado
datetime data_de_validade = D'2222.01.01'; // 0 -> Desativado

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
double   profit0=0;
double   MaxLossIn0=0;
double   MaxGainIn0=0;
int      handle_MA5=0;
double   buffer5[2];

int      handle_MA10=0;
double   buffer10[2];

int      handle_MA12=0;
double   buffer12[2];

int      handle_MA15=0;
double   buffer15[2];

int      handle_MA20=0;
double   buffer20[2];

int      handle_MA50=0;
double   buffer50[2];

int      handle_MA120=0;
double   buffer120[2];

int      handle_MA150=0;
double   buffer150[2];

int      handle_MA50_1=0;
double   buffer50_1[2];

int      handle_MA50_2=0;
double   buffer50_2[2];

   //***********PAINEL
CAppDialog Painel;
   CLabel Texto;
   CLabel Texto1;
   CLabel Texto2;
   CLabel Texto3;
   CLabel Texto4;
   CLabel Texto5;
   CLabel Texto6;
   CLabel Texto7;
   CLabel Texto8;
   CLabel Texto9;
   CLabel Texto10;
   CLabel Texto11;
   CLabel Texto12;
   CLabel Texto13;
   CLabel Texto14;   
   CLabel Texto15;


int OnInit()
  {
  
  ///////**************************PAINEL
 /*Painel.Create(0,"Indicadores",0,80,20,250,350);
   Texto.Create(0,"Texto",0,5,5,0,0);
   Texto.Text("VALORES");
   Texto.Text("Valor "+DoubleToString(0.00));
   Texto.Color(clrBlue);
   Texto1.Create(0,"Texto1",0,5,20,0,0);
   Texto1.Text("VALORES1");
   Texto1.Text("Valor1 "+DoubleToString(0.00));
   Texto1.Color(clrBlue);
   Texto2.Create(0,"Texto2",0,5,35,0,0);
   Texto2.Text("VALORES2");
   Texto2.Text("Valor2 "+DoubleToString(0.00));
   Texto2.Color(clrBlue);
   Texto3.Create(0,"Texto3",0,5,50,0,0);
   Texto3.Text("VALORES3");
   Texto3.Text("Valor3 "+DoubleToString(0.00));
   Texto3.Color(clrBlue);
   Texto4.Create(0,"Texto4",0,5,65,0,0);
   Texto4.Text("VALORES4");
   Texto4.Text("Valor4 "+DoubleToString(0.00));
   Texto4.Color(clrBlue);
   Texto5.Create(0,"Texto5",0,5,80,0,0);
   Texto5.Text("VALORES5");
   Texto5.Text("Valor5 "+DoubleToString(0.00));
   Texto5.Color(clrBlue);
   Texto6.Create(0,"Texto6",0,5,95,0,0);
   Texto6.Text("VALORES6");
   Texto6.Text("Valor6 "+DoubleToString(0.00));
   Texto6.Color(clrBlue);
   Texto7.Create(0,"Texto7",0,5,110,0,0);
   Texto7.Text("VALORES7");
   Texto7.Text("Valor7 "+DoubleToString(0.00));
   Texto7.Color(clrBlue);
   Texto8.Create(0,"Texto8",0,5,125,0,0);
   Texto8.Text("VALORES8");
   Texto8.Text("Valor8 "+DoubleToString(0.00));
   Texto8.Color(clrBlue);
   Texto9.Create(0,"Texto9",0,5,140,0,0);
   Texto9.Text("VALORES9");
   Texto9.Text("Valor9 "+DoubleToString(0.00));
   Texto9.Color(clrBlue);
   Texto10.Create(0,"Texto10",0,5,155,0,0);
   Texto10.Text("VALORES10");
   Texto10.Text("Valor10 "+DoubleToString(0.00));
   Texto10.Color(clrBlue);
   Texto11.Create(0,"Texto11",0,5,170,0,0);
   Texto11.Text("VALORES11");
   Texto11.Text("Valor11 "+DoubleToString(0.00));
   Texto11.Color(clrBlue);
   Texto12.Create(0,"Texto12",0,5,185,0,0);
   Texto12.Text("VALORES12");
   Texto12.Text("Valor12 "+DoubleToString(0.00));
   Texto12.Color(clrBlue);
   Texto13.Create(0,"Texto13",0,5,200,0,0);
   Texto13.Text("VALORES13");
   Texto13.Text("Valor13 "+DoubleToString(0.00));
   Texto13.Color(clrBlue);
   Texto14.Create(0,"Texto14",0,5,215,0,0);
   Texto14.Text("VALORES14");
   Texto14.Text("Valor14 "+DoubleToString(0.00));
   Texto14.Color(clrBlue);
   Texto15.Create(0,"Texto15",0,5,230,0,0);
   Texto15.Text("VALORES15");
   Texto15.Text("Valor15 "+DoubleToString(0.00));
   Texto15.Color(clrBlue);
   
   Painel.Add(Texto);
   Painel.Add(Texto1);
   Painel.Add(Texto2);
   Painel.Add(Texto3);
   Painel.Add(Texto4);
   Painel.Add(Texto5);
   Painel.Add(Texto6);
   Painel.Add(Texto7);
   Painel.Add(Texto8);
   Painel.Add(Texto9);
   Painel.Add(Texto10);
   Painel.Add(Texto11);
   Painel.Add(Texto12);
   Painel.Add(Texto13);
   Painel.Add(Texto14);
   Painel.Add(Texto15);
  // Painel.Run();*/
   
   //************ FINAL PAINEL
   
   
   
   
   handle_MA5 = iMA(Symbol(),PERIOD_CURRENT,1,0,MODE_SMA,PRICE_CLOSE);
   handle_MA10 = iMA(Symbol(),PERIOD_CURRENT,5,0,MODE_SMA,PRICE_CLOSE);
   handle_MA12 = iMA(Symbol(),PERIOD_CURRENT,10,0,MODE_SMA,PRICE_CLOSE);
   handle_MA15 = iMA(Symbol(),PERIOD_CURRENT,14,0,MODE_SMA,PRICE_CLOSE);
   handle_MA20 = iMA(Symbol(),PERIOD_CURRENT,25,0,MODE_SMA,PRICE_CLOSE);
   handle_MA50 = iMFI(Symbol(),PERIOD_CURRENT,7,VOLUME_TICK);
   handle_MA50_1 = iMFI(Symbol(),PERIOD_CURRENT,14,VOLUME_TICK);
   handle_MA50_2 = iMomentum(Symbol(),PERIOD_CURRENT,25,PRICE_CLOSE);
   

   


   
//---

//---  Validação do EA
   string comment = ea_comment + "\n";

// Validação da conta
   if(numero_da_conta > 0)
     {
      if(numero_da_conta != AccountInfoInteger(ACCOUNT_LOGIN))
        {
         Alert("GridEA liberado somente para a conta: " + IntegerToString(numero_da_conta));
         return INIT_FAILED;
        }
      comment += "EA liberado para conta: " + IntegerToString(numero_da_conta) + "\n";
     }

// Validação de data de validade
   if(data_de_validade > 0)
     {
      if(TimeCurrent() > data_de_validade)
        {
         Alert("GridEA vencido em " + TimeToString(data_de_validade, TIME_DATE));
         return INIT_FAILED;
        }
      comment += "EA com data de validade para: " + TimeToString(data_de_validade, TIME_DATE) + "\n";

     }

   Comment(comment);

   if(ManterTendencia > 0)
     {
     
      double delta = iClose(_Symbol, _Period, 0) - iClose(_Symbol, _Period, 4);
       double delta5 = (iClose(_Symbol, _Period, 0) + iClose(_Symbol, _Period, 1)+ iClose(_Symbol, _Period, 2)+ iClose(_Symbol, _Period, 3)+ iClose(_Symbol, _Period, 4)+ iClose(_Symbol, _Period, 5)+ iClose(_Symbol, _Period, 6)+ iClose(_Symbol, _Period, 7)+ iClose(_Symbol, _Period, 8))/9;
      double delta6 = (iClose(_Symbol, _Period, 0) + iClose(_Symbol, _Period, 1)+ iClose(_Symbol, _Period, 2)+ iClose(_Symbol, _Period, 3)+ iClose(_Symbol, _Period, 4)+ iClose(_Symbol, _Period, 5)+ iClose(_Symbol, _Period, 6)+ iClose(_Symbol, _Period, 7)+ iClose(_Symbol, _Period, 8)+ iClose(_Symbol, _Period, 9)+ iClose(_Symbol, _Period, 10)+ iClose(_Symbol, _Period, 11)+ iClose(_Symbol, _Period, 12)+ iClose(_Symbol, _Period, 13)+ iClose(_Symbol, _Period, 14)+ iClose(_Symbol, _Period, 15)+ iClose(_Symbol, _Period, 16)+ iClose(_Symbol, _Period, 17)+ iClose(_Symbol, _Period, 18)+ iClose(_Symbol, _Period, 19))/20;
      double delta7 = (delta5 - delta6);
      if(buffer5[1]>buffer10[1]&&buffer10[1]>buffer12[1]&&buffer12[1]>buffer15[1]&&buffer15[1]>buffer20[1])
        {
      //   ea_tradeside = BUY;
        }
      if(buffer5[1]<buffer10[1]&&buffer10[1]<buffer12[1]&&buffer12[1]<buffer15[1]&&buffer15[1]<buffer20[1])
        {
      //   ea_tradeside = SELL;
        }
      string comment=StringFormat("Tendencia:\nDelta = %G ",delta);
      ChartSetString(0,CHART_COMMENT,comment);
     }

   /* ea_tradeside = FirstSide;*/

//--- SYMBOL
   ea_symbol = new CSymbolInfo;
   ea_symbol.Name(_Symbol);
   if(!ea_symbol.Refresh())
     {
      Alert("GridEA: Erro na inicialização do símbolo");
      return(INIT_FAILED);
     }
   ea_symbol.RefreshRates();

//--- TRADE
   ea_trade = new CTrade;
   ea_trade.SetExpertMagicNumber(Magic);
   ea_trade.SetTypeFillingBySymbol(_Symbol);

//--- REENTRADAS
   ea_reentrada = new CReentrada;
   ea_reentrada.Magic_(Magic);
   ea_reentrada.Mult(Calculos==POINTS?1:0.0001);
   if(Step>0)
      for(int i=0; i<Quant; i++)
         ea_reentrada.AdicionarReentrada((i+1)*Step, MathPow(Multiplicador, i+1)*InitialVolume, TP);

//--- FINANCE
   ea_finance = new CFinance;

   ea_finance.MaxLossIn(Finance_MaxLossOut);
   MaxLossIn0=(InitialVolume*Finance_MaxLossIn);
   ea_finance.MaxLossOut(Finance_MaxLossOut);
   ea_finance.MaxGainIn((InitialVolume*Finance_MaxGainIn));
   MaxGainIn0=((InitialVolume*Finance_MaxGainIn));
   ea_finance.MaxGainOut(Finance_MaxGainOut);
   ea_finance.MaxOperations(Finance_MaxOperations);
   ea_finance.MaxGainOperations(Finance_MaxOperationsGain);
   ea_finance.MaxLossOperations(Finance_MaxOperationsLoss);
   ea_finance.Magic_(Magic);
   

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("GC - Data Buffer.");
   ZeroMemory(buffer5);
   ZeroMemory(buffer10);
   ZeroMemory(buffer12);
   ZeroMemory(buffer15);
   ZeroMemory(buffer20);
   ZeroMemory(buffer50);
   ZeroMemory(buffer120);
   ZeroMemory(buffer150);
   
   
   Print("GC - Handle signals.");
   ZeroMemory(handle_MA5);
   ZeroMemory(handle_MA10);
   ZeroMemory(handle_MA12);
   ZeroMemory(handle_MA15);
   ZeroMemory(handle_MA20);
   ZeroMemory(handle_MA50);
   ZeroMemory(handle_MA50_1);
   ZeroMemory(handle_MA50_2);
   ZeroMemory(handle_MA120);
   ZeroMemory(handle_MA120);
//--- Remoção dos objetos criados
   if(ea_trade != NULL)
     {
      delete ea_trade;
      ea_trade = NULL;
     }
   if(ea_symbol != NULL)
     {
      delete ea_symbol;
      ea_symbol = NULL;
     }
   if(ea_reentrada != NULL)
     {
      delete ea_reentrada;
      ea_reentrada = NULL;
     }
   if(ea_finance != NULL)
     {
      delete ea_finance;
      ea_finance = NULL;
     }

//--- Limpar comentário
   Comment("");
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
 
   ZeroMemory(buffer5);
   CopyBuffer(handle_MA5,0,0,2,buffer5);
   
   PrintFormat("buffer12[0]= %f - buffer12[1]= %f",buffer5[0],buffer5[1]);
   ZeroMemory(buffer10);
   CopyBuffer(handle_MA10,0,0,2,buffer10);
   
   PrintFormat("buffer25[0]= %f - buffer25[1]= %f",buffer10[0],buffer10[1]);
   ZeroMemory(buffer12);
   
   CopyBuffer(handle_MA12,0,0,2,buffer12);
   
   ZeroMemory(buffer15);
   CopyBuffer(handle_MA15,0,0,2,buffer15);
   
   ZeroMemory(buffer20);
   CopyBuffer(handle_MA20,0,0,2,buffer20);
   
   ZeroMemory(buffer50);
   CopyBuffer(handle_MA50,0,0,2,buffer50);
   
   ZeroMemory(buffer50_1);
   CopyBuffer(handle_MA50_1,0,0,2,buffer50_1);
   
   ZeroMemory(buffer50_2);
   CopyBuffer(handle_MA50_2,0,0,2,buffer50_2);
   
   PrintFormat("buffer50[0]= %f - buffer50[1]= %f",buffer50[0],buffer50[1]);
   ZeroMemory(buffer120);
   CopyBuffer(handle_MA120,0,0,2,buffer120);
   
   ZeroMemory(buffer150);
   CopyBuffer(handle_MA150,0,0,2,buffer150);
   
   
   
   double buf5= buffer10[1]-buffer5[1];
   double buf5a= fabs(buffer10[1]-buffer5[1]);
   double Dif510 = fabs(buffer20[1]-buffer5[1]);
   double buf12= buffer12[1]-buffer10[1];
   double buf10= buffer12[1]-buffer5[1];
   double buf15= buffer15[1]-buffer10[1];
   double buf20= buffer20[1]-buffer15[1];
   double buf50= buffer50[1]-buffer20[1];
   double buf120= buffer120[1]-buffer50[1];   
   double buf150= buffer150[1]-buffer120[1];
   
   Print("---------------------------------------------------");
   
   double delta1 = iClose(_Symbol, _Period, 0) - iClose(_Symbol, _Period, 5);
   double delta2 = iClose(_Symbol, _Period, 1) - iClose(_Symbol, _Period, 1);
   double delta3 = iClose(_Symbol, _Period, 0) - iClose(_Symbol, _Period, 5);
   double delta4 = iClose(_Symbol, _Period, 0) - iClose(_Symbol, _Period, 4);
   double delta5 = (iClose(_Symbol, _Period, 0) + iClose(_Symbol, _Period, 1)+ iClose(_Symbol, _Period, 2)+ iClose(_Symbol, _Period, 3)+ iClose(_Symbol, _Period, 4)+ iClose(_Symbol, _Period, 5)+ iClose(_Symbol, _Period, 6)+ iClose(_Symbol, _Period, 7)+ iClose(_Symbol, _Period, 8))/9;
   double delta6 = (iClose(_Symbol, _Period, 0) + iClose(_Symbol, _Period, 1)+ iClose(_Symbol, _Period, 2)+ iClose(_Symbol, _Period, 3)+ iClose(_Symbol, _Period, 4)+ iClose(_Symbol, _Period, 5)+ iClose(_Symbol, _Period, 6)+ iClose(_Symbol, _Period, 7)+ iClose(_Symbol, _Period, 8)+ iClose(_Symbol, _Period, 9)+ iClose(_Symbol, _Period, 10)+ iClose(_Symbol, _Period, 11)+ iClose(_Symbol, _Period, 12)+ iClose(_Symbol, _Period, 13)+ iClose(_Symbol, _Period, 14)+ iClose(_Symbol, _Period, 15)+ iClose(_Symbol, _Period, 16)+ iClose(_Symbol, _Period, 17)+ iClose(_Symbol, _Period, 18)+ iClose(_Symbol, _Period, 19))/20;
   double delta7 = (delta5 - delta6);
   double delta9 = fabs(delta7);
   double Media0 = iClose(_Symbol,_Period,0);
   double Media5 = (iClose(_Symbol, _Period, 0)+ iClose(_Symbol, _Period, 1)+ iClose(_Symbol, _Period, 2)+ iClose(_Symbol, _Period, 3)+ iClose(_Symbol, _Period, 4))/5;
   double Media10 = (iClose(_Symbol, _Period, 1)+ iClose(_Symbol, _Period, 2)+ iClose(_Symbol, _Period, 3)+ iClose(_Symbol, _Period, 4)+ iClose(_Symbol, _Period, 5)+ iClose(_Symbol, _Period, 6)+ iClose(_Symbol, _Period, 7)+ iClose(_Symbol, _Period, 8)+ iClose(_Symbol, _Period, 9)+ iClose(_Symbol, _Period, 10))/10;   
   double Media9 =  (iClose(_Symbol, _Period, 0) + iClose(_Symbol, _Period, 1)+ iClose(_Symbol, _Period, 2)+ iClose(_Symbol, _Period, 3)+ iClose(_Symbol, _Period, 4)+ iClose(_Symbol, _Period, 5)+ iClose(_Symbol, _Period, 6)+ iClose(_Symbol, _Period, 7)+ iClose(_Symbol, _Period, 8))/9;
   double Media20 = (iClose(_Symbol, _Period, 0) + iClose(_Symbol, _Period, 1)+ iClose(_Symbol, _Period, 2)+ iClose(_Symbol, _Period, 3)+ iClose(_Symbol, _Period, 4)+ iClose(_Symbol, _Period, 5)+ iClose(_Symbol, _Period, 6)+ iClose(_Symbol, _Period, 7)+ iClose(_Symbol, _Period, 8)+ iClose(_Symbol, _Period, 9)+ iClose(_Symbol, _Period, 10)+ iClose(_Symbol, _Period, 11)+ iClose(_Symbol, _Period, 12)+ iClose(_Symbol, _Period, 13)+ iClose(_Symbol, _Period, 14)+ iClose(_Symbol, _Period, 15)+ iClose(_Symbol, _Period, 16)+ iClose(_Symbol, _Period, 17)+ iClose(_Symbol, _Period, 18)+ iClose(_Symbol, _Period, 19))/20;
   double Media30 = (iClose(_Symbol, _Period, 0) + iClose(_Symbol, _Period, 1)+ iClose(_Symbol, _Period, 2)+ iClose(_Symbol, _Period, 3)+ iClose(_Symbol, _Period, 4)+ iClose(_Symbol, _Period, 5)+ iClose(_Symbol, _Period, 6)+ iClose(_Symbol, _Period, 7)+ iClose(_Symbol, _Period, 8)+ iClose(_Symbol, _Period, 9)+ iClose(_Symbol, _Period, 10)+ iClose(_Symbol, _Period, 11)+ iClose(_Symbol, _Period, 12)+ iClose(_Symbol, _Period, 13)+ iClose(_Symbol, _Period, 14)+ iClose(_Symbol, _Period, 15)+ iClose(_Symbol, _Period, 16)+ iClose(_Symbol, _Period, 17)+ iClose(_Symbol, _Period, 18)+ iClose(_Symbol, _Period, 19)+ iClose(_Symbol, _Period, 20)+ iClose(_Symbol, _Period, 21)+ iClose(_Symbol, _Period, 22)+ iClose(_Symbol, _Period, 23)+ iClose(_Symbol, _Period, 24)+ iClose(_Symbol, _Period, 25)+ iClose(_Symbol, _Period, 26)+ iClose(_Symbol, _Period, 27)+ iClose(_Symbol, _Period, 28)+ iClose(_Symbol, _Period, 29))/30;
   double Media50 = (iClose(_Symbol, _Period, 0) + iClose(_Symbol, _Period, 1)+ iClose(_Symbol, _Period, 2)+ iClose(_Symbol, _Period, 3)+ iClose(_Symbol, _Period, 4)+ iClose(_Symbol, _Period, 5)+ iClose(_Symbol, _Period, 6)+ iClose(_Symbol, _Period, 7)+ iClose(_Symbol, _Period, 8)+ iClose(_Symbol, _Period, 9)+ iClose(_Symbol, _Period, 10)+ iClose(_Symbol, _Period, 11)+ iClose(_Symbol, _Period, 12)+ iClose(_Symbol, _Period, 13)+ iClose(_Symbol, _Period, 14)+ iClose(_Symbol, _Period, 15)+ iClose(_Symbol, _Period, 16)+ iClose(_Symbol, _Period, 17)+ iClose(_Symbol, _Period, 18)+ iClose(_Symbol, _Period, 19)+ iClose(_Symbol, _Period, 20)+ iClose(_Symbol, _Period, 21)+ iClose(_Symbol, _Period, 22)+ iClose(_Symbol, _Period, 23)+ iClose(_Symbol, _Period, 24)+ iClose(_Symbol, _Period, 25)+ iClose(_Symbol, _Period, 26)+ iClose(_Symbol, _Period, 27)+ iClose(_Symbol, _Period, 28)+ iClose(_Symbol, _Period, 29)+ iClose(_Symbol, _Period, 30)+ iClose(_Symbol, _Period, 31)+ iClose(_Symbol, _Period, 32)+ iClose(_Symbol, _Period, 33)+ iClose(_Symbol, _Period, 34)+ iClose(_Symbol, _Period, 35)+ iClose(_Symbol, _Period, 36)+ iClose(_Symbol, _Period, 37)+ iClose(_Symbol, _Period, 38)+ iClose(_Symbol, _Period, 39)+ iClose(_Symbol, _Period, 40)+ iClose(_Symbol, _Period, 41)+ iClose(_Symbol, _Period, 42)+ iClose(_Symbol, _Period, 43)+ iClose(_Symbol, _Period, 44)+ iClose(_Symbol, _Period, 45)+ iClose(_Symbol, _Period, 46)+ iClose(_Symbol, _Period, 47)+ iClose(_Symbol, _Period, 48)+ iClose(_Symbol, _Period, 49))/50;
   double Dif09 = fabs(Media0-Media9);
   double Result = Media5-Media10;
   
 
   double Dif020 = fabs(Media0-Media20);
   double Dif030 = fabs(Media0-Media30);
   double Dif050 = fabs(Media0-Media50);
   double Dif920 =   fabs(Media9-Media20);
   double Dif930 =   fabs(Media9-Media30);
   double Dif950 =   fabs(Media9-Media50);
   double Dif2030 =  fabs(Media20-Media30);
   double Dif2050 =  fabs(Media20-Media50);
   double Dif3050 = fabs(Media30-Media50);
   double Volume = (iVolume(_Symbol,_Period,0));
   double VolumeA = (iVolume(_Symbol,_Period,1));
   double VolumeAA = (iVolume(_Symbol,_Period,2));
   int Mo = 10*fabs(100-buffer50_2[1]);
   int entrada_adicional;
   int Vo = InitialVolume+entrada_adicional;
   if(Mo>5&&Mo<9&&Vol>=1)
   {
   Vo = (Vol+Mo/2);
   }
  
datetime horaLocal = TimeLocal();

int hora = (horaLocal / 3600) % 24;
int minutos = (horaLocal / 60) % 60;
int segundos = horaLocal % 60;

int horaInteiro = hora * 10000 + minutos * 100 + segundos;

      if (hora <=9)
      {
      saldo = AccountInfoDouble(ACCOUNT_BALANCE);
      saldo_lucro                   = saldo*porcentagem_diaria;
      Finance_MaxGainOut            = porcentagem_diaria*saldo*2;
      Finance_MaxLossOut            = porcentagem_diaria*saldo*2; 
      if(MaxGainIn0<250)
      {
      entrada_adicional=0;
      }
      if(MaxGainIn0>250)
      {
      entrada_adicional=saldo/5000;
      Vo = InitialVolume+entrada_adicional;
      }
      Finance_MaxGainIn             = saldo_lucro;          // Ganho para entradas
      }
      if (hora >= 9)
   {
   ea_finance.MaxGainIn((InitialVolume*Finance_MaxGainIn)/1);
   MaxGainIn0=((InitialVolume*Finance_MaxGainIn)/1);
   Finance_MaxGainOut            = porcentagem_diaria*saldo*2;
      entrada_adicional=saldo/5000;
      Vo = InitialVolume+entrada_adicional;
   }
      if (hora >= 12)
      
   {
   ea_finance.MaxGainIn((InitialVolume*Finance_MaxGainIn)/2);
   MaxGainIn0=((InitialVolume*Finance_MaxGainIn)/2);
   }
      if (hora >= 13)
   {
   ea_finance.MaxGainIn((InitialVolume*Finance_MaxGainIn)/3);
   MaxGainIn0=((InitialVolume*Finance_MaxGainIn)/3);
   }

  /* if(Dif020<ManterTendencia/3||Dif920<ManterTendencia/4&&Dif930<ManterTendencia/4||Dif920<ManterTendencia/4&&Dif950<ManterTendencia/4||Dif920<ManterTendencia/4&&Dif2030<ManterTendencia/4||Dif920<ManterTendencia/4&&Dif2050<ManterTendencia/4||Dif930<ManterTendencia/4&&Dif3050<ManterTendencia/4||Dif2030<ManterTendencia/4&&Dif2050<ManterTendencia/4)
       {
       DeleteAllOrders();
       CloseAllPositions();
       }*/
      /*   if(Dif510<50)
             {
            DeleteAllOrders();
            CloseAllPositions();
             }*/
 
   string comment=StringFormat("\n\n\n\n\n\n\n\n\n\n\n\n\n\nBuffer5[1] = %G\nBuffer10[1] = %G\nBuffer12[1] = %G\n Buffer15[1] = %G\n  Buffer20[1] = %G\n  Dif510 = %G\nMFI_7 = %G\nMFI_14 = %G\n iMomentum = %G\nVol = %G\nLUCRO = %G\nPARADA = %G\nTOTAL LOSS = %G\nSALDO = %G\nENTRADA ADICIONAL = %G\nVALOR SAIDA = %G\n",buffer5[1],buffer10[1],buffer12[1],buffer15[1],buffer20[1],Dif510,buffer50[1],buffer50_1[1],buffer50_2[1],Mo,profit0,MaxGainIn0,hora,saldo,entrada_adicional,Finance_MaxLossOut);
   Texto.Text("MA2 :"+DoubleToString(buffer5[1],_Digits));
   Texto1.Text("MA5 :"+DoubleToString(buffer10[1],_Digits));
   Texto2.Text("MA10 :"+DoubleToString(buffer12[1],_Digits));
   Texto3.Text("MA14 :"+DoubleToString(buffer15[1],_Digits));
   Texto4.Text("MA25 :"+DoubleToString(buffer20[1],_Digits));
   Texto5.Text("MA25-MA2 :"+DoubleToString(Dif510,_Digits));
   Texto6.Text("MFI(7) :"+DoubleToString(buffer50[1],_Digits));
   Texto7.Text("MFI(14) :"+DoubleToString(buffer50_1[1],_Digits));
   Texto8.Text("Momentum(25) :"+DoubleToString(buffer50_2[1],_Digits));
   Texto9.Text("100-Momentum(25) :"+DoubleToString(Mo,_Digits));
   Texto10.Text("MA2-MA5 :"+DoubleToString(buf5,_Digits));  
   Texto11.Text("MA5-MA10 :"+DoubleToString(buf12,_Digits));  
   Texto12.Text("MA14-MA10 :"+DoubleToString(buf15,_Digits));  
   Texto13.Text("MA25-MA14 :"+DoubleToString(buf20,_Digits));
   Texto14.Text("(0=Compra) Decisão :"+DoubleToString(ea_tradeside,_Digits));  




   ChartSetString(0,CHART_COMMENT,comment);
//--- Variáveis auxiliares
   ENUM_LIMIT_TYPES ltype;

//--- Informações de posição e ordem
   bool positioned = PositionOpen();
   bool order_placed = OrderOpen();

//--- Atualizar informações do símbolo
   if(!ea_symbol.RefreshRates())
      return;

//--- Horário da última operação
   if(!positioned && ea_entrytime==0)
      ea_entrytime = TimeCurrent();

//--- Autorizar novos trades
   if(ea_tradedone)
   ea_tradedone = true;
   if(buffer5[1]>buffer10[1]&&buffer10[1]>buffer12[1]&&buffer12[1]>buffer15[1]&&buffer15[1]>buffer20[1]&&Dif510>ManterTendencia&&buffer50[1]>buffer50_1[1]&&Mo>=2)
   {
   ea_tradeside = BUY;
   ea_tradedone = false;
   }
   if(buffer5[1]<buffer10[1]&&buffer10[1]<buffer12[1]&&buffer12[1]<buffer15[1]&&buffer15[1]<buffer20[1]&&Dif510>ManterTendencia&&buffer50[1]<buffer50_1[1]&&Mo>=2)
   
   {
   ea_tradeside = SELL;
   ea_tradedone = false;
   }
     

//--- Leilão
   if(ea_symbol.Bid() >= ea_symbol.Ask())
      return;

//--- verificação de posição
   ea_reentrada.ChecarPosicao();

//--- Checar abertura de operação

   if(HorarioEntrada() && !positioned && TimeCurrent() > ea_entrytime + Delay && !ea_tradedone && !ea_finance.CheckLimit(ltype))
     {
      double mult = Calculos==POINTS?1:0.0001;
      double price, sl, tp;

      if(ManterTendencia > 0)
        {
         double delta = iClose(_Symbol, _Period, 0) - iClose(_Symbol, _Period, 3);
         double delta5 = (iClose(_Symbol, _Period, 0) + iClose(_Symbol, _Period, 1)+ iClose(_Symbol, _Period, 2)+ iClose(_Symbol, _Period, 3)+ iClose(_Symbol, _Period, 4)+ iClose(_Symbol, _Period, 5)+ iClose(_Symbol, _Period, 6)+ iClose(_Symbol, _Period, 7)+ iClose(_Symbol, _Period, 8))/9;
         double delta6 = (iClose(_Symbol, _Period, 0) + iClose(_Symbol, _Period, 1)+ iClose(_Symbol, _Period, 2)+ iClose(_Symbol, _Period, 3)+ iClose(_Symbol, _Period, 4)+ iClose(_Symbol, _Period, 5)+ iClose(_Symbol, _Period, 6)+ iClose(_Symbol, _Period, 7)+ iClose(_Symbol, _Period, 8)+ iClose(_Symbol, _Period, 9)+ iClose(_Symbol, _Period, 10)+ iClose(_Symbol, _Period, 11)+ iClose(_Symbol, _Period, 12)+ iClose(_Symbol, _Period, 13)+ iClose(_Symbol, _Period, 14)+ iClose(_Symbol, _Period, 15)+ iClose(_Symbol, _Period, 16)+ iClose(_Symbol, _Period, 17)+ iClose(_Symbol, _Period, 18)+ iClose(_Symbol, _Period, 19))/20;
         double delta7 = (delta5 - delta6);
         double delta9 = fabs(delta7);
         double Media0 = iClose(_Symbol,_Period,0);
         double Media5 = (iClose(_Symbol, _Period, 1)+ iClose(_Symbol, _Period, 2)+ iClose(_Symbol, _Period, 3)+ iClose(_Symbol, _Period, 4)+ iClose(_Symbol, _Period, 5))/5;
         double Media10 = (iClose(_Symbol, _Period, 1)+ iClose(_Symbol, _Period, 2)+ iClose(_Symbol, _Period, 3)+ iClose(_Symbol, _Period, 4)+ iClose(_Symbol, _Period, 5)+ iClose(_Symbol, _Period, 6)+ iClose(_Symbol, _Period, 7)+ iClose(_Symbol, _Period, 8)+ iClose(_Symbol, _Period, 9)+ iClose(_Symbol, _Period, 10))/10;
         double Media9 =  (iClose(_Symbol, _Period, 0) + iClose(_Symbol, _Period, 1)+ iClose(_Symbol, _Period, 2)+ iClose(_Symbol, _Period, 3)+ iClose(_Symbol, _Period, 4)+ iClose(_Symbol, _Period, 5)+ iClose(_Symbol, _Period, 6)+ iClose(_Symbol, _Period, 7)+ iClose(_Symbol, _Period, 8))/9;
         double Media20 = (iClose(_Symbol, _Period, 0) + iClose(_Symbol, _Period, 1)+ iClose(_Symbol, _Period, 2)+ iClose(_Symbol, _Period, 3)+ iClose(_Symbol, _Period, 4)+ iClose(_Symbol, _Period, 5)+ iClose(_Symbol, _Period, 6)+ iClose(_Symbol, _Period, 7)+ iClose(_Symbol, _Period, 8)+ iClose(_Symbol, _Period, 9)+ iClose(_Symbol, _Period, 10)+ iClose(_Symbol, _Period, 11)+ iClose(_Symbol, _Period, 12)+ iClose(_Symbol, _Period, 13)+ iClose(_Symbol, _Period, 14)+ iClose(_Symbol, _Period, 15)+ iClose(_Symbol, _Period, 16)+ iClose(_Symbol, _Period, 17)+ iClose(_Symbol, _Period, 18)+ iClose(_Symbol, _Period, 19))/20;
         double Media30 = (iClose(_Symbol, _Period, 0) + iClose(_Symbol, _Period, 1)+ iClose(_Symbol, _Period, 2)+ iClose(_Symbol, _Period, 3)+ iClose(_Symbol, _Period, 4)+ iClose(_Symbol, _Period, 5)+ iClose(_Symbol, _Period, 6)+ iClose(_Symbol, _Period, 7)+ iClose(_Symbol, _Period, 8)+ iClose(_Symbol, _Period, 9)+ iClose(_Symbol, _Period, 10)+ iClose(_Symbol, _Period, 11)+ iClose(_Symbol, _Period, 12)+ iClose(_Symbol, _Period, 13)+ iClose(_Symbol, _Period, 14)+ iClose(_Symbol, _Period, 15)+ iClose(_Symbol, _Period, 16)+ iClose(_Symbol, _Period, 17)+ iClose(_Symbol, _Period, 18)+ iClose(_Symbol, _Period, 19)+ iClose(_Symbol, _Period, 20)+ iClose(_Symbol, _Period, 21)+ iClose(_Symbol, _Period, 22)+ iClose(_Symbol, _Period, 23)+ iClose(_Symbol, _Period, 24)+ iClose(_Symbol, _Period, 25)+ iClose(_Symbol, _Period, 26)+ iClose(_Symbol, _Period, 27)+ iClose(_Symbol, _Period, 28)+ iClose(_Symbol, _Period, 29))/30;
         double Media50 = (iClose(_Symbol, _Period, 0) + iClose(_Symbol, _Period, 1)+ iClose(_Symbol, _Period, 2)+ iClose(_Symbol, _Period, 3)+ iClose(_Symbol, _Period, 4)+ iClose(_Symbol, _Period, 5)+ iClose(_Symbol, _Period, 6)+ iClose(_Symbol, _Period, 7)+ iClose(_Symbol, _Period, 8)+ iClose(_Symbol, _Period, 9)+ iClose(_Symbol, _Period, 10)+ iClose(_Symbol, _Period, 11)+ iClose(_Symbol, _Period, 12)+ iClose(_Symbol, _Period, 13)+ iClose(_Symbol, _Period, 14)+ iClose(_Symbol, _Period, 15)+ iClose(_Symbol, _Period, 16)+ iClose(_Symbol, _Period, 17)+ iClose(_Symbol, _Period, 18)+ iClose(_Symbol, _Period, 19)+ iClose(_Symbol, _Period, 20)+ iClose(_Symbol, _Period, 21)+ iClose(_Symbol, _Period, 22)+ iClose(_Symbol, _Period, 23)+ iClose(_Symbol, _Period, 24)+ iClose(_Symbol, _Period, 25)+ iClose(_Symbol, _Period, 26)+ iClose(_Symbol, _Period, 27)+ iClose(_Symbol, _Period, 28)+ iClose(_Symbol, _Period, 29)+ iClose(_Symbol, _Period, 30)+ iClose(_Symbol, _Period, 31)+ iClose(_Symbol, _Period, 32)+ iClose(_Symbol, _Period, 33)+ iClose(_Symbol, _Period, 34)+ iClose(_Symbol, _Period, 35)+ iClose(_Symbol, _Period, 36)+ iClose(_Symbol, _Period, 37)+ iClose(_Symbol, _Period, 38)+ iClose(_Symbol, _Period, 39)+ iClose(_Symbol, _Period, 40)+ iClose(_Symbol, _Period, 41)+ iClose(_Symbol, _Period, 42)+ iClose(_Symbol, _Period, 43)+ iClose(_Symbol, _Period, 44)+ iClose(_Symbol, _Period, 45)+ iClose(_Symbol, _Period, 46)+ iClose(_Symbol, _Period, 47)+ iClose(_Symbol, _Period, 48)+ iClose(_Symbol, _Period, 49))/50;
         double Dif020 =   fabs(Media0-Media20);
         double Result = Media5-Media10;
         
         double Dif920 =   fabs(Media9-Media20);
         double Dif930 =   fabs(Media9-Media30);
         double Dif950 =   fabs(Media9-Media50);
         double Dif2030 =  fabs(Media20-Media30);
         double Dif2050 =  fabs(Media20-Media50);
         double Dif3050 = fabs(Media30-Media50);
         double Volume = (iVolume(_Symbol,_Period,0));
         double VolumeA = (iVolume(_Symbol,_Period,1));
         double VolumeAA = (iVolume(_Symbol,_Period,2));

         

     //*********************************************************************
     ea_tradedone = true;
         if(buffer5[1]>buffer10[1]&&buffer10[1]>buffer12[1]&&buffer12[1]>buffer15[1]&&buffer15[1]>buffer20[1]&&Dif510>ManterTendencia&&buffer50[1]>buffer50_1[1]&&Mo>=2)
           {ea_tradedone = false;
           ea_tradeside = BUY;}

            
         if(buffer5[1]<buffer10[1]&&buffer10[1]<buffer12[1]&&buffer12[1]<buffer15[1]&&buffer15[1]<buffer20[1]&&Dif510>ManterTendencia&&buffer50[1]<buffer50_1[1]&&Mo>=2)
          {ea_tradedone = false;
           ea_tradeside = SELL;}
            
    
         string comment=StringFormat("CHARLES PASSOU POR AQUI!!!!!Tendencia:\nDelta = %G ",delta);
         ChartSetString(0,CHART_COMMENT,comment);
        }

      if(ea_tradeside==BUY)
        {
        double delta9 = fabs(delta7);
         price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         sl = (SL==0)?0:ea_symbol.NormalizePrice(price-(SL)*mult);
         tp = (TP==0)?0:ea_symbol.NormalizePrice(price+TP*mult);
         if(ea_trade.Buy(Vo, _Symbol, price, sl, tp, "GridEA Entrada COMPRA"))
           {
              if(buffer5[1]>buffer10[1]&&buffer10[1]>buffer12[1]&&buffer12[1]>buffer15[1]&&buffer15[1]>buffer20[1]&&Dif510>ManterTendencia&&buffer50[1]>buffer50_1[1]&&Mo>=2)
             {
            ea_entrytime = 0;
            }
           }
        }
      else
        {
        double delta9 = fabs(delta7);
         price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         sl = (SL==0)?0:ea_symbol.NormalizePrice(price+(SL)*mult);
         tp = (TP==0)?0:ea_symbol.NormalizePrice(price-TP*mult);
         if(ea_trade.Sell(Vo, _Symbol, price, sl, tp, "GridEA Entrada VENDA"))
           {
              if(buffer5[1]<buffer10[1]&&buffer10[1]<buffer12[1]&&buffer12[1]<buffer15[1]&&buffer15[1]<buffer20[1]&&Dif510>ManterTendencia&&buffer50[1]<buffer50_1[1]&&Mo>=2)
             {
            ea_entrytime = 0;
            }
           }
        }
      ea_tradedone = true;
      ea_ts_distance = -1;
     }

//--- Ajuste do TP
   if(positioned)
     {
      int total = PositionsTotal();
      double tp = 0;
      for(int i=total-1; i>=0; i--)
        {
         if(!PositionSelectByTicket(PositionGetTicket(i)))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != Magic || PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;

         if(tp==0)
            tp = PositionGetDouble(POSITION_TP);

         if(PositionGetDouble(POSITION_TP) != tp)
            ea_trade.PositionModify(PositionGetTicket(i), PositionGetDouble(POSITION_SL), tp);
        }
     }

//--- verificação de reentradas
   if(positioned)
      ea_reentrada.ChecarReentrada();

//--- verificação do trailing stop
   if(positioned)
      if(TSDistance>=0)
        {
         // iniciar trailing stop e criar linha
         if(ea_ts_distance == -1)
           {
            ea_ts_distance = TSDistance;
            ea_ts_deleted = false;
            ea_ts_triggered = false;
            if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
               ObjectCreate(0, "TrailingStop", OBJ_HLINE, 0, 0, PositionGetDouble(POSITION_PRICE_OPEN) + ea_ts_distance);
            else
               ObjectCreate(0, "TrailingStop", OBJ_HLINE, 0, 0, PositionGetDouble(POSITION_PRICE_OPEN) - ea_ts_distance);

            ObjectSetInteger(0, "TrailingStop", OBJPROP_COLOR, clrDarkBlue);
            ObjectSetInteger(0, "TrailingStop", OBJPROP_STYLE, STYLE_DASHDOT);
           }

         // checagem do movimento do preço
         double price_current = PositionGetDouble(POSITION_PRICE_CURRENT);
         double price_open = PositionGetDouble(POSITION_PRICE_OPEN);
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
           {
            if(price_open + ea_ts_distance < ObjectGetDouble(0, "TrailingStop", OBJPROP_PRICE))
               ObjectSetDouble(0, "TrailingStop", OBJPROP_PRICE, price_open + ea_ts_distance);

            // break even
            if(price_current-price_open >= ea_ts_distance && !ea_ts_triggered)
              {
               if(ea_trade.PositionModify(PositionGetInteger(POSITION_TICKET), ea_symbol.NormalizePrice(price_open+TSGain), PositionGetDouble(POSITION_TP)))
                  ea_ts_triggered = true;
              }
            // trailing
            if(price_current-price_open > ea_ts_distance)
              {
               ea_ts_distance = price_current-price_open;
               ea_trade.PositionModify(PositionGetInteger(POSITION_TICKET), ea_symbol.NormalizePrice(price_open+ea_ts_distance-(TSDistance-TSGain)), PositionGetDouble(POSITION_TP));
               ObjectSetDouble(0, "TrailingStop", OBJPROP_PRICE, price_current);
              }
           }
         else
           {
            if(price_open - ea_ts_distance > ObjectGetDouble(0, "TrailingStop", OBJPROP_PRICE))
               ObjectSetDouble(0, "TrailingStop", OBJPROP_PRICE, price_open - ea_ts_distance);

            // break even
            if(price_open-price_current >= ea_ts_distance && !ea_ts_triggered)
              {
               if(ea_trade.PositionModify(PositionGetInteger(POSITION_TICKET), ea_symbol.NormalizePrice(price_open-TSGain), PositionGetDouble(POSITION_TP)))
                  ea_ts_triggered = true;
              }
            // trailing
            if(price_open-price_current > ea_ts_distance)
              {
               ea_ts_distance = price_open-price_current;
               ea_trade.PositionModify(PositionGetInteger(POSITION_TICKET), ea_symbol.NormalizePrice(price_open-ea_ts_distance+(TSDistance-TSGain)), PositionGetDouble(POSITION_TP));
               ObjectSetDouble(0, "TrailingStop", OBJPROP_PRICE, price_current);
              }
           }
        }
// deletar linha
   if(!positioned && TSDistance >=0 && !ea_ts_deleted)
     {
      ObjectDelete(0, "TrailingStop");
      ea_ts_deleted = true;
     }

//--- Limites financeiros
   if(ea_finance.CheckLimit(ltype))
      if(ltype==LIMIT_MAX_LOSS_OUT || ltype==LIMIT_MAX_GAIN_OUT)
        {
         DeleteAllOrders();
         CloseAllPositions();
        }

//--- Encerramento do dia
   if(HorarioFechamento() && (order_placed || positioned))
     {
      DeleteAllOrders();
      CloseAllPositions();
     }
  }
//+------------------------------------------------------------------+
//| Horário de entrada                                               |
//+------------------------------------------------------------------+
bool HorarioEntrada()
  {
   datetime horario_atual = TimeCurrent();
   datetime horario_inicial = StringToTime(TimeToString(horario_atual, TIME_DATE) + " " + Time_Start);
   datetime horario_final = StringToTime(TimeToString(horario_atual, TIME_DATE) + " " + Time_End);
   return (int)horario_atual >= (int)horario_inicial && (int)horario_atual < (int)horario_final;
  }
//+------------------------------------------------------------------+
//| Horário de fechamento                                            |
//+------------------------------------------------------------------+
bool HorarioFechamento()
  {
   datetime horario_atual = TimeCurrent();
   datetime horario_fechamento = StringToTime(TimeToString(horario_atual, TIME_DATE) + " " + Time_Close);
   return (int)horario_atual >= (int)horario_fechamento;
  }
//+------------------------------------------------------------------+
//| Deletar todas as ordens abertas                                  |
//+------------------------------------------------------------------+
bool DeleteAllOrders()
  {
   bool res = true;
   for(int i = OrdersTotal()-1; i>=0 ; i--)
     {
      if(!OrderSelect(OrderGetTicket(i)))
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != Magic || OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;

      res &= ea_trade.OrderDelete(OrderGetTicket(i));
     }

   return res;
  }
//+------------------------------------------------------------------+
//| Fechar todas as posições abertas                                 |
//+------------------------------------------------------------------+
bool CloseAllPositions()
  {
   bool res = true;
   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      if(!PositionSelectByTicket(PositionGetTicket(i)))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != Magic || PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      res &= ea_trade.PositionClose(PositionGetTicket(i));
     }

   return res;
  }
//+------------------------------------------------------------------+
//| Checar se existe ordem aberta                                    |
//+------------------------------------------------------------------+
bool OrderOpen()
  {
   int  total=OrdersTotal();
   for(int i=total-1; i>=0; i--)
     {
      if(!OrderSelect(OrderGetTicket(i)))
         continue;
      if(OrderGetString(ORDER_SYMBOL)==_Symbol && OrderGetInteger(ORDER_MAGIC)==Magic)
         return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
//| Checar se existe posição aberta                                  |
//+------------------------------------------------------------------+
bool PositionOpen()
  {
   uint total=PositionsTotal();
   for(uint i=0; i<total; i++)
     {
      string position_symbol=PositionGetSymbol(i);
      if(position_symbol==_Symbol && Magic==PositionGetInteger(POSITION_MAGIC))
         return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
//|                                                    Reentrada.mqh |
//|                               Copyright 2019, Charles F. Santana |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CReentrada::CReentrada(void)
  {
   m_priceopen = 0;

   m_symbol.Name(_Symbol);
   m_symbol.Refresh();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CReentrada::~CReentrada(void)
  {
   ArrayFree(m_distance);
   ArrayFree(m_contract);
   ArrayFree(m_takeprofit);
   ArrayFree(m_done);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CReentrada::AdicionarReentrada(double distance, double contract, double takeprofit)
  {
   if(distance <= 0 || contract <= 0 || takeprofit < 0)
      return;

   ArrayResize(m_distance, ArraySize(m_distance) + 1);
   ArrayResize(m_contract, ArraySize(m_contract) + 1);
   ArrayResize(m_takeprofit, ArraySize(m_takeprofit) + 1);
   ArrayResize(m_done, ArraySize(m_done) + 1);

   m_distance[ArraySize(m_distance)-1] = distance*m_mult;
   m_contract[ArraySize(m_contract)-1] = contract;
   m_takeprofit[ArraySize(m_takeprofit)-1] = takeprofit*m_mult/(3*POSITION_VOLUME);

   m_done[ArraySize(m_done)-1] = false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CReentrada::ChecarReentrada(void)
  {
   if(!m_symbol.RefreshRates())
      return;

   if(!PositionSelect(_Symbol))
      return;

   if(m_priceopen==0)
      m_priceopen = PositionGetDouble(POSITION_PRICE_OPEN);

   if(!m_drawn)
     {
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
         for(int i=0; i<ArraySize(m_distance); i++)
           {
            ObjectCreate(0, "Reentrada"+IntegerToString(i), OBJ_HLINE, 0, 0, m_priceopen - m_distance[i]);
            ObjectSetInteger(0, "Reentrada"+IntegerToString(i), OBJPROP_COLOR, clrOrange);
            ObjectSetInteger(0, "Reentrada"+IntegerToString(i), OBJPROP_STYLE, STYLE_DASHDOT);
           }
      else
         for(int i=0; i<ArraySize(m_distance); i++)
           {
            ObjectCreate(0, "Reentrada"+IntegerToString(i), OBJ_HLINE, 0, 0, m_priceopen + m_distance[i]);
            ObjectSetInteger(0, "Reentrada"+IntegerToString(i), OBJPROP_COLOR, clrOrange);
            ObjectSetInteger(0, "Reentrada"+IntegerToString(i), OBJPROP_STYLE, STYLE_DASHDOT);
           }
      m_drawn = true;
     }

   if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
     {
      for(int i=0; i<ArraySize(m_distance); i++)
        {
         if(m_done[i])
            continue;
         double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(price <= m_priceopen - m_distance[i])
           {
            double preco_medio = PositionGetDouble(POSITION_PRICE_OPEN)*PositionGetDouble(POSITION_VOLUME);
            preco_medio += price*m_contract[i];
            preco_medio /= PositionGetDouble(POSITION_VOLUME) + m_contract[i];
            double tp = m_takeprofit[i]==0?0:m_symbol.NormalizePrice(preco_medio + m_takeprofit[i]);
            if(m_trade.Buy(m_contract[i], _Symbol, price, PositionGetDouble(POSITION_SL), tp, "GridEA Reentrada " + IntegerToString(i+1) + " COMPRA"))
              {
               m_done[i] = true;
               ObjectDelete(0, "Reentrada" + IntegerToString(i));
              }
           }
        }
     }
   else
     {
      for(int i=0; i<ArraySize(m_distance); i++)
        {
         if(m_done[i])
            continue;
         double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(price >= m_priceopen + m_distance[i])
           {
            double preco_medio = PositionGetDouble(POSITION_PRICE_OPEN)*PositionGetDouble(POSITION_VOLUME);
            preco_medio += price*m_contract[i];
            preco_medio /= PositionGetDouble(POSITION_VOLUME) + m_contract[i];
            double tp = m_takeprofit[i]==0?0:m_symbol.NormalizePrice(preco_medio - m_takeprofit[i]);
            if(m_trade.Sell(m_contract[i], _Symbol, price, PositionGetDouble(POSITION_SL), tp, "GridEA Reentrada " + IntegerToString(i+1) + " VENDA"))
              {
               m_done[i] = true;
               ObjectDelete(0, "Reentrada" + IntegerToString(i));
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CReentrada::ChecarPosicao(void)
  {
   if(!PositionSelect(_Symbol))
     {
      for(int i=0; i<ArraySize(m_done); i++)
        {
         m_done[i] = false;
         ObjectDelete(0, "Reentrada" + IntegerToString(i));
        }
      m_priceopen = 0;
      m_drawn = false;
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                      Finance.mqh |
//|                                                  Charles F. Santana |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CFinance::CFinance(void) : m_max_loss_in(0),
   m_max_loss_out(0),
   m_max_gain_in(0),
   m_max_gain_out(0),
   m_max_operations(0),
   m_max_gain_operations(0),
   m_max_loss_operations(0)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CFinance::~CFinance(void)
  {
  }
//+------------------------------------------------------------------+
//| Checking limits.                                                 |
//+------------------------------------------------------------------+
bool CFinance::CheckLimit(ENUM_LIMIT_TYPES &ltype)
  {
   double profit = 0;
   int total_deals = 0, gain_deals = 0, loss_deals = 0;
   GetCurrentProfit(profit, total_deals, gain_deals, loss_deals);
   double current_profit = GetLastProfit();
   double delta10 = current_profit;
   

   profit += current_profit;
   profit0=profit;
   
   
Texto15.Text("GANHO SAIDA :"+DoubleToString(profit,_Digits));    
   string comment1=StringFormat("\n\n\n\n\n\n\n\n\n\n\n\n\n\nBuffer5[1] = %G\nDelta10 = %G",profit);
   //******************************************
   string comment2=StringFormat("Variação Atual= %G\nUltimo Candle = %G",delta10);


//--- Loss
   if(profit < 0)
     {
      if(profit <= -m_max_loss_out && m_max_loss_out != 0)
        {
         ltype = LIMIT_MAX_LOSS_OUT;
         return true;
        }
      if(profit <= -m_max_loss_in  && m_max_loss_in != 0)
        {
         ltype = LIMIT_MAX_LOSS_IN;
         return true;
        }
     }

//--- Profit

   if(profit > 0)
     {
           if(profit >= m_max_gain_out  && m_max_gain_out != 0)
        {
         ltype = LIMIT_MAX_GAIN_OUT;
         return true;
        }
      if(profit >= m_max_gain_in  && m_max_gain_in != 0)
        {
         ltype = LIMIT_MAX_GAIN_IN;
         return true;
        }
        
     }

//--- Max operations
   if((total_deals >= m_max_operations  && m_max_operations != 0) ||
      (gain_deals >= m_max_gain_operations  && m_max_gain_operations != 0) ||
      (loss_deals >= m_max_loss_operations  && m_max_loss_operations != 0))
     {
      ltype = LIMIT_MAX_OPERATIONS;
      return true;
     }

//---
   ltype = LIMIT_NONE;
   return false;
  }
//+------------------------------------------------------------------+
//| Get current status                                               |
//+------------------------------------------------------------------+
void CFinance::GetCurrentProfit(double &profit, int &total, int &gain_total, int &loss_total)
  {
   MqlDateTime today;
   TimeCurrent(today);
   today.hour = 0;
   today.min = 0;
   today.sec = 0;
   if(!HistorySelect(StructToTime(today), TimeCurrent()))
      return;

   int totaldeals = HistoryDealsTotal();
   profit = 0.0;
   for(int i=0; i<totaldeals; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket, DEAL_TYPE) != DEAL_TYPE_BUY && HistoryDealGetInteger(ticket, DEAL_TYPE) != DEAL_TYPE_SELL)
         continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != m_magic)
         continue;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
         continue;

      total += 1;
      if(HistoryDealGetDouble(ticket, DEAL_PROFIT)<0)
         loss_total += 1;
      else
         gain_total += 1;

      profit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
     }
  }
//+------------------------------------------------------------------+
//| Get position profit                                              |
//+------------------------------------------------------------------+
double CFinance::GetLastProfit(void)
  {
   if(!PositionSelect(_Symbol))
      return 0;
   return (PositionGetInteger(POSITION_MAGIC) != m_magic)? 0 : PositionGetDouble(POSITION_PROFIT);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
                  
                  {
                  Painel.ChartEvent(id,lparam,dparam,sparam);
                  }
