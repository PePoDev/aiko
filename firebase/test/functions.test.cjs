const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createRequire}=require('node:module');
const path=require('node:path');
const functionsRequire=createRequire(path.resolve(__dirname,'../functions/package.json'));
process.env.FIRESTORE_EMULATOR_HOST='127.0.0.1:8081';
process.env.FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099';
process.env.FIREBASE_STORAGE_EMULATOR_HOST='127.0.0.1:9199';
const {initializeApp,deleteApp}=functionsRequire('firebase-admin/app');
const {getAuth}=functionsRequire('firebase-admin/auth');
const {getFirestore}=functionsRequire('firebase-admin/firestore');
const {getStorage}=functionsRequire('firebase-admin/storage');
const base='http://127.0.0.1:5001/demo-aiko/us-central1/';
async function call(name,data,token) {
 return fetch(base+name,{method:'POST',headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},body:JSON.stringify({data})});
}
test('privileged functions reject unauthenticated callers',async()=>{
 for(const name of ['deleteAccount','redeemLinePairing','ocrScanner','marketFeed']) {
  assert.equal((await call(name,{})).status,401,name);
 }
 assert.equal((await fetch(base+'aikoChat',{method:'POST',headers:{'Content-Type':'application/json'},body:'{"messages":[]}'})).status,401);
});
test('account deletion removes only the authenticated owner and their files',async()=>{
 const app=initializeApp({projectId:'demo-aiko',storageBucket:'demo-aiko.appspot.com'},'deletion-test');
 const db=getFirestore(app),auth=getAuth(app),bucket=getStorage(app).bucket();
 let uid,other;
 try {
  const response=await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-api-key',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:`deletion-${Date.now()}@example.com`,password:'LocalTest123!',returnSecureToken:true})});
  const user=await response.json();uid=user.localId;assert.ok(uid);
  other=(await auth.createUser({email:`retained-${Date.now()}@example.com`})).uid;
  await db.doc(`users/${uid}/accounts/cash`).set({user_id:uid});
  await db.doc(`users/${other}/accounts/cash`).set({user_id:other});
  await db.doc(`line_links/${uid}`).set({uid});
  await bucket.file(`users/${uid}/receipts/test.txt`).save('receipt',{contentType:'text/plain'});
  assert.equal((await call('ocrScanner',{imageBytes:[]},user.idToken)).status,400);
  const chat=await fetch(base+'aikoChat',{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${user.idToken}`},body:JSON.stringify({messages:[{role:'user',content:'Hello'}]})});
  assert.equal(chat.status,503);
  const deleted=await call('deleteAccount',{},user.idToken);
  assert.equal(deleted.status,200,await deleted.text());
  assert.equal((await db.doc(`users/${uid}/accounts/cash`).get()).exists,false);
  assert.equal((await db.doc(`line_links/${uid}`).get()).exists,false);
  assert.equal((await bucket.file(`users/${uid}/receipts/test.txt`).exists())[0],false);
  await assert.rejects(auth.getUser(uid),{code:'auth/user-not-found'});
  assert.equal((await db.doc(`users/${other}/accounts/cash`).get()).exists,true);
 } finally {
  for(const id of [uid,other].filter(Boolean)) {
   await db.recursiveDelete(db.doc(`users/${id}`));
   await auth.deleteUser(id).catch(()=>{});
   await db.doc(`rate_limits/${id}:ocr`).delete();
   await db.doc(`rate_limits/${id}:chat`).delete();
  }
  await deleteApp(app);
 }
});
