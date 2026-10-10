const {test}=require('node:test');
const assert=require('node:assert/strict');
const {systemPromptFor}=require('../lib/chat');
test('the app language picks the reply language and disclaimer',()=>{
 const thai=systemPromptFor('THB',undefined,'th');
 assert.match(thai,/Always reply in Thai/);
 assert.match(thai,/ไม่ใช่คำแนะนำทางการเงิน/);
 const english=systemPromptFor('USD',undefined,'en');
 assert.match(english,/Always reply in English/);
 assert.match(english,/not certified financial advice/);
});
test('without a language (LINE) Aiko mirrors the user and knows both disclaimers',()=>{
 const prompt=systemPromptFor('THB');
 assert.match(prompt,/same language as the user's latest message/);
 assert.match(prompt,/not certified financial advice/);
 assert.match(prompt,/ไม่ใช่คำแนะนำทางการเงิน/);
});
