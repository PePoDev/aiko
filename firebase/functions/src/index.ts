import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { onCall, onRequest, HttpsError } from 'firebase-functions/v2/https';
import { setGlobalOptions } from 'firebase-functions/v2';
import { createHash, createHmac, randomInt, timingSafeEqual } from 'node:crypto';
import { buildModel, isRequestBody, systemPromptFor, resolveTools, streamAnswer } from './chat';

// Cost guard: cap scale-out so a traffic spike or abuse can't run up the bill.
// Each instance serves up to 80 concurrent requests.
setGlobalOptions({maxInstances: 10});

initializeApp();
const db = getFirestore();
const secrets = ['AI_API_KEY', 'AI_MODEL', 'AI_BASE_URL'];
const lineSecrets = [...secrets, 'LINE_CHANNEL_SECRET', 'LINE_CHANNEL_ACCESS_TOKEN'];

async function rateLimit(uid: string, action: string, max = 30) {
  const ref = db.collection('rate_limits').doc(`${uid}:${action}`);
  await db.runTransaction(async tx => {
    const record = (await tx.get(ref)).data();
    const now = Date.now();
    const count = record && now - record.start < 60000 ? record.count + 1 : 1;
    if (count > max) throw new HttpsError('resource-exhausted', 'Please try again in a minute.');
    tx.set(ref, {count, start: count === 1 ? now : record!.start});
  });
}

export const aikoChat = onRequest({cors:true, timeoutSeconds:300, secrets}, async (req,res) => {
  if (req.method !== 'POST') { res.status(405).json({error:'POST required'}); return; }
  let uid: string;
  try {
    const bearer = req.headers.authorization?.match(/^Bearer (.+)$/)?.[1];
    if (!bearer) throw new Error('No token');
    uid = (await getAuth().verifyIdToken(bearer)).uid;
  } catch { res.status(401).json({error:'Sign in to use Aiko.'}); return; }
  try { await rateLimit(uid,'chat'); } catch { res.status(429).json({error:'Please try again in a minute.'}); return; }
  if (!isRequestBody(req.body)) { res.status(400).json({error:'messages array is required'}); return; }
  const model = buildModel();
  if (!model) { res.status(503).json({error:'AI provider is not configured.'}); return; }
  const profile = (await db.doc(`users/${uid}/profiles/${uid}`).get()).data();
  const messages: Record<string,unknown>[] = [{role:'system',content:systemPromptFor(profile?.base_currency ?? 'THB', req.body.financialContext, req.body.systemContext?.locale)},
    ...req.body.messages.filter(m => ['user','assistant'].includes(m.role)).slice(-10).map(m => ({role:m.role,content:m.content.slice(0,1000)}))];
  await resolveTools(uid,messages,model);
  res.set({'Content-Type':'text/event-stream','Cache-Control':'no-cache, no-transform'});
  const event = (data:unknown) => { if (!res.destroyed) res.write(`data: ${JSON.stringify(data)}\n\n`); };
  await streamAnswer(model,messages,{delta:text=>event({delta:text}),done:()=>event({done:true}),fail:error=>event({error})});
  res.end();
});

export const deleteAccount = onCall(async request => {
  if (!request.auth) throw new HttpsError('unauthenticated','Sign in first.');
  if (Date.now()/1000 - Number(request.auth.token.auth_time) > 300) throw new HttpsError('failed-precondition','Sign in again before deleting your account.');
  const uid=request.auth.uid;
  const links=await db.collection('line_links').where('uid','==',uid).get();
  for (const link of links.docs) await link.ref.delete();
  await db.recursiveDelete(db.doc(`users/${uid}`));
  await getStorage().bucket().deleteFiles({prefix:`users/${uid}/`});
  await getAuth().deleteUser(uid);
  return {deleted:true};
});

export const redeemLinePairing = onCall(async request => {
  if (!request.auth) throw new HttpsError('unauthenticated','Sign in first.');
  const uid=request.auth.uid;
  await rateLimit(uid,'pair',5);
  const code=String(request.data?.code ?? '').trim().toUpperCase();
  if (!/^[A-Z2-9]{6}$/.test(code)) throw new HttpsError('invalid-argument','Invalid pairing code.');
  const ref=db.collection('line_pairings').doc(createHash('sha256').update(code).digest('hex'));
  await db.runTransaction(async tx => {
    const pairing=(await tx.get(ref)).data();
    if (!pairing || pairing.expires_at.toMillis() < Date.now()) throw new HttpsError('not-found','Code is invalid or expired.');
    const linkRef=db.collection('line_links').doc(pairing.line_user_id);
    const existing=(await tx.get(linkRef)).data();
    if (existing && existing.uid !== uid) throw new HttpsError('already-exists','LINE account is already connected.');
    tx.set(linkRef,{uid});
    tx.set(db.doc(`users/${uid}/integrations/line`),{connected:true});
    tx.delete(ref);
  });
  return {connected:true};
});

// LINE has no app language: answer in Thai when the user writes Thai, in
// English otherwise, and in both when there is no text (a new follower).
function lineCopy(text: string | undefined): (en: string, th: string) => string {
  if (text === undefined || text.trim() === '') return (en, th) => `${th}\n\n${en}`;
  const thai = /[\u0E00-\u0E7F]/.test(text);
  return (en, th) => (thai ? th : en);
}

