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
