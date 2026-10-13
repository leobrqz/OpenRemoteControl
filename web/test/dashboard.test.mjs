import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const script=readFileSync(new URL('../src/dashboard.js',import.meta.url),'utf8');
class Element {
  constructor(tag){this.tag=tag;this.children=[];this.textContent='';this.dataset={};this.classList={toggle(){}};}
  append(...items){this.children.push(...items);}
  replaceChildren(...items){this.children=items;}
  setAttribute(){}
  addEventListener(name,callback){this[name]=callback;}
}
const all=root=>[root,...root.children.flatMap(all)];
const flush=()=>new Promise(resolve=>setImmediate(resolve));
async function dashboard(update){
  const elements=new Map(['page','pageTitle','notice','copyLogs'].map(id=>[id,new Element('div')]));
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
      return {ok:true,json:async()=>({running:true}),text:async()=>''};
    },
  });
  vm.runInContext(script,context);await flush();
  return {context,elements,requests,setUpdate:value=>{current=value;},get reloads(){return reloads;}};
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
