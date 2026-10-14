import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const script=readFileSync(new URL('../src/dashboard.js',import.meta.url),'utf8');
class Element {
  constructor(tag){
    this.tag=tag;this.children=[];this._textContent='';this.scrollTop=0;this.scrollLeft=0;
    this.clientHeight=0;this.scrollHeight=0;this.dataset={};this.attributes={};this.listeners={};
    this.classList={toggle(){}};
  }
  get textContent(){return this._textContent;}
  set textContent(value){this._textContent=String(value);this.scrollHeight=this._textContent.length;}
  append(...items){this.children.push(...items);}
  replaceChildren(...items){this.children=items;}
  setAttribute(name,value){this.attributes[name]=String(value);}
  addEventListener(name,callback){(this.listeners[name]??=[]).push(callback);}
  dispatch(name,event={}){for(const callback of this.listeners[name]||[])callback({currentTarget:this,...event});}
  click(){if(this.onclick)this.onclick({currentTarget:this});this.dispatch('click');}
}
const all=root=>[root,...root.children.flatMap(all)];
const flush=()=>new Promise(resolve=>setImmediate(resolve));

async function dashboard(update,config={}){
  const elements=new Map(['page','pageTitle','notice','copyLogs','appVersion','mainNav','languageLabel','languageSelect'].map(id=>[id,new Element(id)]));
  const pages=['status','devices','network','logs','about'].map(page=>Object.assign(new Element('button'),{dataset:{page}}));
  const requests=[];let reloads=0,current=update,now=0;
  class FakeDate extends Date{static now(){return now;}}
  const storage=config.storage??new Map();
  const location={hash:config.hash??'#about',reload:()=>reloads++};
  const window={scrollX:0,scrollY:0,addEventListener(){},scrollTo:(x,y)=>{window.scrollX=x;window.scrollY=y;}};
  const context=vm.createContext({
    document:{documentElement:{lang:''},title:'',createElement:tag=>new Element(tag),getElementById:id=>elements.get(id),querySelectorAll:selector=>selector==='[data-page]'?pages:[]},
    location,window,
    localStorage:{getItem:key=>storage.get(key)??null,setItem:(key,value)=>storage.set(key,value)},
    navigator:{clipboard:{writeText:async()=>{}}},
    URL,AbortSignal,Intl,Date:FakeDate,
    setTimeout:callback=>{now+=1000;queueMicrotask(callback);},setInterval(){},
    fetch:async(url,options)=>{
      requests.push({url,options});
      if(url==='/api/action')return config.actionResponse?.()??{ok:true,json:async()=>({ok:true})};
      if(url==='/api/updates')return {ok:true,json:async()=>current};
      if(url==='/api/status')return {ok:true,json:async()=>config.status??{running:true,discoveryRunning:true,port:47652,discoveryPort:47653,dashboardPort:47654,addresses:['192.168.1.20'],requests:[],clients:[]}};
      if(url==='/api/diagnostics'&&config.diagnostics)return config.diagnostics(requests.filter(item=>item.url==='/api/diagnostics').length);
      if(url==='/api/diagnostics')return {ok:true,text:async()=>'original diagnostic line'};
      return {ok:true,json:async()=>({}),text:async()=>''};
    },
  });
  vm.runInContext(script,context);await flush();
  return {context,elements,pages,requests,storage,location,window,setUpdate:value=>{current=value;},get reloads(){return reloads;}};
}
function setLanguage(app,value){
  const select=app.elements.get('languageSelect');
  select.value=value;select.dispatch('change');
}
function pageText(app){return all(app.elements.get('page')).map(item=>item.textContent);}
const candidate={state:'available',currentVersion:'0.3.0',availableVersion:'0.3.1',candidateId:'opaque',notes:'<img src=x onerror=alert(1)>',releaseUrl:'https://github.com/leobrqz/OpenRemoteControl/releases/tag/v0.3.1'};

