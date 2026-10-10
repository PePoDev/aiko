const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,deleteDoc,onSnapshot,disableNetwork,enableNetwork}=require('firebase/firestore');
const {ref,uploadBytes,getBytes}=require('firebase/storage');
let env;
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-aiko-tests',firestore:{host:'127.0.0.1',port:8081,rules:fs.readFileSync('firebase/firestore.rules','utf8')},storage:{host:'127.0.0.1',port:9199,rules:fs.readFileSync('firebase/storage.rules','utf8')}});});
after(async()=>{if(env)await env.cleanup();});
const account={id:'cash',user_id:'alice',name:'Cash',currency:'THB',type:'cash',current_balance:'100.10'};
test('finance records require authentication, correct owner, and decimal strings',async()=>{
 const alice=env.authenticatedContext('alice').firestore();
 await assertSucceeds(setDoc(doc(alice,'users/alice/accounts/cash'),account));
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'users/alice/accounts/cash')));
 await assertFails(getDoc(doc(env.authenticatedContext('bob').firestore(),'users/alice/accounts/cash')));
 await assertFails(setDoc(doc(alice,'users/alice/accounts/cash'),{...account,user_id:'bob'}));
 await assertFails(setDoc(doc(alice,'users/alice/accounts/cash'),{...account,current_balance:100.1}));
 await assertFails(setDoc(doc(alice,'users/alice/integrations/line'),{connected:true}));
});
test('default category identity is immutable while its budget stays editable',async()=>{
 const db=env.authenticatedContext('alice').firestore(), target=doc(db,'users/alice/categories/template');
 const category={id:'template',user_id:'alice',template_id:'coffee',name:'Coffee',budget_amount:'20'};
 await assertSucceeds(setDoc(target,category));
 await assertSucceeds(setDoc(target,{...category,budget_amount:'30'}));
 await assertFails(setDoc(target,{...category,name:'Renamed'}));
 await assertFails(deleteDoc(target));
});
test('a default clone seeded without created_at keeps its budget editable',async()=>{
 const db=env.authenticatedContext('alice').firestore(), target=doc(db,'users/alice/categories/seeded');
 // Shape written by sign-in seeding: created_at is null.
 const seeded={id:'seeded',user_id:'alice',template_id:'coffee',name:'Coffee',created_at:null,budget_amount:null,budget_currency:null,updated_at:'2026-10-01T00:00:00.000Z',version:1};
 await assertSucceeds(setDoc(target,seeded));
 const budgeted={...seeded,budget_amount:'30',budget_currency:'THB',updated_at:'2026-10-02T00:00:00.000Z',version:2};
 await assertSucceeds(setDoc(target,budgeted));
 // Older clients stamp created_at on their first save; allowed once.
 const stamped={...budgeted,budget_amount:'40',created_at:'2026-10-03T00:00:00.000Z'};
 await assertSucceeds(setDoc(target,stamped));
 await assertFails(setDoc(target,{...stamped,created_at:'2026-10-04T00:00:00.000Z'}));
 await assertFails(setDoc(target,{...stamped,created_at:null}));
 await assertFails(setDoc(target,{...stamped,name:'Renamed'}));
 const group=doc(db,'users/alice/category_groups/seeded');
 const seededGroup={id:'seeded',user_id:'alice',template_id:'food',name:'Food & Drink',created_at:null,budget_amount:null,budget_currency:null};
 await assertSucceeds(setDoc(group,seededGroup));
 await assertSucceeds(setDoc(group,{...seededGroup,budget_amount:'500',budget_currency:'THB'}));
});
test('independent clients observe edits and hard deletes',async()=>{
 const first=env.authenticatedContext('sync').firestore(),second=env.authenticatedContext('sync').firestore();
 const a=doc(first,'users/sync/preferences/test'),b=doc(second,'users/sync/preferences/test');
 await setDoc(a,{value:'first'});
 await assertSucceeds(getDoc(b));
 const waitFor=(predicate)=>new Promise((resolve,reject)=>{
  const timeout=setTimeout(()=>{unsubscribe();reject(new Error('snapshot timed out'));},10000);
  const unsubscribe=onSnapshot(b,s=>{if(predicate(s)){clearTimeout(timeout);unsubscribe();resolve();}},reject);
 });
 const changed=waitFor(s=>s.data()?.value==='second');
 await setDoc(a,{value:'second'}); await changed;
 const deleted=waitFor(s=>!s.exists());
 await deleteDoc(a); await deleted;
});
test('Firebase queues offline writes and delivers them after reconnect',async()=>{
 const first=env.authenticatedContext('offline').firestore(),second=env.authenticatedContext('offline').firestore();
 const a=doc(first,'users/offline/preferences/theme'),b=doc(second,'users/offline/preferences/theme');
 await setDoc(a,{value:'light'});
 await disableNetwork(first);
 const pending=setDoc(a,{value:'dark'});
 const local=await new Promise(resolve=>{const unsub=onSnapshot(a,{includeMetadataChanges:true},s=>{if(s.metadata.hasPendingWrites){unsub();resolve(s.data());}});});
 assert.equal(local.value,'dark');
 await enableNetwork(first);await pending;
 assert.equal((await getDoc(b)).data().value,'dark');
});
test('storage permits only the owner and supported attachment content',async()=>{
 const alice=env.authenticatedContext('alice').storage('gs://demo-aiko-tests.appspot.com');
 const bob=env.authenticatedContext('bob').storage('gs://demo-aiko-tests.appspot.com');
 const path='users/alice/receipts/test.txt';
 await assertSucceeds(uploadBytes(ref(alice,path),new Uint8Array([65,66]),{contentType:'text/plain'}));
 await assertFails(getBytes(ref(bob,path)));
 await assertFails(uploadBytes(ref(alice,'users/bob/receipts/no.txt'),new Uint8Array([65]),{contentType:'text/plain'}));
 await assertFails(uploadBytes(ref(alice,'users/alice/receipts/no.exe'),new Uint8Array([65]),{contentType:'application/x-msdownload'}));
});
