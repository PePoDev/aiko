// Ask Aiko tools must read only what they need: billed documents stay
// proportional to the question, not to the size of the user's ledger.
const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const {createRequire}=require('node:module');
const path=require('node:path');
const functionsRequire=createRequire(path.resolve(__dirname,'../functions/package.json'));
process.env.FIRESTORE_EMULATOR_HOST='127.0.0.1:8081';
const {initializeApp,deleteApp}=functionsRequire('firebase-admin/app');
const {getFirestore}=functionsRequire('firebase-admin/firestore');
const app=initializeApp({projectId:'demo-aiko-reads'});
const {FinanceReader,financeTool}=require('../functions/lib/finance_tools.js');
const uid=`reader-${Date.now()}`;
const tx=(id,date,type,amount,category_id)=>({id,user_id:uid,account_id:'cash',date,type,amount,currency:'THB',category_id,merchant:id});

before(async()=>{
 const db=getFirestore(app),root=db.collection('users').doc(uid),batch=db.batch();
 for(const row of [
  tx('aug','2026-08-31T23:59:59.000','expense','5','food'),
  tx('sep1','2026-09-01T00:00:00.000','income','100',null),
  tx('sep2','2026-09-15T12:00:00.000','expense','20','food'),
  tx('sep3','2026-09-30T23:59:59.999','expense','7.5','rent'),
  tx('oct','2026-10-01T00:00:00.000','expense','9','food'),
 ]) batch.set(root.collection('transactions').doc(row.id),row);
 batch.set(root.collection('categories').doc('food'),{id:'food',user_id:uid,name:'Food',is_active:true,budget_enabled:true,budget_amount:'50',budget_currency:'THB'});
 batch.set(root.collection('categories').doc('rent'),{id:'rent',user_id:uid,name:'Rent',is_active:true,budget_enabled:false});
 batch.set(root.collection('categories').doc('unused'),{id:'unused',user_id:uid,name:'Unused',is_active:true,budget_enabled:false});
 batch.set(root.collection('accounts').doc('cash'),{id:'cash',user_id:uid,name:'Cash',type:'cash',currency:'THB',current_balance:'68.5',is_active:true,include_in_net_worth:true});
 batch.set(db.collection('users').doc('someone-else').collection('transactions').doc('x'),{...tx('x','2026-09-10','expense','999','food'),user_id:'someone-else'});
 await batch.commit();
});
after(async()=>{await deleteApp(app);});
const range={start_date:'2026-09-01',end_date:'2026-09-30'};

test('date-ranged tools read only that range, inclusive of both ends',async()=>{
 const reader=new FinanceReader(uid);
 assert.deepEqual(await financeTool(uid,'aiko_cashflow_summary',range,reader),[{currency:'THB',income:'100',expense:'27.5',net:'72.5'}]);
 assert.equal(reader.documentsRead,3);
});

test('category names come from the referenced categories only',async()=>{
 const reader=new FinanceReader(uid);
 const spending=await financeTool(uid,'aiko_spending_by_category',range,reader);
 assert.deepEqual(spending.map(s=>[s.category,s.total]),[['Food','20'],['Rent','7.5']]);
 assert.equal(reader.documentsRead,3+2);
});

test('budget status reads budgeted categories only',async()=>{
 const reader=new FinanceReader(uid);
 assert.deepEqual(await financeTool(uid,'aiko_budget_status',range,reader),[{name:'Food',budget_limit:'50',currency:'THB',spent:'20'}]);
 assert.equal(reader.documentsRead,3+1);
});

test('recent transactions read only the newest rows',async()=>{
 const reader=new FinanceReader(uid);
 const recent=await financeTool(uid,'aiko_recent_transactions',{max_rows:2},reader);
 assert.deepEqual(recent.map(t=>[t.merchant,t.category]),[['oct','Food'],['sep3','Rent']]);
 assert.equal(reader.documentsRead,2+2);
});

test('account tools never read transactions',async()=>{
 const reader=new FinanceReader(uid);
 const summary=await financeTool(uid,'aiko_account_summary',{},reader);
 assert.deepEqual(summary.net_worth_by_currency,{THB:'68.5'});
 assert.equal(reader.documentsRead,1);
});

test('one request never reads the same data twice',async()=>{
 const reader=new FinanceReader(uid);
 await financeTool(uid,'aiko_cashflow_summary',range,reader);
 await financeTool(uid,'aiko_spending_by_category',range,reader);
 await financeTool(uid,'aiko_cashflow_summary',range,reader);
 assert.equal(reader.documentsRead,3+2);
});

test('invalid ranges are rejected before any read',async()=>{
 const reader=new FinanceReader(uid);
 await assert.rejects(financeTool(uid,'aiko_cashflow_summary',{start_date:'2026-09-30',end_date:'2026-09-01'},reader));
 assert.equal(reader.documentsRead,0);
});