test('defaults to en-US and renders the static shell in English',async()=>{
  const app=await dashboard(candidate);
  assert.equal(app.context.document.documentElement.lang,'en-US');
  assert.equal(app.context.document.title,'Open Remote Control — Server');
  assert.equal(app.elements.get('languageSelect').value,'en-US');
  assert.equal(app.elements.get('languageLabel').textContent,'Language');
  assert.equal(app.elements.get('pageTitle').textContent,'About');
  assert.equal(app.elements.get('mainNav').attributes['aria-label'],'Main navigation');
  assert.equal(app.elements.get('copyLogs').textContent,'Copy diagnostics');
});

test('only en-US and pt-BR catalogs exist and every entry is readable and paired',async()=>{
  const app=await dashboard(candidate);
  const catalogs=vm.runInContext('translations',app.context);
  assert.deepEqual(Array.from(vm.runInContext('supportedLanguages',app.context)),['en-US','pt-BR']);
  const english=Object.keys(catalogs['en-US']).sort();
  assert.deepEqual(Object.keys(catalogs['pt-BR']).sort(),english);
  for(const locale of ['en-US','pt-BR']){
    for(const [key,value] of Object.entries(catalogs[locale])){
      assert.equal(typeof value,'string',locale+':'+key+' must be text');
      assert.ok(value.trim(),locale+':'+key+' must not be blank');
      assert.doesNotMatch(value,/Ã.|Â.|â€|ï¿½/,locale+':'+key+' has broken encoding');
      assert.notEqual(value,key,locale+':'+key+' must be translated');
    }
  }
});

test('language changes immediately without an action and keeps page, hash, QR and scroll',async()=>{
  const app=await dashboard(candidate);
  const state={running:true,discoveryRunning:true,port:47652,discoveryPort:47653,dashboardPort:47654,addresses:['192.168.1.20'],requests:[],clients:[],pairingQrAvailable:true,pairingExpiresAt:'2030-01-02T03:04:00Z'};
  vm.runInContext('currentPage="devices";location.hash="#devices";render('+JSON.stringify(state)+')',app.context);
  const before=all(app.elements.get('page')).find(item=>item.tag==='img');
  const qrSource=before.src;
  app.window.scrollTo(0,275);
  const requestCountBefore=app.requests.length;
  setLanguage(app,'pt-BR');
  assert.equal(app.elements.get('pageTitle').textContent,'Dispositivos');
  assert.equal(app.location.hash,'#devices');
  assert.equal(app.context.document.documentElement.lang,'pt-BR');
  assert.equal(app.elements.get('languageLabel').textContent,'Idioma');
  assert.equal(app.window.scrollY,275);
  const after=all(app.elements.get('page')).find(item=>item.tag==='img');
  assert.equal(after,before,'the current QR node is reused');
  assert.equal(after.src,qrSource);
  assert.equal(app.requests.length,requestCountBefore,'language changes do not call the server');
});

test('language choice persists independently in browser storage',async()=>{
  const storage=new Map();
  const first=await dashboard(candidate,{storage});
  setLanguage(first,'pt-BR');
  assert.equal(storage.get('openRemoteDashboardLanguage'),'pt-BR');
  const next=await dashboard(candidate,{storage});
  assert.equal(next.context.document.documentElement.lang,'pt-BR');
  assert.equal(next.elements.get('languageLabel').textContent,'Idioma');
  assert.equal(next.elements.get('pageTitle').textContent,'Sobre');
});

test('switching while approving a phone retains the pending action and prevents duplicate approval',async()=>{
  let finish;
  const reply=new Promise(resolve=>{finish=resolve;});
  const app=await dashboard(candidate,{
    hash:'#devices',
    status:{running:true,requests:[{id:'phone-1',name:'Meu celular'}],clients:[]},
    actionResponse:()=>reply,
  });
  const approve=all(app.elements.get('page')).find(item=>item.textContent==='Approve');
  const operation=approve.onclick();
  assert.equal(approve.disabled,true);
  setLanguage(app,'pt-BR');
  const translated=all(app.elements.get('page')).find(item=>item.textContent==='Aprovar');
  assert.equal(translated.disabled,true);
  await translated.onclick();
  assert.equal(app.requests.filter(item=>item.url==='/api/action').length,1);
  finish({ok:true,json:async()=>({ok:true})});
  await operation;
  assert.equal(all(app.elements.get('page')).find(item=>item.textContent==='Aprovar').disabled,false);
});

