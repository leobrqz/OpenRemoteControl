const byId=id=>document.getElementById(id);
const translations={
  'en-US':{
    'title':'Open Remote Control — Server','navigation':'Main navigation','language.label':'Language',
    'page.status':'Status','page.devices':'Devices','page.network':'Network','page.logs':'Logs','page.about':'About',
    'copy':'Copy diagnostics','copy.done':'Copied',
    'section.server':'Server status','section.deviceSummary':'Devices','section.pair':'Pair a phone','section.requests':'Connection requests',
    'section.clients':'Authorized phones','section.connections':'Connections','section.local':'Local connection','section.logs':'Server activity',
    'section.about':'About','section.project':'Project','section.development':'Development','section.updates':'Updates',
    'pair.title':'Connect with QR code','pair.description':'Scan this code in the Android app to pair your phone.',
    'pair.start':'Start the server to create a QR code.','pair.valid':'Valid until {time}','pair.new':'Generate a new QR code',
    'pair.expired':'The QR code has expired. Generate another to pair.','pair.generate':'Generate QR code','pair.alt':'QR code to pair the Android app',
    'status.started':'Server running','status.stopped':'Server stopped','status.wifi':'Wi-Fi connection','status.listening':'Listening on all interfaces',
    'status.off':'Stopped','status.tcp':'TCP control','status.port':'Port {port}','status.discovery':'Automatic discovery','status.udp':'Listening via UDP',
    'status.local':'Local network','status.noAddress':'No local address found','status.lastPhone':'Last phone connection attempt',
    'status.noConnection':'No connection received','status.start':'Start server','status.stop':'Stop server',
    'status.pending':'Pending requests','status.authorized':'Authorized phones',
    'devices.noneWaiting':'No requests waiting.','devices.defaultPhone':'Phone','devices.reject':'Reject','devices.approve':'Approve',
    'devices.noneAuthorized':'No authorized phones.','devices.connected':'Connected','devices.authorized':'Authorized','devices.revoke':'Revoke access',
    'devices.android':'Android {version}',
    'network.wifiControl':'Wi-Fi control','network.tcp':'TCP {port}','network.udp':'UDP {port}','network.addresses':'This PC addresses',
    'network.noIpv4':'No local IPv4 address','network.dashboard':'Dashboard on this PC',
    'network.instruction':'To connect on the same Wi-Fi network, open the Android app and tap Request connection.',
    'network.help':'If discovery does not find the PC, open Devices and scan the QR code with the Android app. The QR code uses local network addresses; to connect from another network, a relay or a public route to the PC is required.',
    'logs.loading':'Loading diagnostics…','logs.error':'Could not load diagnostics. Check that the server is running, then try again.',
    'about.application':'Application','about.server':'Server','about.license':'License','about.log':'Log file',
    'about.website':'Official website','about.personalWebsite':'Personal website','about.personalGithub':'Personal GitHub','about.author':'Leonardo Briquezi aka devpatok',
    'links.github':'GitHub',
    'updates.loading':'Loading updates…','updates.ready':'Ready to check.','updates.disabled':'Updates are provided through the managed portable package. Download the current version from GitHub.',
    'updates.checking':'Checking for updates…','updates.current':'You have the latest version.','updates.available':'Update available.',
    'updates.deferred':'Update postponed until you check again or restart the Windows app.','updates.downloading':'Downloading and validating the update…',
    'updates.applying':'Applying the update. The server will restart.','updates.failed':'The update could not be completed.',
    'updates.installed':'Installed version','updates.availableVersion':'Available version','updates.viewRelease':'View release on GitHub',
    'updates.download':'Update download','updates.retry':'Try again','updates.check':'Check for updates','updates.update':'Update','updates.defer':'Not now',
    'updates.error':'The update could not be completed. Check again or try later.',
    'updates.restartTimeout':'The server has not responded yet. Try reconnecting to the local dashboard.','updates.reconnect':'Reconnect to dashboard',
    'error.action':'The action could not be completed. Try again.','error.updateAction':'The update action could not be completed. Try again.',
    'error.status':'The server reported a problem. Check the server diagnostics.','error.update':'The update could not be completed. Check again or try later.',
    'error.connection':'Could not reach the server. Check that it is running and try again.','error.copy':'Could not copy diagnostics. Check browser clipboard access.',
    'error.logs':'Could not load diagnostics. Check that the server is running, then try again.',
    'error.code.invalid_origin':'This dashboard request was rejected. Open the dashboard from this PC.',
    'error.code.invalid_action':'That action is not available. Refresh the dashboard and try again.',
    'error.code.invalid_request':'The request could not be processed. Refresh the dashboard and try again.',
    'error.code.invalid_client':'This phone is no longer authorized. Pair it again.',
    'error.code.invalid_body':'The request could not be processed. Refresh the dashboard and try again.',
    'error.code.updates_unavailable':'Update information is unavailable. Try again later.',
    'error.code.invalid_update':'The update information could not be verified. Check for updates again.',
    'error.code.unknown_action':'That action is not available. Refresh the dashboard and try again.',
    'error.code.update_busy':'An update is already in progress. Wait for it to finish and try again.',
    'error.code.candidate_changed':'The update changed. Check for updates again before continuing.',
    'error.code.action_failed':'The action could not be completed. Try again.',
    'error.code.no_local_address':'The server could not find a usable local network address.',
    'error.code.port_in_use':'The control port is already in use. Close the other service using it, then restart the server.',
    'error.code.server_failed':'The server could not start. Check the server diagnostics.',
    'error.code.discovery_failed':'Automatic discovery could not start. Check the server diagnostics.',
    'error.code.connection_rejected':'The phone connection was rejected. Check the pairing request.',
    'error.code.connection_failed':'The phone could not connect. Check the network and server diagnostics.',
    'error.code.timeout':'The update check timed out. Check your connection and try again.',
    'error.code.offline':'Could not connect to GitHub. Check your internet connection and try again.',
    'error.code.rate_limited':'GitHub temporarily limited update checks. Try again later.',
    'error.code.missing_asset':'The update file is not available. Try again later.',
    'error.code.invalid_metadata':'The update information could not be verified. Check for updates again.',
    'error.code.checksum':'The update package did not pass its integrity check. Try again.',
    'error.code.insufficient_space':'There is not enough disk space for the update. Free up space and try again.',
    'error.code.unwritable_directory':'The update could not be saved. Check the application folder permissions.',
    'error.code.prepare_failed':'The update could not be prepared. Check the server diagnostics.',
    'error.code.update_failed':'The update failed. Check the server diagnostics and try again.',
    'error.code.network':'Could not connect to the update service. Check your internet connection.',
    'error.code.download':'The update download failed. Try again.',
    'error.code.apply':'The update could not be applied. Check the server diagnostics.',
    'error.code.unavailable':'The requested information is unavailable. Try again later.'
  },
  'pt-BR':{
    'title':'Open Remote Control — Servidor','navigation':'Navegação principal','language.label':'Idioma',
    'page.status':'Status','page.devices':'Dispositivos','page.network':'Rede','page.logs':'Logs','page.about':'Sobre',
    'copy':'Copiar diagnóstico','copy.done':'Copiado',
    'section.server':'Estado do servidor','section.deviceSummary':'Dispositivos','section.pair':'Parear celular','section.requests':'Pedidos de conexão',
    'section.clients':'Celulares autorizados','section.connections':'Conexões','section.local':'Conexão local','section.logs':'Atividade do servidor',
    'section.about':'Sobre','section.project':'Projeto','section.development':'Desenvolvimento','section.updates':'Atualizações',
    'pair.title':'Conectar pelo QR code','pair.description':'Escaneie este código no app Android para parear o celular.',
    'pair.start':'Inicie o servidor para gerar um QR code.','pair.valid':'Válido até {time}','pair.new':'Gerar novo QR code',
    'pair.expired':'O QR code expirou. Gere outro para parear.','pair.generate':'Gerar QR code','pair.alt':'QR code para parear o app Android',
    'status.started':'Servidor iniciado','status.stopped':'Servidor parado','status.wifi':'Conexão Wi-Fi','status.listening':'Ouvindo em todas as interfaces',
    'status.off':'Parada','status.tcp':'Controle TCP','status.port':'Porta {port}','status.discovery':'Descoberta automática','status.udp':'Ouvindo via UDP',
    'status.local':'Rede local','status.noAddress':'Nenhum endereço local encontrado','status.lastPhone':'Última tentativa de conexão do celular',
    'status.noConnection':'Nenhuma conexão recebida','status.start':'Iniciar servidor','status.stop':'Parar servidor',
    'status.pending':'Pedidos pendentes','status.authorized':'Celulares autorizados',
    'devices.noneWaiting':'Nenhum pedido aguardando.','devices.defaultPhone':'Celular','devices.reject':'Recusar','devices.approve':'Aprovar',
    'devices.noneAuthorized':'Nenhum celular autorizado.','devices.connected':'Conectado','devices.authorized':'Autorizado','devices.revoke':'Revogar acesso',
    'devices.android':'Android {version}',
    'network.wifiControl':'Controle Wi-Fi','network.tcp':'TCP {port}','network.udp':'UDP {port}','network.addresses':'Endereços deste PC',
    'network.noIpv4':'Nenhum endereço IPv4 local','network.dashboard':'Painel neste computador',
    'network.instruction':'Para conectar na mesma rede Wi-Fi, abra o app Android e toque em Solicitar conexão.',
    'network.help':'Se a descoberta não encontrar o PC, abra Dispositivos e escaneie o QR code com o app Android. O QR code usa endereços da rede local; para conectar de outra rede, é necessário um servidor intermediário ou uma rota pública até o PC.',
    'logs.loading':'Carregando diagnóstico…','logs.error':'Não foi possível carregar o diagnóstico. Confira se o servidor está ativo e tente novamente.',
    'about.application':'Aplicativo','about.server':'Servidor','about.license':'Licença','about.log':'Arquivo de log',
    'about.website':'Site oficial','about.personalWebsite':'Site pessoal','about.personalGithub':'GitHub pessoal','about.author':'Leonardo Briquezi aka devpatok',
    'links.github':'GitHub',
    'updates.loading':'Carregando atualizações…','updates.ready':'Pronto para verificar.','updates.disabled':'As atualizações são fornecidas pelo pacote portátil gerenciado. Baixe a versão atual pelo GitHub.',
    'updates.checking':'Verificando atualizações…','updates.current':'Você está na versão mais recente.','updates.available':'Atualização disponível.',
    'updates.deferred':'Atualização adiada até verificar novamente ou reiniciar o aplicativo do Windows.','updates.downloading':'Baixando e validando a atualização…',
    'updates.applying':'Aplicando a atualização. O servidor será reiniciado.','updates.failed':'Não foi possível concluir a atualização.',
    'updates.installed':'Versão instalada','updates.availableVersion':'Versão disponível','updates.viewRelease':'Ver versão no GitHub',
    'updates.download':'Download da atualização','updates.retry':'Tentar novamente','updates.check':'Verificar atualizações','updates.update':'Atualizar','updates.defer':'Agora não',
    'updates.error':'Não foi possível concluir a atualização. Verifique novamente ou tente mais tarde.',
    'updates.restartTimeout':'O servidor ainda não respondeu. Tente reconectar ao painel local.','updates.reconnect':'Reconectar ao painel',
    'error.action':'Não foi possível concluir a ação. Tente novamente.','error.updateAction':'Não foi possível concluir a ação de atualização. Tente novamente.',
    'error.status':'O servidor informou um problema. Confira os diagnósticos do servidor.','error.update':'Não foi possível concluir a atualização. Verifique novamente ou tente mais tarde.',
    'error.connection':'Não foi possível acessar o servidor. Confira se ele está ativo e tente novamente.','error.copy':'Não foi possível copiar os diagnósticos. Confira o acesso à área de transferência do navegador.',
    'error.logs':'Não foi possível carregar o diagnóstico. Confira se o servidor está ativo e tente novamente.',
    'error.code.invalid_origin':'A solicitação ao painel foi recusada. Abra o painel neste computador.',
    'error.code.invalid_action':'Essa ação não está disponível. Atualize o painel e tente novamente.',
    'error.code.invalid_request':'Não foi possível processar a solicitação. Atualize o painel e tente novamente.',
    'error.code.invalid_client':'Este celular não está mais autorizado. Faça o pareamento novamente.',
    'error.code.invalid_body':'Não foi possível processar a solicitação. Atualize o painel e tente novamente.',
    'error.code.updates_unavailable':'As informações de atualização estão indisponíveis. Tente mais tarde.',
    'error.code.invalid_update':'Não foi possível validar as informações da atualização. Verifique novamente.',
    'error.code.unknown_action':'Essa ação não está disponível. Atualize o painel e tente novamente.',
    'error.code.update_busy':'Já existe uma atualização em andamento. Aguarde e tente novamente.',
    'error.code.candidate_changed':'A atualização mudou. Verifique novamente antes de continuar.',
    'error.code.action_failed':'Não foi possível concluir a ação. Tente novamente.',
    'error.code.no_local_address':'O servidor não encontrou um endereço de rede local utilizável.',
    'error.code.port_in_use':'A porta de controle já está em uso. Feche o outro serviço que a utiliza e reinicie o servidor.',
    'error.code.server_failed':'Não foi possível iniciar o servidor. Confira os diagnósticos do servidor.',
    'error.code.discovery_failed':'Não foi possível iniciar a descoberta automática. Confira os diagnósticos do servidor.',
    'error.code.connection_rejected':'A conexão do celular foi recusada. Confira o pedido de pareamento.',
    'error.code.connection_failed':'O celular não conseguiu se conectar. Confira a rede e os diagnósticos do servidor.',
    'error.code.timeout':'A verificação da atualização excedeu o tempo limite. Confira a conexão e tente novamente.',
    'error.code.offline':'Não foi possível acessar o GitHub. Confira a conexão com a internet e tente novamente.',
    'error.code.rate_limited':'O GitHub limitou temporariamente as verificações. Tente mais tarde.',
    'error.code.missing_asset':'O arquivo de atualização está indisponível. Tente mais tarde.',
    'error.code.invalid_metadata':'Não foi possível validar as informações da atualização. Verifique novamente.',
    'error.code.checksum':'O pacote de atualização não passou na verificação de integridade. Tente novamente.',
    'error.code.insufficient_space':'Não há espaço em disco suficiente para a atualização. Libere espaço e tente novamente.',
    'error.code.unwritable_directory':'Não foi possível salvar a atualização. Confira as permissões da pasta do aplicativo.',
    'error.code.prepare_failed':'Não foi possível preparar a atualização. Confira os diagnósticos do servidor.',
    'error.code.update_failed':'A atualização falhou. Confira os diagnósticos do servidor e tente novamente.',
    'error.code.network':'Não foi possível acessar o serviço de atualização. Confira a conexão com a internet.',
    'error.code.download':'O download da atualização falhou. Tente novamente.',
    'error.code.apply':'Não foi possível aplicar a atualização. Confira os diagnósticos do servidor.',
    'error.code.unavailable':'As informações solicitadas estão indisponíveis. Tente mais tarde.'
  }
};
const supportedLanguages=['en-US','pt-BR'];
const languageStorageKey='openRemoteDashboardLanguage';
function storedLanguage(){
  try{const value=localStorage.getItem(languageStorageKey);if(supportedLanguages.includes(value))return value;}catch{}
  return 'en-US';
}
let language=storedLanguage();
const t=(key,values={})=>{
  let text=translations[language][key]??translations['en-US'][key]??key;
  for(const [name,value] of Object.entries(values))text=text.replaceAll('{'+name+'}',String(value));
  return text;
};
const localeNumber=(value,options={})=>new Intl.NumberFormat(language,options).format(value);
let currentPage=['status','devices','network','logs','about'].includes(location.hash.slice(1))?location.hash.slice(1):'status';
let latestState=null;
let latestUpdate=null;
let updateActionPending=false;
const pendingActions=new Set();
let reconnectTarget=null;
let reconnectTimedOut=false;
let reconnectRunning=false;
let logsOutput=null;
let logsHeading=null;
let logsLoadState='loading';
let logsFetchPending=false;
let logsGeneration=0;
let activeNotice=null;
let pairingQr=null;
let pairingQrUrl=null;
function node(tag,className,text){
  const item=document.createElement(tag);
  if(className)item.className=className;
  if(text!==undefined)item.textContent=text;
  return item;
}
function section(title,body){
  const wrap=node('section','section');
  if(title)wrap.append(node('h2','',title));
  wrap.append(body);
  return wrap;
}
function panel(){return node('div','card bg-base-100 border border-base-300 shadow-sm p-4');}
function row(label,value,state){
  const line=node('div','row');
  line.append(node('div','row-label',label),node('div','row-value'+(state?' '+state:''),String(value)));
  return line;
}
function showNotice(message,localization=null){
  activeNotice=message?localization:null;
  const box=byId('notice');
  box.textContent=message||'';
  box.classList.toggle('visible',Boolean(message));
}
function errorMessage(code,fallback){
  const key=code&&('error.code.'+code);
  return key&&translations[language][key]?t(key):t(fallback);
}
function showError(code,fallback){showNotice(errorMessage(code,fallback),{code,fallback});}
async function doAction(name,id,button){
  const key=JSON.stringify([name,id??null]);
  if(pendingActions.has(key))return;
  pendingActions.add(key);
  if(button)button.disabled=true;
  try{
    const response=await fetch('/api/action',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action:name,id:id})});
    const result=await response.json();
    if(!response.ok)throw {errorCode:result.errorCode};
    showNotice('');
    await refresh();
  }catch(error){showError(error?.errorCode,'error.action');}
  finally{
    pendingActions.delete(key);
    if(button)button.disabled=false;
    if(latestState)render(latestState,{preserveNotice:true});
  }
}
function makeAction(label,action,id,kind){
  const variant=kind==='primary'?'btn-success':kind==='danger'?'btn-outline btn-error':'btn-outline btn-neutral';
  const button=node('button','btn btn-sm '+variant,label);
  button.disabled=pendingActions.has(JSON.stringify([action,id??null]));
  button.onclick=()=>doAction(action,id,button);
  return button;
}
function renderPairing(data){
  const card=node('div','pairing-card');
  const details=node('div','pairing-copy');
  details.append(node('h3','',t('pair.title')));
  details.append(node('p','',t('pair.description')));
  if(!data.running){
    pairingQr=null;pairingQrUrl=null;
    details.append(node('div','empty',t('pair.start')));
  }else if(data.pairingQrAvailable&&data.pairingExpiresAt){
    const expires=new Date(data.pairingExpiresAt).toLocaleTimeString(language,{hour:'2-digit',minute:'2-digit'});
    details.append(node('div','device-detail',t('pair.valid',{time:expires})));
    details.append(makeAction(t('pair.new'),'new_pairing_code'));
    const qrUrl='/api/pairing-qr.svg?expires='+encodeURIComponent(data.pairingExpiresAt);
    const image=pairingQr&&pairingQrUrl===qrUrl?pairingQr:document.createElement('img');
    image.className='pairing-qr';
    image.alt=t('pair.alt');
    image.src=qrUrl;
    pairingQr=image;pairingQrUrl=qrUrl;
    card.append(details,image);
    return card;
  }else{
    pairingQr=null;pairingQrUrl=null;
    details.append(node('div','empty',t('pair.expired')));
    details.append(makeAction(t('pair.generate'),'new_pairing_code','', 'primary'));
  }
  card.append(details);
  return card;
}
function renderStatus(data){
  const root=byId('page');root.replaceChildren();
  const statusPanel=panel();
  const statusLine=node('div','status-line');
  statusLine.append(node('span','indicator '+(data.running?'good':'bad')));
  statusLine.append(node('span','',t(data.running?'status.started':'status.stopped')));
  statusPanel.append(statusLine);
  const rows=node('div','rows');
  rows.append(row(t('status.wifi'),data.running?t('status.listening'):t('status.off'),data.running?'ok':'off'));
  rows.append(row(t('status.tcp'),data.running?t('status.port',{port:data.port||47652}):'—'));
  rows.append(row(t('status.discovery'),data.discoveryRunning?t('status.udp'):t('status.off'),data.discoveryRunning?'ok':'off'));
  rows.append(row(t('status.local'),(data.addresses||[]).join('  ·  ')||t('status.noAddress')));
  rows.append(row(t('status.lastPhone'),data.lastConnectionAddress||t('status.noConnection')));
  statusPanel.append(rows);
  const actions=node('div','actions');
  actions.append(makeAction(t(data.running?'status.stop':'status.start'),data.running?'stop':'start'));
  statusPanel.append(actions);
  root.append(section(t('section.server'),statusPanel));
  const totals=panel();
  const summary=node('div','rows');
  summary.append(row(t('status.pending'),localeNumber((data.requests||[]).length)));
  summary.append(row(t('status.authorized'),localeNumber((data.clients||[]).length)));
  totals.append(summary);
  root.append(section(t('section.deviceSummary'),totals));
}
function renderDevices(data){
  const root=byId('page');root.replaceChildren();
  root.append(section(t('section.pair'),renderPairing(data)));
  const requests=panel();const waiting=data.requests||[];
  if(!waiting.length)requests.append(node('div','empty',t('devices.noneWaiting')));
  for(const item of waiting){
    const line=node('div','device-row');const details=node('div');
    details.append(node('div','device-name',item.name||t('devices.defaultPhone')));
    details.append(node('div','device-detail',item.address||''));
    const actions=node('div','actions');
    actions.append(makeAction(t('devices.reject'),'reject',item.id,'danger'),makeAction(t('devices.approve'),'approve',item.id,'primary'));
    line.append(details,actions);requests.append(line);
  }
  root.append(section(t('section.requests'),requests));
  const clients=panel();const paired=data.clients||[];
  if(!paired.length)clients.append(node('div','empty',t('devices.noneAuthorized')));
  for(const item of paired){
    const line=node('div','device-row');const details=node('div');
    const name=item.name||t('devices.defaultPhone');
    details.append(node('div','device-name',name));
    const metadata=[item.model&&!name.toLowerCase().includes(item.model.toLowerCase())&&item.model,item.androidVersion&&t('devices.android',{version:item.androidVersion})].filter(Boolean);
    details.append(node('div','device-detail',metadata.length?metadata.join(' · '):item.connected?t('devices.connected'):t('devices.authorized')));
    if(metadata.length)details.append(node('div','device-detail',item.connected?t('devices.connected'):t('devices.authorized')));
    line.append(details,makeAction(t('devices.revoke'),'revoke',item.id));clients.append(line);
  }
  root.append(section(t('section.clients'),clients));
}
function renderNetwork(data){
  const root=byId('page');root.replaceChildren();
  const connections=panel();const rows=node('div','rows');
  rows.append(row(t('network.wifiControl'),t('network.tcp',{port:data.port||47652})));
  rows.append(row(t('network.discovery'),t('network.udp',{port:data.discoveryPort||47653})));
  rows.append(row(t('network.addresses'),(data.addresses||[]).join('  ·  ')||t('network.noIpv4')));
  rows.append(row(t('network.dashboard'),'http://127.0.0.1:'+(data.dashboardPort||47654)+'/'));
  connections.append(rows);root.append(section(t('section.connections'),connections));
  const help=panel();
  help.append(node('div','',t('network.instruction')));
  help.append(node('p','small',t('network.help')));
  root.append(section(t('section.local'),help));
}
function renderLogs({refreshDiagnostics=true}={}){
  const root=byId('page');
  if(!logsOutput){
    root.replaceChildren();
    const box=panel();
    logsLoadState='loading';
    logsOutput=node('pre','log-output',t('logs.loading'));
    logsOutput.setAttribute('aria-label',t('section.logs'));
    box.append(logsOutput);
    const wrapper=section(t('section.logs'),box);
    logsHeading=wrapper.children[0];
    root.append(wrapper);
  }else if(logsHeading){
    logsHeading.textContent=t('section.logs');
    logsOutput.setAttribute('aria-label',t('section.logs'));
    if(logsLoadState==='loading')logsOutput.textContent=t('logs.loading');
    if(logsLoadState==='failed')logsOutput.textContent=t('logs.error');
  }
  if(!refreshDiagnostics||logsFetchPending)return;
  logsFetchPending=true;
  const output=logsOutput;const generation=logsGeneration;
  void (async()=>{
    try{
      const response=await fetch('/api/diagnostics',{cache:'no-store'});
      if(!response.ok)throw new Error('diagnostics unavailable');
      const text=await response.text();
      if(currentPage!=='logs'||generation!==logsGeneration||output!==logsOutput)return;
      logsLoadState='loaded';
      if(output.textContent!==text){
        const followTail=output.scrollTop+output.clientHeight>=output.scrollHeight-1;
        const scrollTop=output.scrollTop;const scrollLeft=output.scrollLeft;
        output.textContent=text;
        output.scrollLeft=scrollLeft;
        output.scrollTop=followTail?output.scrollHeight:scrollTop;
      }
      if(latestState?.error)showError(latestState.errorCode,'error.status');else showNotice('');
    }catch{
      if(currentPage==='logs'&&generation===logsGeneration&&output===logsOutput){
        if(logsLoadState==='loading'){
          logsLoadState='failed';
          output.textContent=t('logs.error');
        }
        if(latestState?.error)showError(latestState.errorCode,'error.status');else showError(null,'error.logs');
      }
    }finally{logsFetchPending=false;}
  })();
}
function renderAbout(data){
  const root=byId('page');root.replaceChildren();
  const details=panel();const rows=node('div','rows');
  rows.append(row(t('about.application'),'Open Remote Control'));
  rows.append(row(t('about.server'),'Windows'));
  rows.append(row(t('about.license'),'GPL-3.0-only'));
  rows.append(row(t('about.log'),data.logPath||'—'));
  details.append(rows);root.append(section(t('section.about'),details));
  const links=panel();
  const projectLinks=node('div','flex flex-wrap gap-4');
  for(const [label,href] of [[t('links.github'),'https://github.com/leobrqz/OpenRemoteControl'],['SourceForge','https://sourceforge.net/projects/openremotecontrol/'],[t('about.website'),'https://openremotecontrol.sourceforge.io/']]){
    const link=node('a','link',label);link.href=href;link.target='_blank';link.rel='noopener noreferrer';projectLinks.append(link);
  }
  links.append(projectLinks);
  root.append(section(t('section.project'),links));
  const author=panel();
  author.append(node('p','mb-3',t('about.author')));
  const authorLinks=node('div','flex flex-wrap gap-4');
  for(const [label,href] of [[t('about.personalWebsite'),'https://leonardobriquezi.me'],[t('about.personalGithub'),'https://github.com/leobrqz']]){
    const link=node('a','link',label);link.href=href;link.target='_blank';link.rel='noopener noreferrer';authorLinks.append(link);
  }
  author.append(authorLinks);
  root.append(section(t('section.development'),author));
  root.append(section(t('section.updates'),renderUpdates()));
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
      const result=await response.json();if(!response.ok)throw {errorCode:result.errorCode};
      if(action==='update_install'){reconnectTarget=candidate.availableVersion;reconnectTimedOut=false;}
      showNotice('');await refresh();
    }catch(error){showError(error?.errorCode,'error.updateAction');}
    finally{updateActionPending=false;if(currentPage==='about')renderAbout(latestState);}
  };
  return button;
}
function renderUpdates(){
  const card=panel();const data=latestUpdate;
  if(!data){card.append(node('p','',t('updates.loading')));return card;}
  const labels={idle:'updates.ready',disabled:'updates.disabled',checking:'updates.checking',upToDate:'updates.current',available:'updates.available',deferred:'updates.deferred',downloading:'updates.downloading',applying:'updates.applying',failed:'updates.failed'};
  card.append(row(t('updates.installed'),data.currentVersion||'—'));
  if(data.availableVersion)card.append(row(t('updates.availableVersion'),data.availableVersion));
  card.append(node('p','',t(labels[data.state]||'updates.ready')));
  if(data.notes)card.append(node('pre','whitespace-pre-wrap break-words',data.notes));
  if(data.releaseUrl){
    const link=node('a','link',t('updates.viewRelease'));
    try{const url=new URL(data.releaseUrl);if(url.origin==='https://github.com'&&url.pathname.startsWith('/leobrqz/OpenRemoteControl/releases/tag/')){link.href=url.href;link.target='_blank';link.rel='noopener noreferrer';card.append(link);}}catch{}
  }
  if(data.state==='downloading'){
    const progress=node('progress','progress progress-success w-full');progress.max=100;progress.value=data.progressPercent??0;
    progress.setAttribute('aria-label',t('updates.download'));card.append(progress,node('span','',localeNumber(progress.value)+'%'));
  }
  if(data.error)card.append(node('p','text-error',errorMessage(data.error.code,'error.update')));
  const actions=node('div','actions');
  actions.append(updateButton(t(data.state==='failed'?'updates.retry':'updates.check'),'update_check'));
  if(data.state==='available')actions.append(updateButton(t('updates.update'),'update_install','primary'),updateButton(t('updates.defer'),'update_defer'));
  if(reconnectTimedOut){
    card.append(node('p','text-error',t('updates.restartTimeout')));
    const retry=node('button','btn btn-sm btn-outline btn-neutral',t('updates.reconnect'));
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
function render(data,{languageChange=false,preserveNotice=false}={}){
  latestState=data;
  byId('pageTitle').textContent=t('page.'+currentPage);
  byId('appVersion').textContent=latestUpdate?.currentVersion?'v'+latestUpdate.currentVersion:'';
  if(currentPage!=='logs'&&logsOutput){logsGeneration++;logsOutput=null;logsHeading=null;logsLoadState='loading';}
  if(currentPage==='status')renderStatus(data);
  if(currentPage==='devices')renderDevices(data);
  if(currentPage==='network')renderNetwork(data);
  if(currentPage==='logs')renderLogs({refreshDiagnostics:!languageChange});
  if(currentPage==='about')renderAbout(data);
  if(data.error)showError(data.errorCode,'error.status');
  else if((languageChange||preserveNotice)&&activeNotice)showError(activeNotice.code,activeNotice.fallback);
  else showNotice('');
}
async function refresh(){
  if(reconnectRunning)return;
  try{
    const [response,updates]=await Promise.all([fetch('/api/status',{cache:'no-store'}),fetch('/api/updates',{cache:'no-store'})]);
    if(!response.ok||!updates.ok)throw new Error('server unavailable');
    latestUpdate=await updates.json();
    if(latestUpdate.state==='applying'&&!reconnectTimedOut){reconnectTarget=latestUpdate.availableVersion;void reconnect();}
    if(latestUpdate.state==='failed')reconnectTarget=null;
    render(await response.json());
  }catch{if(reconnectTarget&&!reconnectTimedOut)void reconnect();else showError(null,'error.connection');}
}
function updateChrome(){
  document.documentElement.lang=language;
  document.title=t('title');
  byId('pageTitle').textContent=t('page.'+currentPage);
  byId('mainNav').setAttribute('aria-label',t('navigation'));
  byId('languageControls').setAttribute('aria-label',t('language.label'));
  document.querySelectorAll('[data-language]').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.language===language)));
  byId('copyLogs').textContent=t('copy');
  byId('copyLogs').setAttribute('aria-label',t('copy'));
  document.querySelectorAll('[data-page]').forEach(item=>{item.textContent=t('page.'+item.dataset.page);});
}
function selectPage(){
  document.querySelectorAll('[data-page]').forEach(item=>item.classList.toggle('active',item.dataset.page===currentPage));
  if(latestState)render(latestState);
}
function changeLanguage(value){
  if(!supportedLanguages.includes(value)||value===language)return;
  let scrollX=0,scrollY=0;
  try{scrollX=window.scrollX;scrollY=window.scrollY;}catch{}
  language=value;
  try{localStorage.setItem(languageStorageKey,language);}catch{}
  updateChrome();
  if(latestState)render(latestState,{languageChange:true});
  try{window.scrollTo(scrollX,scrollY);}catch{}
}
updateChrome();
document.querySelectorAll('[data-language]').forEach(button=>button.addEventListener('click',()=>changeLanguage(button.dataset.language)));
document.querySelectorAll('[data-page]').forEach(button=>button.addEventListener('click',()=>{
  currentPage=button.dataset.page;location.hash=currentPage;selectPage();
}));
window.addEventListener('hashchange',()=>{
  currentPage=['status','devices','network','logs','about'].includes(location.hash.slice(1))?location.hash.slice(1):'status';
  selectPage();
});
selectPage();
byId('copyLogs').onclick=async event=>{
  const button=event.currentTarget;
  try{
    const response=await fetch('/api/diagnostics',{cache:'no-store'});
    if(!response.ok)throw new Error('diagnostics unavailable');
    const text=await response.text();await navigator.clipboard.writeText(text);
    button.textContent=t('copy.done');button.setAttribute('aria-label',t('copy.done'));
    setTimeout(()=>{button.textContent=t('copy');button.setAttribute('aria-label',t('copy'));},1600);
  }catch{showError(null,'error.copy');}
};
refresh();setInterval(refresh,1000);
