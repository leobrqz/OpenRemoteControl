const byId=id=>document.getElementById(id);
const translations={
  'en-US':{
    'title':'Open Remote Control — Server','app.kicker':'WINDOWS SERVER','navigation':'Main navigation','language.label':'Language',
    'page.status':'Status','page.devices':'Devices','page.network':'Network','page.logs':'Logs','page.updates':'Updates','page.about':'About',
    'page.statusSubtitle':'Your Windows server at a glance.','page.devicesSubtitle':'Pair phones and manage who can control this PC.','page.networkSubtitle':'Local addresses and connection details for this PC.','page.logsSubtitle':'Recent log entries and where the files are stored.','page.updatesSubtitle':'See what is new and choose when to install it.','page.aboutSubtitle':'Project links, license, and development credits.',
    'nav.workspace':'WORKSPACE','nav.preferences':'PREFERENCES',
    'copy':'Copy diagnostics','copy.done':'Copied',
    'section.server':'Server status','section.deviceSummary':'Devices','section.pair':'Pair a phone','section.requests':'Connection requests',
    'section.clients':'Authorized phones','section.connections':'Connections','section.local':'Local connection','section.logs':'Server activity',
    'section.about':'About','section.project':'Project','section.development':'Development','section.updates':'Updates',
    'pair.title':'Connect with QR code','pair.description':'Scan this code in the Android app to pair your phone.',
    'pair.remoteReady':'Remote access uses Iroh public relays when needed.','pair.remoteUnavailable':'Remote access unavailable; this code works on the local network.',
    'pair.start':'Start the server to create a QR code.','pair.valid':'Valid until {time}','pair.new':'Generate a new QR code',
    'pair.expired':'The QR code has expired. Generate another to pair.','pair.generate':'Generate QR code','pair.alt':'QR code to pair the Android app',
    'status.started':'Server running','status.stopped':'Server stopped','status.connecting':'Connecting…','status.wifi':'Wi-Fi connection','status.listening':'Listening on all interfaces',
    'status.off':'Stopped','status.tcp':'TCP control','status.port':'Port {port}','status.discovery':'Automatic discovery','status.udp':'Listening via UDP',
    'status.local':'Local network','status.noAddress':'No local address found','status.lastPhone':'Last phone connection attempt',
    'status.noConnection':'No connection received','status.start':'Start server','status.stop':'Stop server',
    'status.pending':'Pending requests','status.authorized':'Authorized phones',
    'status.device':'YOUR COMPUTER','status.runningDescription':'The server is ready to accept connections from your phone.','status.stoppedDescription':'Start the server to connect your phone and control this PC.','status.connectPhone':'Connect a phone','status.overview':'At a glance','status.deviceCount':'Authorized phones','status.deviceCountCaption':'Can connect to this computer','status.pendingCaption':'Waiting for your approval','status.addressCaption':'Local network address','status.connections':'Connection details','status.connectionDescription':'How your phone can reach this computer on the local network.','status.lastConnection':'Last phone connection','status.lastConnectionDescription':'Most recent connection attempt received by the server.','status.lastConnectionAt':'Received {time}','status.noConnectionYet':'No connection attempt yet','status.pendingNone':'No requests need your attention',
    'devices.noneWaiting':'No requests waiting.','devices.defaultPhone':'Phone','devices.reject':'Reject','devices.approve':'Approve',
    'devices.noneAuthorized':'No authorized phones.','devices.connected':'Connected','devices.authorized':'Authorized','devices.revoke':'Revoke access',
    'devices.android':'Android {version}',
    'network.wifiControl':'Wi-Fi control','network.tcp':'TCP {port}','network.udp':'UDP {port}','network.discovery':'Automatic discovery','network.addresses':'This PC addresses',
    'network.noIpv4':'No local IPv4 address','network.dashboard':'Dashboard on this PC',
    'network.instruction':'To connect on the same Wi-Fi network, open the Android app and tap Request connection.',
    'network.help':'Scan the QR code in Devices to save a persistent connection that can also work from another network.',
    'logs.loading':'Loading diagnostics…','logs.error':'Could not load diagnostics. Check that the server is running, then try again.','logs.folder':'Log folder',
    'about.application':'Application','about.server':'Server','about.license':'License','about.log':'Log file',
    'about.website':'Official website','about.personalWebsite':'Personal website','about.personalGithub':'Personal GitHub','about.author':'Leonardo Briquezi aka devpatok',
    'about.summary':'A simple way to control your Windows PC from your phone.','about.projectDescription':'Source code and project releases.','about.maintainerRole':'Project developer',
    'links.github':'GitHub',
    'updates.loading':'Loading updates…','updates.ready':'Update status','updates.disabledTitle':'Updates are unavailable.','updates.disabled':'Download the current version from GitHub to update this installation.',
    'updates.checking':'Checking for updates…','updates.current':'You have the latest version.','updates.available':'Update available.',
    'updates.deferred':'Update postponed until you check again or restart the Windows app.','updates.downloading':'Downloading and validating the update…',
    'updates.applying':'Applying the update. The server will restart.','updates.failed':'The update could not be completed.',
    'updates.installed':'Installed version','updates.availableVersion':'Available version','updates.viewRelease':'View release on GitHub',
    'updates.download':'Update download','updates.retry':'Try again','updates.check':'Check for updates','updates.update':'Update','updates.defer':'Not now',
    'updates.error':'The update could not be completed. Check again or try later.',
    'updates.restartTimeout':'The server has not responded yet. Try reconnecting to the local dashboard.','updates.reconnect':'Reconnect to dashboard',
    'updates.heroAvailable':'A new version is ready. Review the notes and install when you are ready.','updates.heroCurrent':'This server is up to date.','updates.heroChecking':'Checking the latest release…','updates.heroIdle':'Check for a newer version of Open Remote Control.','updates.heroDisabled':'This installation cannot update from the dashboard.','updates.heroFailed':'The update could not be completed. Review the error and try again.','updates.notificationTitle':'Update available','updates.notificationBody':'Version {version} is ready to install.','updates.notificationAction':'View update','updates.currentTitle':'You are up to date','updates.currentBody':'This server is already using the latest version.','updates.dismiss':'Dismiss notification','updates.details':'Version details','updates.howItWorks':'You stay in control','updates.howItWorksBody':'The server checks for updates automatically. Installing one always requires your confirmation.','updates.readyLabel':'Ready','updates.availableLabel':'Available','updates.latestLabel':'Latest version','updates.installedLabel':'Installed version',
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
    'title':'Open Remote Control — Servidor','app.kicker':'SERVIDOR WINDOWS','navigation':'Navegação principal','language.label':'Idioma',
    'page.status':'Status','page.devices':'Dispositivos','page.network':'Rede','page.logs':'Logs','page.updates':'Atualizações','page.about':'Sobre',
    'page.statusSubtitle':'Uma visão geral do servidor Windows.','page.devicesSubtitle':'Pareie celulares e gerencie quem pode controlar este PC.','page.networkSubtitle':'Endereços locais e detalhes de conexão deste computador.','page.logsSubtitle':'Entradas recentes e a pasta onde os arquivos são salvos.','page.updatesSubtitle':'Confira as novidades e escolha quando instalar.','page.aboutSubtitle':'Links do projeto, licença e créditos de desenvolvimento.',
    'nav.workspace':'ESPAÇO DE TRABALHO','nav.preferences':'PREFERÊNCIAS',
    'copy':'Copiar diagnóstico','copy.done':'Copiado',
    'section.server':'Estado do servidor','section.deviceSummary':'Dispositivos','section.pair':'Parear celular','section.requests':'Pedidos de conexão',
    'section.clients':'Celulares autorizados','section.connections':'Conexões','section.local':'Conexão local','section.logs':'Atividade do servidor',
    'section.about':'Sobre','section.project':'Projeto','section.development':'Desenvolvimento','section.updates':'Atualizações',
    'pair.title':'Conectar pelo QR code','pair.description':'Escaneie este código no app Android para parear o celular.',
    'pair.remoteReady':'O acesso remoto usa servidores públicos do Iroh quando necessário.','pair.remoteUnavailable':'Acesso remoto indisponível; o código funciona na rede local.',
    'pair.start':'Inicie o servidor para gerar um QR code.','pair.valid':'Válido até {time}','pair.new':'Gerar novo QR code',
    'pair.expired':'O QR code expirou. Gere outro para parear.','pair.generate':'Gerar QR code','pair.alt':'QR code para parear o app Android',
    'status.started':'Servidor iniciado','status.stopped':'Servidor parado','status.connecting':'Conectando…','status.wifi':'Conexão Wi-Fi','status.listening':'Ouvindo em todas as interfaces',
    'status.off':'Parada','status.tcp':'Controle TCP','status.port':'Porta {port}','status.discovery':'Descoberta automática','status.udp':'Ouvindo via UDP',
    'status.local':'Rede local','status.noAddress':'Nenhum endereço local encontrado','status.lastPhone':'Última tentativa de conexão do celular',
    'status.noConnection':'Nenhuma conexão recebida','status.start':'Iniciar servidor','status.stop':'Parar servidor',
    'status.pending':'Pedidos pendentes','status.authorized':'Celulares autorizados',
    'status.device':'SEU COMPUTADOR','status.runningDescription':'O servidor está pronto para receber conexões do celular.','status.stoppedDescription':'Inicie o servidor para conectar o celular e controlar este PC.','status.connectPhone':'Conectar celular','status.overview':'Visão geral','status.deviceCount':'Celulares autorizados','status.deviceCountCaption':'Podem se conectar a este computador','status.pendingCaption':'Aguardando sua aprovação','status.addressCaption':'Endereço da rede local','status.connections':'Detalhes da conexão','status.connectionDescription':'Como o celular pode acessar este computador pela rede local.','status.lastConnection':'Última conexão do celular','status.lastConnectionDescription':'Tentativa de conexão mais recente recebida pelo servidor.','status.lastConnectionAt':'Recebida em {time}','status.noConnectionYet':'Nenhuma tentativa de conexão ainda','status.pendingNone':'Nenhum pedido precisa da sua atenção',
    'devices.noneWaiting':'Nenhum pedido aguardando.','devices.defaultPhone':'Celular','devices.reject':'Recusar','devices.approve':'Aprovar',
    'devices.noneAuthorized':'Nenhum celular autorizado.','devices.connected':'Conectado','devices.authorized':'Autorizado','devices.revoke':'Revogar acesso',
    'devices.android':'Android {version}',
    'network.wifiControl':'Controle Wi-Fi','network.tcp':'TCP {port}','network.udp':'UDP {port}','network.discovery':'Descoberta automática','network.addresses':'Endereços deste PC',
    'network.noIpv4':'Nenhum endereço IPv4 local','network.dashboard':'Painel neste computador',
    'network.instruction':'Para conectar na mesma rede Wi-Fi, abra o app Android e toque em Solicitar conexão.',
    'network.help':'Escaneie o QR code em Dispositivos para salvar uma conexão persistente, que também pode funcionar em outra rede.',
    'logs.loading':'Carregando diagnóstico…','logs.error':'Não foi possível carregar o diagnóstico. Confira se o servidor está ativo e tente novamente.','logs.folder':'Pasta de logs',
    'about.application':'Aplicativo','about.server':'Servidor','about.license':'Licença','about.log':'Arquivo de log',
    'about.website':'Site oficial','about.personalWebsite':'Site pessoal','about.personalGithub':'GitHub pessoal','about.author':'Leonardo Briquezi aka devpatok',
    'about.summary':'Uma forma simples de controlar o PC Windows pelo celular.','about.projectDescription':'Código-fonte e versões do projeto.','about.maintainerRole':'Desenvolvedor do projeto',
    'links.github':'GitHub',
    'updates.loading':'Carregando atualizações…','updates.ready':'Estado das atualizações','updates.disabledTitle':'Atualizações indisponíveis.','updates.disabled':'Baixe a versão atual pelo GitHub para atualizar esta instalação.',
    'updates.checking':'Verificando atualizações…','updates.current':'Você está na versão mais recente.','updates.available':'Atualização disponível.',
    'updates.deferred':'Atualização adiada até verificar novamente ou reiniciar o aplicativo do Windows.','updates.downloading':'Baixando e validando a atualização…',
    'updates.applying':'Aplicando a atualização. O servidor será reiniciado.','updates.failed':'Não foi possível concluir a atualização.',
    'updates.installed':'Versão instalada','updates.availableVersion':'Versão disponível','updates.viewRelease':'Ver versão no GitHub',
    'updates.download':'Download da atualização','updates.retry':'Tentar novamente','updates.check':'Verificar atualizações','updates.update':'Atualizar','updates.defer':'Agora não',
    'updates.error':'Não foi possível concluir a atualização. Verifique novamente ou tente mais tarde.',
    'updates.restartTimeout':'O servidor ainda não respondeu. Tente reconectar ao painel local.','updates.reconnect':'Reconectar ao painel',
    'updates.heroAvailable':'Uma nova versão está pronta. Confira as novidades e instale quando quiser.','updates.heroCurrent':'Este servidor está atualizado.','updates.heroChecking':'Verificando a versão mais recente…','updates.heroIdle':'Verifique se há uma nova versão do Open Remote Control.','updates.heroDisabled':'Esta instalação não pode ser atualizada pelo painel.','updates.heroFailed':'Não foi possível concluir a atualização. Confira o erro e tente novamente.','updates.notificationTitle':'Atualização disponível','updates.notificationBody':'A versão {version} está pronta para instalar.','updates.notificationAction':'Ver atualização','updates.currentTitle':'Você está atualizado','updates.currentBody':'Este servidor já está na versão mais recente.','updates.dismiss':'Dispensar notificação','updates.details':'Detalhes da versão','updates.howItWorks':'Você decide','updates.howItWorksBody':'O servidor verifica atualizações automaticamente. A instalação sempre depende da sua confirmação.','updates.readyLabel':'Pronta','updates.availableLabel':'Disponível','updates.latestLabel':'Versão mais recente','updates.installedLabel':'Versão instalada',
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
let currentPage=['status','devices','network','logs','updates','about'].includes(location.hash.slice(1))?location.hash.slice(1):'status';
let latestState=null;
let latestUpdate=null;
let updateActionPending=false;
let announcedUpdateVersion=null;
let updateCheckFeedbackPending=false;
let toastTimer=null;
const pendingActions=new Set();
let reconnectTarget=null;
let reconnectTimedOut=false;
let reconnectRunning=false;
let logsOutput=null;
let logsHeading=null;
let logsPathLabel=null;
let logsPathValue=null;
let logsLoadState='loading';
let logsFetchPending=false;
let logsGeneration=0;
let activeNotice=null;
let pairingQr=null;
let pairingQrUrl=null;
let lastRenderedPage=null;
let lastRenderedUpdateSignature=null;
const pageDescriptionKeys={status:'page.statusSubtitle',devices:'page.devicesSubtitle',network:'page.networkSubtitle',logs:'page.logsSubtitle',updates:'page.updatesSubtitle',about:'page.aboutSubtitle'};
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
function showToast(title,message,{actionLabel,action,kind='success'}={}){
  const root=byId('toastContainer');
  if(!root)return;
  if(toastTimer!==null)clearTimeout(toastTimer);
  const card=node('div','toast-card'+(kind==='error'?' error':''));
  card.setAttribute('role',kind==='error'?'alert':'status');
  const mark=node('div','toast-mark',kind==='error'?'!':'✓');
  mark.setAttribute('aria-hidden','true');
  const copy=node('div','toast-copy');
  copy.append(node('strong','',title),node('p','',message));
  if(actionLabel&&action){
    const button=node('button','toast-action',actionLabel);
    button.type='button';button.onclick=()=>{dismissToast();action();};
    copy.append(button);
  }
  const close=node('button','toast-close','×');
  close.type='button';close.setAttribute('aria-label',t('updates.dismiss'));close.onclick=dismissToast;
  card.append(mark,copy,close);root.replaceChildren(card);
  toastTimer=setTimeout(dismissToast,10000);
}
function dismissToast(){
  if(toastTimer!==null){clearTimeout(toastTimer);toastTimer=null;}
  byId('toastContainer')?.replaceChildren();
}
function navigateTo(page){
  currentPage=page;location.hash=page;selectPage();
}
function syncUpdateBadge(){
  const badge=byId('updateBadge');
  if(!badge)return;
  const pending=['available','deferred'].includes(latestUpdate?.state);
  badge.classList.toggle('hidden',!pending);
  badge.textContent=pending?t('updates.availableLabel'):'';
}
function notifyUpdateState(data){
  syncUpdateBadge();
  if(data?.state==='available'&&data.availableVersion){
    updateCheckFeedbackPending=false;
    if(announcedUpdateVersion!==data.availableVersion){
      announcedUpdateVersion=data.availableVersion;
      showToast(t('updates.notificationTitle'),t('updates.notificationBody',{version:data.availableVersion}),{
        actionLabel:t('updates.notificationAction'),action:()=>navigateTo('updates'),
      });
    }
  }else if(updateCheckFeedbackPending&&data?.state==='upToDate'){
    updateCheckFeedbackPending=false;
    showToast(t('updates.currentTitle'),t('updates.currentBody'));
  }else if(updateCheckFeedbackPending&&data?.state==='failed'){
    updateCheckFeedbackPending=false;
    showToast(t('updates.failed'),errorMessage(data.error?.code,'error.update'),{kind:'error',actionLabel:t('updates.notificationAction'),action:()=>navigateTo('updates')});
  }else if(updateCheckFeedbackPending&&data?.state==='disabled'){
    updateCheckFeedbackPending=false;
    showToast(t('updates.heroDisabled'),t('updates.disabled'),{kind:'error'});
  }
}
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
    details.append(node('div','device-detail',t(data.persistentAvailable?'pair.remoteReady':'pair.remoteUnavailable')));
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
function statCard(label,value,caption,valueClass=''){
  const card=node('div','stat-card');
  card.append(node('div','stat-label',label),node('div','stat-value'+(valueClass?' '+valueClass:''),value),node('div','stat-caption',caption));
  return card;
}
function connectionTime(value){
  if(!value)return '';
  const date=new Date(value);
  if(Number.isNaN(date.getTime()))return '';
  return new Intl.DateTimeFormat(language,{dateStyle:'medium',timeStyle:'short'}).format(date);
}
function connectPhoneButton(){
  const button=node('button','btn btn-outline btn-neutral',t('status.connectPhone'));
  button.type='button';button.onclick=()=>navigateTo('devices');
  return button;
}
function renderStatus(data){
  const root=byId('page');root.replaceChildren();
  const hero=node('div','server-hero'+(data.running?'':' stopped'));
  const copy=node('div','server-hero-copy');
  copy.append(node('div','eyebrow',t('status.device')));
  copy.append(node('h2','',t(data.running?'status.started':'status.stopped')));
  copy.append(node('p','',t(data.running?'status.runningDescription':'status.stoppedDescription')));
  const actions=node('div','server-hero-actions');
  actions.append(makeAction(t(data.running?'status.stop':'status.start'),data.running?'stop':'start',undefined,data.running?'danger':'primary'));
  actions.append(connectPhoneButton());
  hero.append(copy,actions);root.append(hero);

  const requests=data.requests||[],clients=data.clients||[],addresses=data.addresses||[];
  const address=addresses.join(' · ')||t('status.noAddress');
  const stats=node('div','stat-grid');
  stats.append(
    statCard(t('status.deviceCount'),localeNumber(clients.length),t('status.deviceCountCaption')),
    statCard(t('status.pending'),localeNumber(requests.length),requests.length?t('status.pendingCaption'):t('status.pendingNone')),
    statCard(t('status.local'),address,t('status.addressCaption'),'address-value'),
  );
  root.append(section(t('status.overview'),stats));

  const grid=node('div','overview-grid');
  const connection=panel();connection.className+=' overview-card';
  const heading=node('div','card-heading');
  const headingCopy=node('div');headingCopy.append(node('h3','',t('status.connections')),node('p','',t('status.connectionDescription')));
  const networkLink=node('a','text-link',t('page.network'));networkLink.href='#network';networkLink.onclick=event=>{event.preventDefault();navigateTo('network');};
  heading.append(headingCopy,networkLink);connection.append(heading);
  const rows=node('div','rows');
  rows.append(row(t('status.wifi'),data.running?t('status.listening'):t('status.off'),data.running?'ok':'off'));
  rows.append(row(t('status.tcp'),data.running?t('status.port',{port:data.port||47652}):'—'));
  rows.append(row(t('status.discovery'),data.discoveryRunning?t('status.udp'):t('status.off'),data.discoveryRunning?'ok':'off'));
  connection.append(rows);grid.append(connection);

  const recent=panel();recent.className+=' overview-card';
  const recentHeading=node('div','card-heading');
  recentHeading.append(node('div','',t('status.lastConnection')));recent.append(recentHeading);
  recent.append(node('p','small',t('status.lastConnectionDescription')));
  if(data.lastConnectionAddress){
    recent.append(node('div','connection-address',data.lastConnectionAddress));
    const time=connectionTime(data.lastConnectionAt);
    if(time)recent.append(node('div','connection-time',t('status.lastConnectionAt',{time})));
  }else{
    const empty=node('div','connection-empty');empty.append(node('strong','',t('status.noConnectionYet')),node('span','',t('status.noConnection')));recent.append(empty);
  }
  grid.append(recent);root.append(grid);
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
  help.append(node('div','network-help',t('network.instruction')+' '+t('network.help')));
  root.append(section(t('section.local'),help));
}
function renderLogs({refreshDiagnostics=true}={}){
  const root=byId('page');
  if(!logsOutput){
    root.replaceChildren();
    const box=panel();
    logsLoadState='loading';
    const location=node('div','log-location');
    logsPathLabel=node('span','log-location-label',t('logs.folder'));
    logsPathValue=node('code','log-location-value',logDirectory(latestState?.logPath));
    location.append(logsPathLabel,logsPathValue);
    logsOutput=node('pre','log-output',t('logs.loading'));
    logsOutput.setAttribute('aria-label',t('section.logs'));
    box.append(location,logsOutput);
    const wrapper=section(t('section.logs'),box);
    logsHeading=wrapper.children[0];
    root.append(wrapper);
  }else if(logsHeading){
    logsHeading.textContent=t('section.logs');
    logsOutput.setAttribute('aria-label',t('section.logs'));
    if(logsLoadState==='loading')logsOutput.textContent=t('logs.loading');
    if(logsLoadState==='failed')logsOutput.textContent=t('logs.error');
  }
  if(logsPathLabel)logsPathLabel.textContent=t('logs.folder');
  if(logsPathValue)logsPathValue.textContent=logDirectory(latestState?.logPath);
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
function logDirectory(path){
  if(typeof path!=='string'||!path)return '—';
  const separator=Math.max(path.lastIndexOf('\\'),path.lastIndexOf('/'));
  return separator>0?path.slice(0,separator):path;
}
function renderAbout(){
  const root=byId('page');root.replaceChildren();
  const hero=node('div','about-hero');
  const mark=node('img','about-brand-mark');mark.src='/assets/mark.svg';mark.alt='';
  const identity=node('div');identity.append(node('h2','',t('about.application')),node('p','',t('about.summary')));
  const badges=node('div','about-badges');
  badges.append(node('span','about-badge','Windows'),node('span','about-badge','v'+(latestUpdate?.currentVersion||'—')));
  identity.append(badges);hero.append(mark,identity);root.append(hero);

  const grid=node('div','about-grid');
  const project=panel();project.className+=' about-card';
  project.append(node('h3','',t('section.project')),node('p','',t('about.projectDescription')));
  const projectLinks=node('div','project-links');
  for(const [label,href] of [[t('links.github'),'https://github.com/leobrqz/OpenRemoteControl'],['SourceForge','https://sourceforge.net/projects/openremotecontrol/'],[t('about.website'),'https://openremotecontrol.sourceforge.io/']]){
    const link=node('a','project-link',label);link.href=href;link.target='_blank';link.rel='noopener noreferrer';projectLinks.append(link);
  }
  project.append(projectLinks,node('div','about-divider'),node('div','project-license',t('about.license')+' · GPL-3.0-only'));grid.append(project);

  const details=panel();details.className+=' about-card';
  details.append(node('h3','',t('section.development')));
  const maintainer=node('div','maintainer');
  const maintainerCopy=node('div');maintainerCopy.append(node('strong','',t('about.author')),node('span','',t('about.maintainerRole')));
  maintainer.append(maintainerCopy);details.append(maintainer);
  const authorLinks=node('div','project-links author-links');
  for(const [label,href] of [[t('about.personalWebsite'),'https://leonardobriquezi.me'],[t('about.personalGithub'),'https://github.com/leobrqz']]){
    const link=node('a','project-link',label);link.href=href;link.target='_blank';link.rel='noopener noreferrer';authorLinks.append(link);
  }
  details.append(authorLinks);
  grid.append(details);root.append(grid);
}
function updateButton(label,action,kind){
  const button=node('button','btn btn-sm '+(kind==='primary'?'btn-success':'btn-outline btn-neutral'),label);
  const busy=updateActionPending||['checking','downloading','applying'].includes(latestUpdate?.state);
  button.disabled=busy||latestUpdate?.state==='disabled'||!latestUpdate;
  button.onclick=async()=>{
    if(updateActionPending)return;
    updateActionPending=true;
    if(action==='update_check')updateCheckFeedbackPending=true;
    if(currentPage==='updates')renderUpdates();
    const candidate=latestUpdate;
    try{
      const body={action};if(action!=='update_check')body.candidateId=candidate.candidateId;
      const response=await fetch('/api/action',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
      const result=await response.json();if(!response.ok)throw {errorCode:result.errorCode};
      if(action==='update_install'){reconnectTarget=candidate.availableVersion;reconnectTimedOut=false;}
      showNotice('');await refresh();
    }catch(error){updateCheckFeedbackPending=false;showError(error?.errorCode,'error.updateAction');}
    finally{updateActionPending=false;if(currentPage==='updates')renderUpdates();}
  };
  return button;
}
function renderUpdates(force=false){
  const root=byId('page');
  const data=latestUpdate;
  const signature=JSON.stringify([data,updateActionPending,reconnectTimedOut,language]);
  if(!force&&signature===lastRenderedUpdateSignature&&currentPage==='updates')return;
  lastRenderedUpdateSignature=signature;
  root.replaceChildren();
  if(!data){root.append(panel());return;}
  const titles={idle:'updates.ready',disabled:'updates.disabledTitle',checking:'updates.checking',upToDate:'updates.current',available:'updates.available',deferred:'updates.deferred',downloading:'updates.downloading',applying:'updates.applying',failed:'updates.failed'};
  const descriptions={disabled:'updates.disabled',available:'updates.heroAvailable'};
  const state=data.state||'idle';
  const hero=node('div','update-hero');
  const message=node('div','update-hero-copy');
  message.append(node('h2','',t(titles[state]||'updates.ready')));
  if(descriptions[state])message.append(node('p','',t(descriptions[state])));
  hero.append(message);
  if(state!=='disabled')hero.append(updateButton(t(state==='failed'?'updates.retry':'updates.check'),'update_check'));

  const versionCard=panel();versionCard.className+=' update-panel';
  versionCard.append(hero);
  const versions=node('div','update-versions');
  versions.append(row(t('updates.installed'),data.currentVersion||'—'));
  if(data.availableVersion)versions.append(row(t('updates.availableVersion'),data.availableVersion));
  versionCard.append(versions);
  if(state==='downloading'){
    const progress=node('progress','update-progress');progress.max=100;progress.value=data.progressPercent??0;
    progress.setAttribute('aria-label',t('updates.download'));versionCard.append(progress,node('div','small',localeNumber(progress.value)+'%'));
  }
  if(data.notes)versionCard.append(node('pre','release-notes',data.notes));
  if(data.releaseUrl){
    try{
      const url=new URL(data.releaseUrl);
      if(url.origin==='https://github.com'&&url.pathname.startsWith('/leobrqz/OpenRemoteControl/releases/tag/')){
        const link=node('a','text-link',t('updates.viewRelease'));link.href=url.href;link.target='_blank';link.rel='noopener noreferrer';versionCard.append(link);
      }
    }catch{}
  }
  if(data.error){
    versionCard.append(node('p','update-error',errorMessage(data.error.code,'error.update')));
  }
  const actions=node('div','update-actions');
  if(state==='available')actions.append(updateButton(t('updates.update'),'update_install','primary'),updateButton(t('updates.defer'),'update_defer'));
  if(reconnectTimedOut){
    versionCard.append(node('p','update-error',t('updates.restartTimeout')));
    const retry=node('button','btn btn-sm btn-outline btn-neutral',t('updates.reconnect'));
    retry.onclick=()=>{reconnectTimedOut=false;void reconnect();};actions.append(retry);
  }
  if(actions.children.length)versionCard.append(actions);
  root.append(versionCard);
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
        if(data.state==='failed'){latestUpdate=data;reconnectTarget=null;reconnectRunning=false;if(currentPage==='updates')renderUpdates();return;}}
    }catch{}
    const remaining=Math.min(nextPoll,deadline)-Date.now();
    if(remaining>0)await new Promise(resolve=>setTimeout(resolve,remaining));
  }
  reconnectRunning=false;reconnectTimedOut=true;
  if(currentPage==='updates')renderUpdates();
}
function render(data,{languageChange=false,preserveNotice=false}={}){
  const pageChanged=lastRenderedPage!==currentPage;
  latestState=data;
  byId('pageTitle').textContent=t('page.'+currentPage);
  const description=byId('pageDescription');if(description)description.textContent=t(pageDescriptionKeys[currentPage]||'page.statusSubtitle');
  byId('appVersion').textContent=latestUpdate?.currentVersion?'v'+latestUpdate.currentVersion:'';
  syncUpdateBadge();
  if(currentPage!=='logs'&&logsOutput){logsGeneration++;logsOutput=null;logsHeading=null;logsPathLabel=null;logsPathValue=null;logsLoadState='loading';}
  if(currentPage==='status')renderStatus(data);
  if(currentPage==='devices')renderDevices(data);
  if(currentPage==='network')renderNetwork(data);
  if(currentPage==='logs')renderLogs({refreshDiagnostics:!languageChange});
  if(currentPage==='updates')renderUpdates(pageChanged||languageChange);
  if(currentPage==='about')renderAbout();
  lastRenderedPage=currentPage;
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
    notifyUpdateState(latestUpdate);
    if(latestUpdate.state==='applying'&&!reconnectTimedOut){reconnectTarget=latestUpdate.availableVersion;void reconnect();}
    if(latestUpdate.state==='failed')reconnectTarget=null;
    render(await response.json());
  }catch{if(reconnectTarget&&!reconnectTimedOut)void reconnect();else showError(null,'error.connection');}
}
function updateChrome(){
  document.documentElement.lang=language;
  document.title=t('title');
  byId('pageTitle').textContent=t('page.'+currentPage);
  const eyebrow=byId('pageEyebrow');if(eyebrow)eyebrow.textContent=t('app.kicker');
  const description=byId('pageDescription');if(description)description.textContent=t(pageDescriptionKeys[currentPage]||'page.statusSubtitle');
  byId('mainNav').setAttribute('aria-label',t('navigation'));
  byId('languageControls').setAttribute('aria-label',t('language.label'));
  const workspace=byId('navWorkspace');if(workspace)workspace.textContent=t('nav.workspace');
  const preferences=byId('navPreferences');if(preferences)preferences.textContent=t('nav.preferences');
  const copyLogs=byId('copyLogs');if(copyLogs){copyLogs.textContent=t('copy');copyLogs.setAttribute('aria-label',t('copy'));}
  document.querySelectorAll('[data-language]').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.language===language)));
  document.querySelectorAll('[data-page]').forEach(item=>{
    const label=item.querySelector?.('.nav-label');
    if(label)label.textContent=t('page.'+item.dataset.page);else item.textContent=t('page.'+item.dataset.page);
    item.setAttribute('aria-current',String(item.dataset.page===currentPage?'page':'false'));
  });
  syncUpdateBadge();
}
function selectPage(){
  document.querySelectorAll('[data-page]').forEach(item=>item.classList.toggle('active',item.dataset.page===currentPage));
  updateChrome();
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
  currentPage=['status','devices','network','logs','updates','about'].includes(location.hash.slice(1))?location.hash.slice(1):'status';
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