test('dates and numeric counts follow the selected locale',async()=>{
  const app=await dashboard(candidate);
  const state={running:true,discoveryRunning:true,port:47652,discoveryPort:47653,dashboardPort:47654,addresses:[],requests:Array(1234).fill({}),clients:[]};
  vm.runInContext('currentPage="status";render('+JSON.stringify(state)+')',app.context);
  assert.ok(pageText(app).some(text=>text.includes('1,234')));
  setLanguage(app,'pt-BR');
  assert.ok(pageText(app).some(text=>text.includes('1.234')));

  const pairing={running:true,pairingQrAvailable:true,pairingExpiresAt:'2030-01-02T15:04:00Z'};
  vm.runInContext('currentPage="devices";render('+JSON.stringify(pairing)+')',app.context);
  const portugueseTime=new Date(pairing.pairingExpiresAt).toLocaleTimeString('pt-BR',{hour:'2-digit',minute:'2-digit'});
  assert.ok(pageText(app).some(text=>text.includes(portugueseTime)));
  setLanguage(app,'en-US');
  const englishTime=new Date(pairing.pairingExpiresAt).toLocaleTimeString('en-US',{hour:'2-digit',minute:'2-digit'});
  assert.ok(pageText(app).some(text=>text.includes(englishTime)));
});

test('live translations cover status, devices, network and updates but preserve user values and release notes',async()=>{
  const app=await dashboard({...candidate,notes:'Keep this release note exactly as published.'});
  const state={running:true,discoveryRunning:true,port:47652,discoveryPort:47653,dashboardPort:47654,addresses:['192.168.1.20'],lastConnectionAddress:'192.168.1.45',requests:[],clients:[{id:'a',name:'Pixel',model:'Pixel 8',androidVersion:'14',connected:true}]};
  vm.runInContext('currentPage="status";render('+JSON.stringify(state)+')',app.context);
  assert.ok(pageText(app).includes('Listening on all interfaces'));
  setLanguage(app,'pt-BR');
  assert.ok(pageText(app).includes('Ouvindo em todas as interfaces'));
  assert.ok(pageText(app).includes('192.168.1.20'));
  assert.ok(pageText(app).some(text=>text.includes('47652')));
  vm.runInContext('currentPage="devices";render('+JSON.stringify(state)+')',app.context);
  assert.ok(pageText(app).includes('Pixel 8 · Android 14'));
  vm.runInContext('currentPage="network";render('+JSON.stringify(state)+')',app.context);
  assert.ok(pageText(app).includes('192.168.1.20'));
  assert.ok(pageText(app).some(text=>text.includes('toque em Solicitar conexão')));
  setLanguage(app,'en-US');
  assert.ok(pageText(app).some(text=>text.includes('tap Request connection')));
  setLanguage(app,'pt-BR');
  vm.runInContext('currentPage="about";render('+JSON.stringify(state)+')',app.context);
  assert.ok(pageText(app).includes('Keep this release note exactly as published.'));
  assert.ok(pageText(app).includes('Atualizar'));
  assert.ok(pageText(app).includes('Versão instalada'));
});

test('switching language on Logs retains node, diagnostics and scroll without another request',async()=>{
  const app=await dashboard(candidate);
  app.pages.find(item=>item.dataset.page==='logs').click();
  await flush();
  const output=all(app.elements.get('page')).find(item=>item.tag==='pre');
  assert.equal(output.textContent,'original diagnostic line');
  output.scrollTop=4;output.scrollLeft=2;output.clientHeight=3;
  const calls=app.requests.filter(item=>item.url==='/api/diagnostics').length;
  setLanguage(app,'pt-BR');
  const current=all(app.elements.get('page')).find(item=>item.tag==='pre');
  assert.equal(current,output);
  assert.equal(current.textContent,'original diagnostic line');
  assert.equal(current.scrollTop,4);
  assert.equal(current.scrollLeft,2);
  assert.equal(app.requests.filter(item=>item.url==='/api/diagnostics').length,calls);
});