export const lineWebhook = onRequest({secrets:lineSecrets,timeoutSeconds:300},async(req,res)=>{
  const secret=process.env.LINE_CHANNEL_SECRET;
  const accessToken=process.env.LINE_CHANNEL_ACCESS_TOKEN;
  if (!secret || !accessToken || [secret,accessToken].includes('local-unconfigured')) {res.status(503).send('LINE is not configured');return;}
  const expected=createHmac('sha256',secret).update(req.rawBody).digest();
  const supplied=Buffer.from(req.header('x-line-signature') ?? '', 'base64');
  if (supplied.length !== expected.length || !timingSafeEqual(expected,supplied)) {res.status(401).send('Invalid signature');return;}
  for(const event of req.body?.events ?? []) {
    const lineId=event.source?.userId;
    if (!lineId || !event.replyToken || !['follow','message'].includes(event.type)) continue;
    if (event.type==='message' && event.message?.type!=='text') continue;
    const link=(await db.collection('line_links').doc(lineId).get()).data();
    const say=lineCopy(event.type==='message' ? String(event.message?.text ?? '') : undefined);
    let answer=say(
      'Aiko is not configured for cloud chat yet. Please try again later.',
      'Aiko ยังไม่พร้อมแชตผ่านคลาวด์ โปรดลองใหม่ภายหลังนะคะ',
    );
    if (!link) {
      const alphabet='ABCDEFGHJKMNPQRSTUVWXYZ23456789';
      const code=Array.from({length:6},()=>alphabet[randomInt(alphabet.length)]).join('');
      await db.collection('line_pairings').doc(createHash('sha256').update(code).digest('hex')).set({line_user_id:lineId,expires_at:Timestamp.fromMillis(Date.now()+600000)});
      answer=say(
        `Open Aiko → Profile → Connect LINE and enter ${code}. This code expires in 10 minutes.`,
        `เปิดแอป Aiko → โปรไฟล์ → เชื่อมต่อ LINE แล้วกรอกรหัส ${code} รหัสนี้หมดอายุใน 10 นาทีค่ะ`,
      );
    } else {
      // Validate that the account still exists; LINE never holds a user's auth tokens.
      await getAuth().getUser(link.uid);
      await rateLimit(link.uid,'lineChat');
      const model=buildModel();
      if(model) {
        const profile=(await db.doc(`users/${link.uid}/profiles/${link.uid}`).get()).data();
        const messages: Record<string,unknown>[]=[{role:'system',content:systemPromptFor(profile?.base_currency ?? 'THB')},{role:'user',content:String(event.message?.text ?? 'Hello').slice(0,1000)}];
        await resolveTools(link.uid,messages,model);
        let text='';
        await streamAnswer(model,messages,{delta:t=>{text+=t;},done:()=>{},fail:()=>{}});
        if(text.trim()) answer=text;
      }
    }
    await fetch('https://api.line.me/v2/bot/message/reply',{method:'POST',headers:{Authorization:`Bearer ${accessToken}`,'Content-Type':'application/json'},body:JSON.stringify({replyToken:event.replyToken,messages:[{type:'text',text:answer.slice(0,4800)}]})});
  }
  res.send('ok');
});

// Existing clients can retain OCR and market-feed behavior with a trusted
// provider configured server-side. No provider key is exposed to the app.
async function providerCall(url:string | undefined, key:string | undefined, data:unknown) {
  if (!url || !key || [url,key].includes('local-unconfigured')) throw new HttpsError('unavailable','This provider is not configured.');
  const response=await fetch(url,{method:'POST',headers:{Authorization:`Bearer ${key}`,'Content-Type':'application/json'},body:JSON.stringify(data),signal:AbortSignal.timeout(30000)});
  if(!response.ok) throw new HttpsError('unavailable','Provider request failed.');
  return response.json();
}
export const ocrScanner=onCall({secrets:['OCR_API_URL','OCR_API_KEY']},async request=>{
  if(!request.auth) throw new HttpsError('unauthenticated','Sign in first.');
  await rateLimit(request.auth.uid,'ocr',10);
  const bytes=request.data?.imageBytes;
  if(!Array.isArray(bytes) || bytes.length===0 || bytes.length>5*1024*1024 || !bytes.every(b=>Number.isInteger(b)&&b>=0&&b<=255)) throw new HttpsError('invalid-argument','Invalid receipt image.');
  return providerCall(process.env.OCR_API_URL,process.env.OCR_API_KEY,{fileName:String(request.data.fileName ?? '').slice(0,255),imageBytes:bytes});
});
export const marketFeed=onCall({secrets:['MARKET_API_URL','MARKET_API_KEY']},async request=>{
  if(!request.auth) throw new HttpsError('unauthenticated','Sign in first.');
  await rateLimit(request.auth.uid,'market');
  const symbol=String(request.data?.symbol ?? '');
  const currency=String(request.data?.currency ?? '');
  if(!/^[A-Za-z0-9.^=-]{1,24}$/.test(symbol)|| !/^[A-Z]{3}$/.test(currency)) throw new HttpsError('invalid-argument','Invalid symbol or currency.');
  return providerCall(process.env.MARKET_API_URL,process.env.MARKET_API_KEY,{symbol,currency});
});
