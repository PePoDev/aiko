const {test}=require('node:test');
const assert=require('node:assert/strict');
const {prepare}=require('../../tools/import_legacy.cjs');
test('import preserves IDs, references, and decimal strings',()=>{
 const result=prepare({tables:{accounts:[{id:'cash',user_id:'user',current_balance:'999999999999.99'}],transactions:[{id:'tx',user_id:'user',account_id:'cash',amount:'0.01'}]}});
 assert.equal(result.records[0].path,'users/user/accounts/cash');
 assert.equal(result.records[0].data.current_balance,'999999999999.99');
 assert.equal(result.records[1].data.account_id,'cash');
});
test('import rejects lossy numbers and never imports global templates',()=>{
 assert.throws(()=>prepare({tables:{accounts:[{id:'cash',user_id:'user',current_balance:0.1}]}}));
 assert.deepEqual(prepare({tables:{categories:[{id:'template',user_id:null}]}}).records,[]);
});