test('incremental log polling preserves the node and scroll, following the tail only when already at the bottom',async()=>{
  const lines=['first diagnostic snapshot','updated diagnostic snapshot','final diagnostic snapshot'];
  const app=await dashboard(candidate,{diagnostics:count=>({ok:true,text:async()=>lines[Math.min(count-1,lines.length-1)]})});
  app.pages.find(item=>item.dataset.page==='logs').click();await flush();
  const output=all(app.elements.get('page')).find(item=>item.tag==='pre');
  assert.equal(output.textContent,lines[0]);
  output.clientHeight=4;output.scrollTop=3;output.scrollLeft=2;
  await vm.runInContext('refresh()',app.context);await flush();
  assert.equal(all(app.elements.get('page')).find(item=>item.tag==='pre'),output);
  assert.equal(output.textContent,lines[1]);
  assert.equal(output.scrollTop,3,'reader position is retained away from the tail');
  assert.equal(output.scrollLeft,2,'horizontal position is retained');

  output.scrollTop=output.scrollHeight-output.clientHeight;
  await vm.runInContext('refresh()',app.context);await flush();
  assert.equal(all(app.elements.get('page')).find(item=>item.tag==='pre'),output);
  assert.equal(output.textContent,lines[2]);
  assert.equal(output.scrollTop,output.scrollHeight,'reader follows new output only when already at the bottom');
});

test('a stale diagnostics response after navigation cannot replace the reopened log panel',async()=>{
  let finish;
  const app=await dashboard(candidate,{diagnostics:()=>new Promise(resolve=>{finish=resolve;})});
  app.pages.find(item=>item.dataset.page==='logs').click();
  const oldOutput=all(app.elements.get('page')).find(item=>item.tag==='pre');
  app.pages.find(item=>item.dataset.page==='devices').click();
  app.pages.find(item=>item.dataset.page==='logs').click();
  const currentOutput=all(app.elements.get('page')).find(item=>item.tag==='pre');
  assert.notEqual(currentOutput,oldOutput);
  finish({ok:true,text:async()=>'late response from previous panel'});
  await flush();await flush();
  assert.equal(currentOutput.textContent,'Loading diagnostics…');
  assert.equal(app.requests.filter(item=>item.url==='/api/diagnostics').length,1);
});

test('a later diagnostics failure preserves loaded log text and offers a retry hint',async()=>{
  const app=await dashboard(candidate,{diagnostics:count=>count===1
    ?{ok:true,text:async()=>'previously loaded diagnostic'}
    :{ok:false,text:async()=>''}});
  app.pages.find(item=>item.dataset.page==='logs').click();await flush();
  const output=all(app.elements.get('page')).find(item=>item.tag==='pre');
  output.scrollTop=5;
  await vm.runInContext('refresh()',app.context);await flush();
  assert.equal(output.textContent,'previously loaded diagnostic');
  assert.equal(output.scrollTop,5);
  assert.match(app.elements.get('notice').textContent,/Could not load diagnostics.*try again/i);
});

test('stable error codes use localized copy; unknown raw errors use translated fallback',async()=>{
  const app=await dashboard(candidate,{status:{running:false,error:'an English raw error',errorCode:'server_failed'}});
  await vm.runInContext('refresh()',app.context);
  assert.match(app.elements.get('notice').textContent,/server could not start/i);
  assert.doesNotMatch(app.elements.get('notice').textContent,/an English raw error/);
  setLanguage(app,'pt-BR');
  assert.match(app.elements.get('notice').textContent,/Não foi possível iniciar o servidor/);

  const unknown=await dashboard(candidate,{actionResponse:()=>({ok:false,json:async()=>({error:'private raw diagnostic',errorCode:'future_code'})})});
  vm.runInContext('currentPage="devices";render({running:true,requests:[{id:"req",name:"Phone",address:"192.168.1.5"}],clients:[]})',unknown.context);
  const approve=all(unknown.elements.get('page')).find(item=>item.textContent==='Approve');
  await approve.onclick();
  assert.equal(unknown.elements.get('notice').textContent,'The action could not be completed. Try again.');
  assert.doesNotMatch(unknown.elements.get('notice').textContent,/private raw diagnostic/);
  setLanguage(unknown,'pt-BR');
  assert.equal(unknown.elements.get('notice').textContent,'Não foi possível concluir a ação. Tente novamente.');
});

