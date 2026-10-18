import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { onCall, onRequest, HttpsError } from 'firebase-functions/v2/https';
import { setGlobalOptions } from 'firebase-functions/v2';
import * as logger from 'firebase-functions/logger';
import { createHash, createHmac, randomInt, timingSafeEqual } from 'node:crypto';
import { answerChat, buildModel, isRequestBody, systemPromptFor } from './chat';
import { applyCors, ocrProviderBody, receiptImage } from './http';

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

// CORS is handled in the function (applyCors) instead of `cors: true` so that
// preflights carry Access-Control-Max-Age.
export const aikoChat = onRequest({timeoutSeconds:300, secrets}, async (req,res) => {
  if (applyCors(req,res)) return;
  if (req.method !== 'POST') { res.status(405).json({error:'POST required'}); return; }
  // A client that disconnects cancels the provider requests: no more tokens
  // billed. (`req` emits 'close' once its body is read, so watch `res`.)
  const clientGone = new AbortController();
  res.on('close', () => { if (!res.writableFinished) clientGone.abort(new Error('Client disconnected')); });
  let uid: string;
  try {
    const bearer = req.headers.authorization?.match(/^Bearer (.+)$/)?.[1];
    if (!bearer) throw new Error('No token');
    uid = (await getAuth().verifyIdToken(bearer)).uid;
  } catch { res.status(401).json({error:'Sign in to use Aiko.'}); return; }
  if (!isRequestBody(req.body)) { res.status(400).json({error:'messages array is required'}); return; }
  const model = buildModel();
  if (!model) { res.status(503).json({error:'AI provider is not configured.'}); return; }
  // The profile read runs alongside the rate-limit transaction.
  const profileRead = db.doc(`users/${uid}/profiles/${uid}`).get();
  try { await rateLimit(uid,'chat'); } catch {
    profileRead.catch(() => {});
    res.status(429).json({error:'Please try again in a minute.'}); return;
  }
  const profile = (await profileRead).data();
  const messages: Record<string,unknown>[] = [{role:'system',content:systemPromptFor(profile?.base_currency ?? 'THB', req.body.financialContext, req.body.systemContext?.locale)},
    ...req.body.messages.filter(m => ['user','assistant'].includes(m.role)).slice(-10).map(m => ({role:m.role,content:m.content.slice(0,1000)}))];
  res.set({'Content-Type':'text/event-stream','Cache-Control':'no-cache, no-transform'});
  // The first words can take minutes (tool rounds), so the headers go out now
  // and an SSE comment every 15 s keeps the client's idle timeout (45 s) from
  // giving up meanwhile. Clients skip lines that don't start with "data:".
  res.flushHeaders();
  res.write(': ok\n\n');
  const beat = setInterval(() => { if (!res.destroyed) res.write(': ping\n\n'); }, 15000);
  const event = (data:unknown) => { if (!res.destroyed) res.write(`data: ${JSON.stringify(data)}\n\n`); };
  // Errors reach the client as a stable code ({error: 'PROVIDER_DOWN'}); details are logged.
  try {
    await answerChat(uid,messages,model,{delta:text=>event({delta:text}),done:()=>event({done:true}),fail:code=>event({error:code})},clientGone.signal);
  } finally {
    clearInterval(beat);
  }
  res.end();
});

