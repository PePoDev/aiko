const {test}=require('node:test');
const assert=require('node:assert/strict');
const {applyCors,receiptImage,ocrProviderBody,MAX_RECEIPT_BYTES}=require('../lib/http');

function response(){
 const r={headers:{},varied:[],statusCode:200,ended:false};
 r.set=(k,v)=>{r.headers[k]=v;return r;};
 r.vary=f=>{r.varied.push(f);return r;};
 r.status=c=>{r.statusCode=c;return r;};
 r.end=()=>{r.ended=true;return r;};
 return r;
}

test('a preflight is answered with a cacheable max-age',()=>{
 const res=response();
 const handled=applyCors({method:'OPTIONS',headers:{origin:'https://aiko.web.app','access-control-request-headers':'authorization,content-type'}},res);
 assert.equal(handled,true);
 assert.equal(res.statusCode,204);
 assert.equal(res.ended,true);
 assert.equal(res.headers['Access-Control-Allow-Origin'],'https://aiko.web.app');
 assert.equal(res.headers['Access-Control-Allow-Methods'],'POST');
 assert.equal(res.headers['Access-Control-Allow-Headers'],'authorization,content-type');
 assert.equal(res.headers['Access-Control-Max-Age'],'3600');
});

test('other requests get the allow-origin header and continue',()=>{
 const res=response();
 assert.equal(applyCors({method:'POST',headers:{origin:'http://localhost:8080'}},res),false);
 assert.equal(res.headers['Access-Control-Allow-Origin'],'http://localhost:8080');
 assert.deepEqual(res.varied,['Origin']);
 assert.equal(res.ended,false);
 const noOrigin=response();
 applyCors({method:'POST',headers:{}},noOrigin);
 assert.equal(noOrigin.headers['Access-Control-Allow-Origin'],'*');
});

test('receipt images arrive as base64 and are size-checked after decoding',()=>{
 const bytes=Buffer.from([0,1,2,253,254,255,137,80,78,71]);
 assert.deepEqual([...receiptImage({imageBase64:bytes.toString('base64')})],[...bytes]);
 assert.equal(receiptImage({imageBase64:''}),null);
 assert.equal(receiptImage({imageBase64:'not base64!'}),null);
 assert.equal(receiptImage({imageBase64:'abc'}),null,'length must be a multiple of 4');
 assert.equal(receiptImage({imageBase64:Buffer.alloc(MAX_RECEIPT_BYTES+1).toString('base64')}),null);
 assert.equal(receiptImage({imageBase64:Buffer.alloc(MAX_RECEIPT_BYTES).toString('base64')}).length,MAX_RECEIPT_BYTES);
 assert.equal(receiptImage(undefined),null);
 assert.equal(receiptImage({}),null);
});

test('integer arrays from older apps are still accepted',()=>{
 assert.deepEqual(receiptImage({imageBytes:[1,2,255]}),[1,2,255]);
 assert.equal(receiptImage({imageBytes:[]}),null);
 assert.equal(receiptImage({imageBytes:[256]}),null);
 assert.equal(receiptImage({imageBytes:[1.5]}),null);
 assert.equal(receiptImage({imageBytes:['1']}),null);
});

test('the OCR provider receives exactly the request it received before',()=>{
 const bytes=[0,17,255];
 const expected=JSON.stringify({fileName:'receipt "1".jpg',imageBytes:bytes});
 assert.equal(ocrProviderBody('receipt "1".jpg',Buffer.from(bytes)),expected);
 assert.equal(ocrProviderBody('receipt "1".jpg',bytes),expected);
});
