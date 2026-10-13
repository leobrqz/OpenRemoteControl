const byId=id=>document.getElementById(id);
const pageNames={status:'Status',devices:'Dispositivos',network:'Rede',logs:'Log',about:'Sobre'};
let currentPage=pageNames[location.hash.slice(1)]?location.hash.slice(1):'status';
let latestState=null;
let latestUpdate=null;
let updateActionPending=false;
let reconnectTarget=null;
let reconnectTimedOut=false;
let reconnectRunning=false;
function node(tag,className,text){const item=document.createElement(tag);if(className)item.className=className;if(text!==undefined)item.textContent=text;return item;}
function section(title,body){const wrap=node('section','section');if(title){const heading=node('h2','',title);wrap.append(heading);}wrap.append(body);return wrap;}
function panel(){return node('div','card bg-base-100 border border-base-300 shadow-sm p-4');}
function row(label,value,state){const line=node('div','row');line.append(node('div','row-label',label));line.append(node('div','row-value'+(state?' '+state:''),value));return line;}
function showNotice(message){const box=byId('notice');box.textContent=message||'';box.classList.toggle('visible',Boolean(message));}
async function doAction(name,id,button){if(button)button.disabled=true;try{const response=await fetch('/api/action',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action:name,id:id})});const result=await response.json();if(!response.ok)throw new Error(result.error||'Ação recusada.');showNotice('');await refresh();}catch(error){showNotice(error.message);}finally{if(button)button.disabled=false;}}
function makeAction(label,action,id,kind){const variant=kind==='primary'?'btn-success':kind==='danger'?'btn-outline btn-error':'btn-outline btn-neutral';const button=node('button','btn btn-sm '+variant,label);button.onclick=()=>doAction(action,id,button);return button;}
function renderPairing(data){
  const card=node('div','pairing-card');
  const details=node('div','pairing-copy');
  details.append(node('h3','','Conectar pelo QR'));
  details.append(node('p','','Escaneie este código no app Android para parear o celular.'));
  if(!data.running){
    details.append(node('div','empty','Inicie o servidor para gerar um QR.'));
  }else if(data.pairingQrAvailable&&data.pairingExpiresAt){
    const expires=new Date(data.pairingExpiresAt).toLocaleTimeString('pt-BR',{hour:'2-digit',minute:'2-digit'});
    details.append(node('div','device-detail','Válido até '+expires));
    details.append(makeAction('Gerar novo QR','new_pairing_code'));
    const image=document.createElement('img');
    image.className='pairing-qr';
    image.alt='QR para parear o app Android';
    image.src='/api/pairing-qr.svg?expires='+encodeURIComponent(data.pairingExpiresAt);
    card.append(details,image);
    return card;
  }else{
    details.append(node('div','empty','O QR expirou. Gere outro para parear.'));
    details.append(makeAction('Gerar QR','new_pairing_code','', 'primary'));
  }
  card.append(details);
  return card;
}
function renderStatus(data){
  const root=byId('page');root.replaceChildren();
  const statusPanel=panel();
  const statusLine=node('div','status-line');
  statusLine.append(node('span','indicator '+(data.running?'good':'bad')));
  statusLine.append(node('span','',data.running?'Servidor iniciado':'Servidor parado'));
  statusPanel.append(statusLine);
  const rows=node('div','rows');
  rows.append(row('Conexão Wi-Fi',data.running?'Ouvindo em todas as interfaces':'Parada',data.running?'ok':'off'));
  rows.append(row('Controle TCP',data.running?'Porta '+(data.port||47652):'—'));
  rows.append(row('Descoberta automática',data.discoveryRunning?'Ouvindo via UDP':'Parada',data.discoveryRunning?'ok':'off'));
  rows.append(row('Rede local',(data.addresses||[]).join('  ·  ')||'Nenhum endereço local encontrado'));
  rows.append(row('Última tentativa do celular',data.lastConnectionAddress||'Nenhuma conexão recebida'));
  statusPanel.append(rows);
  const actions=node('div','actions');
  actions.append(makeAction(data.running?'Parar servidor':'Iniciar servidor',data.running?'stop':'start'));
  statusPanel.append(actions);
  root.append(section('Estado do servidor',statusPanel));
  const totals=panel();
  const count=(data.requests||[]).length;
  const linked=(data.clients||[]).length;
  const summary=node('div','rows');
  summary.append(row('Pedidos pendentes',String(count)));
  summary.append(row('Celulares autorizados',String(linked)));
  totals.append(summary);
  root.append(section('Dispositivos',totals));
}
function renderDevices(data){
  const root=byId('page');root.replaceChildren();
  root.append(section('Parear celular',renderPairing(data)));
  const requests=panel();
  const waiting=data.requests||[];
  if(!waiting.length)requests.append(node('div','empty','Nenhum pedido aguardando.'));
  for(const item of waiting){
    const line=node('div','device-row');const details=node('div');
    details.append(node('div','device-name',item.name||'Celular'));
    details.append(node('div','device-detail',item.address||''));
    const actions=node('div','actions');
    actions.append(makeAction('Recusar','reject',item.id,'danger'));
    actions.append(makeAction('Aprovar','approve',item.id,'primary'));
    line.append(details,actions);requests.append(line);
  }
  root.append(section('Pedidos de conexão',requests));
  const clients=panel();const paired=data.clients||[];
  if(!paired.length)clients.append(node('div','empty','Nenhum celular autorizado.'));
  for(const item of paired){
    const line=node('div','device-row');const details=node('div');
    details.append(node('div','device-name',item.name||'Celular'));
    details.append(node('div','device-detail',item.connected?'Conectado':'Autorizado'));
    line.append(details,makeAction('Revogar','revoke',item.id));clients.append(line);
  }
  root.append(section('Celulares autorizados',clients));
}
function renderNetwork(data){
  const root=byId('page');root.replaceChildren();
  const connections=panel();const rows=node('div','rows');
  rows.append(row('Controle Wi-Fi','TCP '+(data.port||47652)));
  rows.append(row('Descoberta automática','UDP '+(data.discoveryPort||47653)));
  rows.append(row('Endereços deste PC',(data.addresses||[]).join('  ·  ')||'Nenhum endereço IPv4 local'));
  rows.append(row('Painel neste computador','http://127.0.0.1:'+(data.dashboardPort||47654)+'/'));
  connections.append(rows);root.append(section('Conexões',connections));
  const help=panel();
  help.append(node('div','','Para conectar na mesma rede Wi-Fi, abra o app Android e toque em Solicitar.'));
  help.append(node('p','small','Se a descoberta não encontrar o PC, abra Dispositivos e escaneie o QR com o app Android. O QR usa endereços da rede local; para conectar de outra rede, é necessário um relay ou uma rota pública até o PC.'));
  root.append(section('Conexão local',help));
}
async function renderLogs(){
  const root=byId('page');root.replaceChildren();
  const box=panel();const output=node('pre','log-output','Carregando log…');box.append(output);root.append(section('Atividade do servidor',box));
  try{const response=await fetch('/api/diagnostics',{cache:'no-store'});output.textContent=await response.text();}
  catch(error){output.textContent='Não foi possível carregar o log: '+error.message;}
}
function renderAbout(data){
  const root=byId('page');root.replaceChildren();
  const details=panel();const rows=node('div','rows');
  rows.append(row('Aplicativo','Open Remote Control'));
  rows.append(row('Servidor','Windows'));
  rows.append(row('Licença','GPL-3.0'));
  rows.append(row('Arquivo de log',data.logPath||'—'));
  details.append(rows);root.append(section('Sobre',details));
  root.append(section('Atualizações',renderUpdates()));
}
function updateButton(label,action,kind){
  const button=node('button','btn btn-sm '+(kind==='primary'?'btn-success':'btn-outline btn-neutral'),label);
  const busy=updateActionPending||['checking','downloading','applying'].includes(latestUpdate?.state);
  button.disabled=busy||latestUpdate?.state==='disabled'||!latestUpdate;
  button.onclick=async()=>{
    if(updateActionPending)return;
    updateActionPending=true;renderAbout(latestState);
    const candidate=latestUpdate;
    try{
      const body={action};if(action!=='update_check')body.candidateId=candidate.candidateId;
      const response=await fetch('/api/action',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
      const result=await response.json();if(!response.ok)throw new Error(result.error||'Atualização recusada.');
      if(action==='update_install'){reconnectTarget=candidate.availableVersion;reconnectTimedOut=false;}
      showNotice('');await refresh();
    }catch(error){showNotice(error.message);}
    finally{updateActionPending=false;if(currentPage==='about')renderAbout(latestState);}
  };
  return button;
}
function renderUpdates(){
  const card=panel();const data=latestUpdate;
  if(!data){card.append(node('p','','Carregando atualizações…'));return card;}
  const labels={idle:'Pronto para verificar.',disabled:'Atualizações disponíveis no pacote portátil gerenciado. Baixe a versão atual pelo GitHub.',checking:'Verificando atualizações…',upToDate:'Você está na versão mais recente.',available:'Atualização disponível.',deferred:'Atualização adiada até reiniciar ou verificar novamente.',downloading:'Baixando e validando atualização…',applying:'Atualizando; o servidor será reiniciado',failed:'Não foi possível atualizar.'};
  card.append(row('Versão instalada',data.currentVersion||'—'));
  if(data.availableVersion)card.append(row('Versão disponível',data.availableVersion));
  card.append(node('p','',labels[data.state]||''));
  if(data.notes)card.append(node('pre','whitespace-pre-wrap break-words',data.notes));
  if(data.releaseUrl){
    const link=node('a','link','Ver versão no GitHub');
    try{const url=new URL(data.releaseUrl);if(url.origin==='https://github.com'&&url.pathname.startsWith('/leobrqz/OpenRemoteControl/releases/tag/')){link.href=url.href;link.target='_blank';link.rel='noopener noreferrer';card.append(link);}}catch{}
  }
  if(data.state==='downloading'){
    const progress=node('progress','progress progress-success w-full');progress.max=100;progress.value=data.progressPercent??0;
    progress.setAttribute('aria-label','Download da atualização');card.append(progress,node('span','',String(progress.value)+'%'));
  }
  if(data.error)card.append(node('p','text-error',data.error.message));
  const actions=node('div','actions');
  actions.append(updateButton(data.state==='failed'?'Tentar novamente':'Verificar atualizações','update_check'));
  if(data.state==='available')actions.append(updateButton('Atualizar','update_install','primary'),updateButton('Agora não','update_defer'));
  if(reconnectTimedOut){
    card.append(node('p','text-error','O servidor ainda não respondeu. Tente reconectar ao painel local.'));
    const retry=node('button','btn btn-sm btn-outline btn-neutral','Reconectar ao painel');
    retry.onclick=()=>{reconnectTimedOut=false;void reconnect();};actions.append(retry);
  }
  card.append(actions);return card;
}
async function reconnect(){
  if(reconnectRunning||!reconnectTarget)return;
  reconnectRunning=true;
  const deadline=Date.now()+60000;
  while(Date.now()<deadline){
    const nextPoll=Date.now()+1000;
    try{
      const response=await fetch('/api/updates',{cache:'no-store',signal:AbortSignal.timeout(Math.min(900,deadline-Date.now()))});
      if(response.ok){const data=await response.json();if(data.currentVersion===reconnectTarget){location.reload();return;}
        if(data.state==='failed'){latestUpdate=data;reconnectTarget=null;reconnectRunning=false;if(currentPage==='about')renderAbout(latestState);return;}}
    }catch{}
    const remaining=Math.min(nextPoll,deadline)-Date.now();
    if(remaining>0)await new Promise(resolve=>setTimeout(resolve,remaining));
  }
  reconnectRunning=false;reconnectTimedOut=true;
  if(currentPage==='about')renderAbout(latestState);
}
function render(data){
  latestState=data;byId('pageTitle').textContent=pageNames[currentPage];
  byId('appVersion').textContent=latestUpdate?.currentVersion?'v'+latestUpdate.currentVersion:'';
  if(currentPage==='status')renderStatus(data);
  if(currentPage==='devices')renderDevices(data);
  if(currentPage==='network')renderNetwork(data);
  if(currentPage==='logs')void renderLogs();
  if(currentPage==='about')renderAbout(data);
  showNotice(data.error||'');
}
async function refresh(){if(reconnectRunning)return;try{
  const [response,updates]=await Promise.all([fetch('/api/status',{cache:'no-store'}),fetch('/api/updates',{cache:'no-store'})]);
  if(!response.ok||!updates.ok)throw new Error('Não foi possível ler o estado do servidor.');
  latestUpdate=await updates.json();
  if(latestUpdate.state==='applying'&&!reconnectTimedOut){reconnectTarget=latestUpdate.availableVersion;void reconnect();}
  if(latestUpdate.state==='failed')reconnectTarget=null;
  render(await response.json());
}catch(error){if(reconnectTarget&&!reconnectTimedOut)void reconnect();else showNotice(error.message);}}
function selectPage(){document.querySelectorAll('[data-page]').forEach(item=>item.classList.toggle('active',item.dataset.page===currentPage));if(latestState)render(latestState);}
document.querySelectorAll('[data-page]').forEach(button=>button.addEventListener('click',()=>{currentPage=button.dataset.page;location.hash=currentPage;selectPage();}));
window.addEventListener('hashchange',()=>{currentPage=pageNames[location.hash.slice(1)]?location.hash.slice(1):'status';selectPage();});
selectPage();
byId('copyLogs').onclick=async event=>{const button=event.currentTarget;try{const response=await fetch('/api/diagnostics',{cache:'no-store'});const text=await response.text();await navigator.clipboard.writeText(text);button.textContent='Copiado';setTimeout(()=>button.textContent='Copiar diagnóstico',1600);}catch(error){showNotice('Falha ao copiar diagnóstico: '+error.message);}};
refresh();setInterval(refresh,1000);
