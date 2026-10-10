const {test}=require('node:test');
const assert=require('node:assert/strict');
const {summarize}=require('../lib/finance_tools');
test('cash flow keeps decimal precision and currencies separate',()=>{
 const result=summarize('aiko_cashflow_summary',{start_date:'2026-09-01',end_date:'2026-09-30'},[],[
  {date:'2026-09-01',type:'income',currency:'THB',amount:'0.1'},
  {date:'2026-09-02',type:'income',currency:'THB',amount:'0.2'},
  {date:'2026-09-03',type:'expense',currency:'THB',amount:'0.05'},
  {date:'2026-09-03',type:'income',currency:'USD',amount:'10'},
 ],[]);
 assert.deepEqual(result,[{currency:'THB',income:'0.3',expense:'0.05',net:'0.25'},{currency:'USD',income:'10',expense:'0',net:'10'}]);
});
test('tools reject unknown names and malformed date ranges',()=>{
 assert.throws(()=>summarize('delete_everything',{},[],[],[]));
 assert.throws(()=>summarize('aiko_budget_status',{start_date:'invalid',end_date:'2026-09-30'},[],[],[]));
});
test('net worth adds signed balances: debts are already negative',()=>{
 const account=(name,type,currency,balance,extra={})=>({name,type,currency,current_balance:balance,is_active:true,include_in_net_worth:true,...extra});
 const result=summarize('aiko_account_summary',{},[
  account('Checking','bank','THB','1000.10'),
  account('Visa','creditCard','THB','-200.05'),
  account('Car loan','loan','THB','-300'),
  account('Amex','creditCard','THB','50'),
  account('Trip fund','goal','THB','999'),
  account('Hidden','bank','THB','5000',{include_in_net_worth:false}),
  account('Closed','bank','THB','7000',{is_active:false}),
  account('Wise','bank','USD','20'),
 ],[],[]);
 assert.deepEqual(result.net_worth_by_currency,{THB:'550.05',USD:'20'});
});
