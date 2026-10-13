import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const script=readFileSync(new URL('../src/dashboard.js',import.meta.url),'utf8');
class Element {
  constructor(tag){this.tag=tag;this.children=[];this._textContent='';this.scrollTop=0;this.scrollLeft=0;this.clientHeight=0;this.scrollHeight=0;this.dataset={};this.classList={toggle(){}};}
  get textContent(){return this._textContent;}
  set textContent(value){this._textContent=String(value);this.scrollHeight=this._textContent.length;}
  append(...items){this.children.push(...items);}
  replaceChildren(...items){this.children=items;}
  setAttribute(){}
  addEventListener(name,callback){this[name]=callback;}
}
const all=root=>[root,...root.children.flatMap(all)];
const flush=()=>new Promise(resolve=>setImmediate(resolve));
async function dashboard(update,config={}){
  const elements=new Map(['page','pageTitle','notice','copyLogs','appVersion'].map(id=>[id,new Element('div')]));
  const pages=['status','devices','network','logs','about'].map(page=>Object.assign(new Element('button'),{dataset:{page}}));
  const requests=[];let now=0,reloads=0,current=update;
  const context=vm.createContext({
    document:{createElement:tag=>new Element(tag),getElementById:id=>elements.get(id),querySelectorAll:()=>pages},
    location:{hash:'#about',reload:()=>reloads++},window:{addEventListener(){}},
    navigator:{clipboard:{writeText:async()=>{}}},URL,AbortSignal,
    Date:{now:()=>now},setTimeout:callback=>{now+=1000;queueMicrotask(callback);},setInterval(){},
    fetch:async(url,options)=>{
      requests.push({url,options});
      if(url==='/api/action')return {ok:true,json:async()=>({ok:true})};
      if(url==='/api/updates')return {ok:true,json:async()=>current};
      if(url==='/api/diagnostics'&&config.diagnostics)return config.diagnostics(requests.filter(item=>item.url==='/api/diagnostics').length);
      return {ok:true,json:async()=>({running:true}),text:async()=>''};
    },
  });
  vm.runInContext(script,context);await flush();
  return {context,elements,requests,pages,setUpdate:value=>{current=value;},get reloads(){return reloads;}};
}
const candidate={state:'available',currentVersion:'0.3.0',availableVersion:'0.3.1',candidateId:'opaque',notes:'<img src=x onerror=alert(1)>',releaseUrl:'https://github.com/leobrqz/OpenRemoteControl/releases/tag/v0.3.1'};
test('initial #about shows safe plain notes and sends only an opaque candidate on approval',async()=>{
  const app=await dashboard(candidate);
  const nodes=all(app.elements.get('page'));
  assert.equal(app.elements.get('pageTitle').textContent,'Sobre');
  assert.ok(nodes.some(item=>item.tag==='pre'&&item.textContent===candidate.notes));
  assert.ok(!nodes.some(item=>item.tag==='img'));
  const button=nodes.find(item=>item.textContent==='Agora não');await button.onclick();
  const action=app.requests.find(item=>item.url==='/api/action');
  assert.deepEqual(JSON.parse(action.options.body),{action:'update_defer',candidateId:'opaque'});
});
test('failure retries a check, download disables controls and progress is rendered',async()=>{
  const failed=await dashboard({...candidate,state:'failed',error:{message:'Libere espaço.'}});
  const retry=all(failed.elements.get('page')).find(item=>item.textContent==='Tentar novamente');await retry.onclick();
  assert.deepEqual(JSON.parse(failed.requests.find(item=>item.url==='/api/action').options.body),{action:'update_check'});
  const busy=await dashboard({...candidate,state:'downloading',progressPercent:42});
  const nodes=all(busy.elements.get('page'));
  assert.ok(nodes.filter(item=>item.tag==='button').every(item=>item.disabled));
  assert.equal(nodes.find(item=>item.tag==='progress').value,42);
});
test('restart reloads only when the approved target version becomes active',async()=>{
  const app=await dashboard({...candidate,state:'applying'});
  assert.equal(app.reloads,0);
  app.setUpdate({...candidate,state:'upToDate',currentVersion:'0.3.1'});
  await vm.runInContext('reconnectTimedOut=false; reconnect()',app.context);
  assert.equal(app.reloads,1);
});
test('restart timeout offers a reconnect button',async()=>{
  const app=await dashboard({...candidate,state:'applying'});
  await flush();
  assert.equal(app.reloads,0);
  assert.ok(all(app.elements.get('page')).some(item=>item.textContent==='Reconectar ao painel'));
  const requests=app.requests.length;
  await vm.runInContext('refresh()',app.context);
  assert.equal(app.requests.length,requests+2,'refresh must wait for the reconnect button after timeout');
});
test('dashboard scripts remain external with no executable notes or inline handlers',()=>{
  const html=readFileSync(new URL('../src/index.html',import.meta.url),'utf8');
  assert.equal((html.match(/<script/g)||[]).length,1);
  assert.match(html,/<script src="\/assets\/dashboard.js" defer><\/script>/);
  assert.doesNotMatch(html,/\son\w+=/i);
  assert.doesNotMatch(script,/innerHTML|eval\(|new Function/);
});
test('about page links to both project homes in safe new tabs',async()=>{
  const app=await dashboard(candidate);
  const links=all(app.elements.get('page')).filter(item=>item.tag==='a'&&['https://github.com/leobrqz/OpenRemoteControl','https://sourceforge.net/projects/openremotecontrol/'].includes(item.href));
  assert.deepEqual(links.map(item=>[item.textContent,item.href,item.target,item.rel]),[
    ['GitHub','https://github.com/leobrqz/OpenRemoteControl','_blank','noopener noreferrer'],
    ['SourceForge','https://sourceforge.net/projects/openremotecontrol/','_blank','noopener noreferrer'],
  ]);
});
test('authorized devices show name and concise model and Android metadata',async()=>{
  const app=await dashboard(candidate);
  vm.runInContext("currentPage='devices';render({running:true,clients:[{id:'a',name:'Pixel',model:'Pixel 8',androidVersion:'14',connected:true},{id:'b',name:'Legacy',connected:false}]})",app.context);
  const text=all(app.elements.get('page')).map(item=>item.textContent);
  assert.ok(text.includes('Pixel'));
  assert.ok(text.includes('Pixel 8 · Android 14'));
  assert.ok(text.includes('Conectado'));
  assert.ok(text.includes('Legacy'));
  assert.ok(text.includes('Autorizado'));
});
test('log refresh retains its panel and reading position while following the tail',async()=>{
  const lines=['first log','updated log','final log'];
  const app=await dashboard(candidate,{diagnostics:async count=>({ok:true,text:async()=>lines[Math.min(count-1,lines.length-1)]})});
  app.pages.find(item=>item.dataset.page==='logs').click();await flush();
  const output=all(app.elements.get('page')).find(item=>item.tag==='pre');
  assert.equal(output.textContent,'first log');
  output.clientHeight=3;output.scrollTop=2;output.scrollLeft=4;
  await vm.runInContext('refresh()',app.context);await flush();
  assert.equal(all(app.elements.get('page')).find(item=>item.tag==='pre'),output);
  assert.equal(output.textContent,'updated log');
  assert.equal(output.scrollTop,2,'reader away from bottom keeps vertical position');
  assert.equal(output.scrollLeft,4,'reader keeps horizontal position');
  output.scrollHeight=output.textContent.length;output.scrollTop=output.scrollHeight-output.clientHeight;
  await vm.runInContext('refresh()',app.context);await flush();
  assert.equal(all(app.elements.get('page')).find(item=>item.tag==='pre'),output);
  assert.equal(output.scrollTop,output.scrollHeight,'reader at bottom follows new lines');
});
test('late diagnostics from a previous Logs visit cannot update a new visit',async()=>{
  let finish;
  const app=await dashboard(candidate,{diagnostics:()=>new Promise(resolve=>{finish=()=>resolve({ok:true,text:async()=>'stale log'});})});
  app.pages.find(item=>item.dataset.page==='logs').click();
  const firstOutput=all(app.elements.get('page')).find(item=>item.tag==='pre');
  app.pages.find(item=>item.dataset.page==='devices').click();
  app.pages.find(item=>item.dataset.page==='logs').click();
  const newOutput=all(app.elements.get('page')).find(item=>item.tag==='pre');
  assert.notEqual(newOutput,firstOutput);
  finish();await flush();
  assert.equal(newOutput.textContent,'Carregando log…');
  assert.equal(app.requests.filter(item=>item.url==='/api/diagnostics').length,1,'diagnostic requests do not overlap');
});
test('diagnostic failure preserves loaded text and shows a retry hint',async()=>{
  let fail=false;
  const app=await dashboard(candidate,{diagnostics:async()=>{if(fail)throw new Error('offline');return {ok:true,text:async()=>'loaded log'};}});
  app.pages.find(item=>item.dataset.page==='logs').click();await flush();
  const output=all(app.elements.get('page')).find(item=>item.tag==='pre');output.scrollTop=3;
  fail=true;await vm.runInContext('refresh()',app.context);await flush();
  assert.equal(output.textContent,'loaded log');
  assert.equal(output.scrollTop,3);
  assert.match(app.elements.get('notice').textContent,/offline.*tente novamente/i);
});