test('diagnostic text is unchanged and copy controls are localized',async()=>{
  const app=await dashboard(candidate,{diagnostics:async()=>({ok:true,text:async()=>'ERROR: unchanged source diagnostic'})});
  app.pages.find(item=>item.dataset.page==='logs').click();await flush();
  const output=all(app.elements.get('page')).find(item=>item.tag==='pre');
  assert.equal(output.textContent,'ERROR: unchanged source diagnostic');
  setLanguage(app,'pt-BR');
  assert.equal(output.textContent,'ERROR: unchanged source diagnostic');
  assert.equal(app.elements.get('copyLogs').textContent,'Copiar diagnóstico');
  assert.equal(app.elements.get('copyLogs').attributes['aria-label'],'Copiar diagnóstico');
});

test('about page keeps safe official project and author links',async()=>{
  const app=await dashboard(candidate);
  const nodes=all(app.elements.get('page'));
  const links=nodes.filter(item=>item.tag==='a'&&['https://github.com/leobrqz/OpenRemoteControl','https://sourceforge.net/projects/openremotecontrol/','https://openremotecontrol.sourceforge.io/','https://leonardobriquezi.me','https://github.com/leobrqz'].includes(item.href));
  assert.deepEqual(links.map(item=>[item.textContent,item.href,item.target,item.rel]),[
    ['GitHub','https://github.com/leobrqz/OpenRemoteControl','_blank','noopener noreferrer'],
    ['SourceForge','https://sourceforge.net/projects/openremotecontrol/','_blank','noopener noreferrer'],
    ['Official website','https://openremotecontrol.sourceforge.io/','_blank','noopener noreferrer'],
    ['Personal website','https://leonardobriquezi.me','_blank','noopener noreferrer'],
    ['Personal GitHub','https://github.com/leobrqz','_blank','noopener noreferrer'],
  ]);
  assert.ok(nodes.some(item=>item.textContent==='Leonardo Briquezi aka devpatok'));
});

test('HTML keeps external JavaScript and exposes the language control in the sidebar',()=>{
  const html=readFileSync(new URL('../src/index.html',import.meta.url),'utf8');
  assert.match(html,/<html lang="en-US">/);
  assert.match(html,/<script src="\/assets\/dashboard.js" defer><\/script>/);
  assert.equal((html.match(/<script/g)||[]).length,1);
  assert.doesNotMatch(html,/\son\w+=/i);
  assert.doesNotMatch(script,/innerHTML|eval\(|new Function/);
  assert.match(html,/<label id="languageLabel" for="languageSelect">/);
  assert.match(html,/<select id="languageSelect" aria-label="Language">/);
  assert.match(html,/<option value="en-US">English<\/option>/);
  assert.match(html,/<option value="pt-BR">Português \(Brasil\)<\/option>/);
  const css=readFileSync(new URL('../src/dashboard.input.css',import.meta.url),'utf8');
  assert.doesNotMatch(css,/\.side-foot\{display:none/);
});

test('update actions use an opaque candidate and only reconnect after the target version is active',async()=>{
  const app=await dashboard(candidate);
  const nodes=all(app.elements.get('page'));
  assert.ok(nodes.some(item=>item.tag==='pre'&&item.textContent===candidate.notes));
  assert.ok(!nodes.some(item=>item.tag==='img'));
  const defer=nodes.find(item=>item.textContent==='Not now');await defer.onclick();
  assert.deepEqual(JSON.parse(app.requests.find(item=>item.url==='/api/action').options.body),{action:'update_defer',candidateId:'opaque'});

  const applying=await dashboard({...candidate,state:'applying'});
  assert.equal(applying.reloads,0);
  applying.setUpdate({...candidate,state:'upToDate',currentVersion:'0.3.1'});
  await vm.runInContext('reconnectTimedOut=false; reconnect()',applying.context);
  assert.equal(applying.reloads,1);
});
