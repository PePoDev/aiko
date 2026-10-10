const {test,after}=require('node:test');
const assert=require('node:assert/strict');
const http=require('node:http');
const {answerChat,answerChunks}=require('../lib/chat');

// A local OpenAI-compatible provider. Each test queues handlers; every request
// is recorded with its parsed JSON body.
const requests=[];
let handlers=[];
const server=http.createServer((req,res)=>{
 let body='';
 req.on('data',chunk=>{body+=chunk;});
 req.on('end',()=>{
  requests.push(JSON.parse(body));
  const handler=handlers.shift();
  if(!handler){res.statusCode=500;res.end('no handler');return;}
  handler(res);
 });
});
const ready=new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
after(()=>{server.closeAllConnections();server.close();});

async function model() {
 await ready;
 return {baseUrl:`http://127.0.0.1:${server.address().port}`,model:'test-model',apiKey:'test-key'};
}
function reset(...queued){requests.length=0;handlers=queued;}
const json=body=>res=>{res.setHeader('Content-Type','application/json');res.end(JSON.stringify(body));};
const completion=message=>json({choices:[{message:{role:'assistant',...message}}]});
const toolCall=(id,name)=>({id,type:'function',function:{name,arguments:'{}'}});
const sse=(...deltas)=>res=>{
 res.setHeader('Content-Type','text/event-stream');
 for(const d of deltas) res.write(`data: ${JSON.stringify({choices:[{delta:{content:d}}]})}\n\n`);
 res.end('data: [DONE]\n\n');
};
function sink(){
 const s={text:'',deltas:0,finished:0,errors:[]};
 s.delta=t=>{s.text+=t;s.deltas++;};
 s.done=()=>{s.finished++;};
 s.fail=code=>{s.errors.push(code);};
 return s;
}
const prompt=()=>[{role:'system',content:'You are Aiko.'},{role:'user',content:'Hello'}];

test('a message that needs no tool is answered with one provider call',async()=>{
 const answer='Hi! '+'Your spending is on track this month. '.repeat(6)+'🎉 Aiko provides estimates, not certified financial advice.';
 reset(completion({content:answer}));
 const s=sink();
 await answerChat('uid',prompt(),await model(),s);
 assert.equal(requests.length,1);
 assert.equal(requests[0].stream,false);
 assert.ok(Array.isArray(requests[0].tools));
 assert.equal(s.text,answer);
 assert.ok(s.deltas>1,'replayed as several deltas');
 assert.equal(s.finished,1);
 assert.deepEqual(s.errors,[]);
});

test('tool calls of one round all run, then the written answer is used',async()=>{
 reset(
  completion({content:null,tool_calls:[toolCall('a','not_a_tool'),toolCall('b','also_not_a_tool')]}),
  completion({content:'Done.'}),
 );
 const s=sink();
 await answerChat('uid',prompt(),await model(),s);
 assert.equal(requests.length,2,'no separate streamed answer');
 const sent=requests[1].messages;
 assert.deepEqual(sent.slice(-3).map(m=>[m.role,m.tool_call_id]),[['assistant',undefined],['tool','a'],['tool','b']]);
 assert.match(sent.at(-1).content,/unknown tool/);
 assert.equal(s.text,'Done.');
 assert.equal(s.finished,1);
});

test('when every round asks for tools the answer is streamed without tools',async()=>{
 const round=()=>completion({content:'',tool_calls:[toolCall('x','not_a_tool')]});
 reset(round(),round(),round(),round(),sse('You spent ','฿4,210.'));
 const s=sink();
 await answerChat('uid',prompt(),await model(),s);
 assert.equal(requests.length,5);
 assert.equal(requests[4].stream,true);
 assert.equal(requests[4].tools,undefined);
 assert.equal(s.text,'You spent ฿4,210.');
 assert.equal(s.finished,1);
});

test('provider failures reach the client as a stable code only',async()=>{
 const failing=res=>{res.statusCode=500;res.end('upstream secret detail');};
 reset(failing,failing);
 const s=sink();
 await answerChat('uid',prompt(),await model(),s);
 assert.equal(requests.length,2);
 assert.deepEqual(s.errors,['PROVIDER_DOWN']);
 assert.equal(s.finished,0);
});

test('a stalled body is cut off by the abort signal, with no further provider call',async()=>{
 reset(res=>{res.setHeader('Content-Type','application/json');res.write('{"choices":');});
 const s=sink();
 const started=Date.now();
 await answerChat('uid',prompt(),await model(),s,AbortSignal.timeout(150));
 assert.ok(Date.now()-started<5000);
 assert.equal(requests.length,1);
 assert.deepEqual(s.errors,['PROVIDER_DOWN']);
});

test('a stream that stalls after some text ends with STREAM_FAILED',async()=>{
 reset(res=>{res.statusCode=503;res.end();},res=>{
  res.setHeader('Content-Type','text/event-stream');
  res.write(`data: ${JSON.stringify({choices:[{delta:{content:'Partial'}}]})}\n\n`);
 });
 const s=sink();
 await answerChat('uid',prompt(),await model(),s,AbortSignal.timeout(300));
 assert.equal(requests.length,2);
 assert.equal(s.text,'Partial');
 assert.deepEqual(s.errors,['STREAM_FAILED']);
});

test('a client that is already gone costs no provider call',async()=>{
 reset();
 const gone=new AbortController();
 gone.abort(new Error('Client disconnected'));
 const s=sink();
 await answerChat('uid',prompt(),await model(),s,gone.signal);
 assert.equal(requests.length,0);
 assert.deepEqual(s.errors,['PROVIDER_DOWN']);
});

test('answer chunks rejoin exactly and never split a surrogate pair',()=>{
 const text='ยอดใช้จ่าย '+'😀'.repeat(60)+' word '.repeat(40);
 const chunks=answerChunks(text,16);
 assert.equal(chunks.join(''),text);
 for(const c of chunks){
  assert.ok(c.length<=16);
  assert.ok(!/[\uD800-\uDBFF]$/.test(c),'no dangling high surrogate');
 }
 assert.deepEqual(answerChunks('short'),['short']);
 assert.deepEqual(answerChunks(''),[]);
});