// Large accounts take a while: Firestore and Storage are deleted in parallel,
// and the function may run for 5 minutes.
export const deleteAccount = onCall({timeoutSeconds:300}, async request => {
  if (!request.auth) throw new HttpsError('unauthenticated','Sign in first.');
  if (Date.now()/1000 - Number(request.auth.token.auth_time) > 300) throw new HttpsError('failed-precondition','Sign in again before deleting your account.');
  const uid=request.auth.uid;
  const links=await db.collection('line_links').where('uid','==',uid).get();
  await Promise.all([
    ...links.docs.map(link => link.ref.delete()),
    db.recursiveDelete(db.doc(`users/${uid}`)),
    getStorage().bucket().deleteFiles({prefix:`users/${uid}/`}),
  ]);
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
  const thai = /[฀-๿]/.test(text);
  return (en, th) => (thai ? th : en);
}

const LINE_REPLY_TIMEOUT_MS = 10_000;

interface LineEvent {
  type?: string;
  replyToken?: string;
  source?: {userId?: string};
  message?: {type?: string; text?: unknown};
}

async function handleLineEvent(event: LineEvent, accessToken: string): Promise<void> {
  const lineId=event.source?.userId;
  if (!lineId || !event.replyToken || !['follow','message'].includes(event.type ?? '')) return;
  if (event.type==='message' && event.message?.type!=='text') return;
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
      let text='';
      await answerChat(link.uid,messages,model,{delta:t=>{text+=t;},done:()=>{},fail:()=>{}});
      if(text.trim()) answer=text;
    }
  }
  const reply=await fetch('https://api.line.me/v2/bot/message/reply',{method:'POST',headers:{Authorization:`Bearer ${accessToken}`,'Content-Type':'application/json'},body:JSON.stringify({replyToken:event.replyToken,messages:[{type:'text',text:answer.slice(0,4800)}]}),signal:AbortSignal.timeout(LINE_REPLY_TIMEOUT_MS)});
  if (!reply.ok) logger.warn('LINE reply failed',{status:reply.status,body:(await reply.text().catch(()=>'')).slice(0,300)});
  else await reply.body?.cancel().catch(()=>{});
}

export const lineWebhook = onRequest({secrets:lineSecrets,timeoutSeconds:300},async(req,res)=>{
  const secret=process.env.LINE_CHANNEL_SECRET;
  const accessToken=process.env.LINE_CHANNEL_ACCESS_TOKEN;
  if (!secret || !accessToken || [secret,accessToken].includes('local-unconfigured')) {res.status(503).send('LINE is not configured');return;}
  const expected=createHmac('sha256',secret).update(req.rawBody).digest();
  const supplied=Buffer.from(req.header('x-line-signature') ?? '', 'base64');
  if (supplied.length !== expected.length || !timingSafeEqual(expected,supplied)) {res.status(401).send('Invalid signature');return;}
  // One failing event (deleted account, rate limit, LINE API error) must not
  // fail the batch: LINE would see a 500 and the other events lose their reply.
  for(const event of req.body?.events ?? []) {
    try {
      await handleLineEvent(event,accessToken);
    } catch (error) {
      logger.error('LINE event failed',{type:event?.type,error:error instanceof Error ? error.message : String(error)});
    }
  }
  res.send('ok');
});

// Existing clients can retain OCR and market-feed behavior with a trusted
// provider configured server-side. No provider key is exposed to the app.
async function providerCall(url:string | undefined, key:string | undefined, body:string) {
  if (!url || !key || [url,key].includes('local-unconfigured')) throw new HttpsError('unavailable','This provider is not configured.');
  const response=await fetch(url,{method:'POST',headers:{Authorization:`Bearer ${key}`,'Content-Type':'application/json'},body,signal:AbortSignal.timeout(30000)});
  if(!response.ok) throw new HttpsError('unavailable','Provider request failed.');
  return response.json();
}
// Sized for images: a 5 MiB receipt peaks at roughly 60 MB (about 100 MB from
// an older app's integer array) while it is decoded and re-encoded for the
// provider, so one 512 MiB instance serves 4 at once.
export const ocrScanner=onCall({secrets:['OCR_API_URL','OCR_API_KEY'],memory:'512MiB',timeoutSeconds:60,concurrency:4},async request=>{
  if(!request.auth) throw new HttpsError('unauthenticated','Sign in first.');
  await rateLimit(request.auth.uid,'ocr',10);
  const image=receiptImage(request.data);
  if(!image) throw new HttpsError('invalid-argument','Invalid receipt image.');
  return providerCall(process.env.OCR_API_URL,process.env.OCR_API_KEY,ocrProviderBody(String(request.data.fileName ?? '').slice(0,255),image));
});
export const marketFeed=onCall({secrets:['MARKET_API_URL','MARKET_API_KEY']},async request=>{
  if(!request.auth) throw new HttpsError('unauthenticated','Sign in first.');
  await rateLimit(request.auth.uid,'market');
  const symbol=String(request.data?.symbol ?? '');
  const currency=String(request.data?.currency ?? '');
  if(!/^[A-Za-z0-9.^=-]{1,24}$/.test(symbol)|| !/^[A-Z]{3}$/.test(currency)) throw new HttpsError('invalid-argument','Invalid symbol or currency.');
  return providerCall(process.env.MARKET_API_URL,process.env.MARKET_API_KEY,JSON.stringify({symbol,currency}));
});
