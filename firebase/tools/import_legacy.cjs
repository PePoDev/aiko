// Imports a JSON export into Firebase. Dry run by default; never contacts a
// source database. Keep original auth IDs to preserve every record reference.
const fs = require('node:fs');
const path = require('node:path');
const {createRequire}=require('node:module');
const functionsRequire=createRequire(path.resolve(__dirname,'../functions/package.json'));
const {initializeApp}=functionsRequire('firebase-admin/app');
const {getAuth}=functionsRequire('firebase-admin/auth');
const {getFirestore}=functionsRequire('firebase-admin/firestore');
const {getStorage,getDownloadURL}=functionsRequire('firebase-admin/storage');
const {randomUUID}=require('node:crypto');
const allowed=new Set(['profiles','accounts','categories','category_groups','transactions','investment_holdings','attachments','transaction_splits']);
const moneyFields=new Set(['current_balance','amount','budget_amount','goal_target_amount','quantity','average_cost','current_price','market_value']);

function prepare(data) {
 const records=[];
 for(const [collection,rows] of Object.entries(data.tables ?? {})) {
  if(!allowed.has(collection)) throw new Error(`Unsupported table: ${collection}`);
  for(const row of rows) {
   // Global category templates are shipped with the app and cloned at login.
   if(['categories','category_groups'].includes(collection) && row.user_id==null) continue;
   const uid=collection==='profiles'?row.id:row.user_id;
   if(typeof uid!=='string'||typeof row.id!=='string'||uid.includes('/')||row.id.includes('/')) throw new Error('Invalid record identity');
   for(const field of moneyFields) if(row[field]!=null && typeof row[field]!=='string') throw new Error(`Export ${collection}.${field} as a decimal string to preserve precision.`);
   const next={...row};
   if(collection==='attachments') {
    next.storage_path=`users/${uid}/receipts/${row.id}/${path.basename(row.file_name)}`;
    next.storage_bucket='firebase';
   }
   if(collection==='profiles') {next.avatar_path=null;next.avatar_url=null;}
   records.push({path:`users/${uid}/${collection}/${row.id}`,data:next});
  }
 }
 const users=(data.users ?? []).map(user=>({uid:user.id,email:user.email,emailVerified:!!user.email_confirmed_at,
   ...(user.encrypted_password?{passwordHash:Buffer.from(user.encrypted_password)}:{})}));
 return {records,users,files:data.files ?? []};
}

async function main() {
 const file=process.argv[2];
 if(!file) throw new Error('Usage: node firebase/tools/import_legacy.cjs export.json [--apply]');
 const data=prepare(JSON.parse(fs.readFileSync(file,'utf8')));
 console.log(JSON.stringify({users:data.users.length,documents:data.records.length,files:data.files.length,apply:process.argv.includes('--apply')}));
 if(!process.argv.includes('--apply')) return;
 const projectId=process.env.GCLOUD_PROJECT;
 if(!projectId) throw new Error('Set GCLOUD_PROJECT explicitly. For emulators also set FIREBASE_AUTH_EMULATOR_HOST, FIRESTORE_EMULATOR_HOST and FIREBASE_STORAGE_EMULATOR_HOST.');
 initializeApp({projectId,storageBucket:process.env.FIREBASE_STORAGE_BUCKET ?? `${projectId}.appspot.com`});
 const root=path.dirname(path.resolve(file));
 for(const file of data.files) {
  if(!/^users\/[^/]+\/(receipts|avatars|documents)\/.+/.test(file.destination)) throw new Error('Invalid storage destination');
  const local=path.resolve(root,file.path);
  if(!local.startsWith(root+path.sep)) throw new Error('Storage source must be inside the export directory');
  const [uploaded] = await getStorage().bucket().upload(local,{
   destination:file.destination,
   metadata:{contentType:file.contentType,metadata:{firebaseStorageDownloadTokens:randomUUID()}},
   preconditionOpts:{ifGenerationMatch:0},
  }).catch(error=>{if(error.code===412) return [getStorage().bucket().file(file.destination)]; throw error;});
  if(file.profileId) {
   if(!file.destination.startsWith(`users/${file.profileId}/avatars/`)) throw new Error('Avatar owner does not match profile');
   const profile=data.records.find(record=>record.path===`users/${file.profileId}/profiles/${file.profileId}`);
   if(!profile) throw new Error('Avatar must reference a profile in this export');
   profile.data.avatar_url=await getDownloadURL(uploaded);
  }
 }
 for(let i=0;i<data.users.length;i+=1000) {
  const result=await getAuth().importUsers(data.users.slice(i,i+1000),{hash:{algorithm:'BCRYPT'}});
  if(result.failureCount) throw new Error(`Auth import rejected ${result.failureCount} users; review export before retrying.`);
 }
 // Create-only: a retry cannot overwrite a record changed since migration.
 for(const record of data.records) {
  try { await getFirestore().doc(record.path).create(record.data); }
  catch(error) { if(error.code!==6) throw error; }
 }
 console.log('Import complete. Verify counts and storage previews before changing production configuration.');
}
module.exports={prepare};
if(require.main===module) main().catch(error=>{console.error(error.message);process.exitCode=1;});
