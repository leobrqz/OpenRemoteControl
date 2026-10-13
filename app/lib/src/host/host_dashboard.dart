import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/diagnostic_log.dart';

typedef DashboardStateProvider = Map<String, Object?> Function();
typedef DashboardActionHandler =
    Future<void> Function(String action, Map<String, dynamic> parameters);

class HostDashboardServer {
  HostDashboardServer({
    required this.stateProvider,
    required this.actionHandler,
  });

  static const int defaultPort = 47654;
  static const int _portAttempts = 8;

  final DashboardStateProvider stateProvider;
  final DashboardActionHandler actionHandler;
  HttpServer? _server;
  StreamSubscription<HttpRequest>? _subscription;

  int? get port => _server?.port;
  String? get url => port == null ? null : 'http://127.0.0.1:$port/';

  Future<void> start() async {
    if (_server != null) return;
    Object? lastError;
    for (var offset = 0; offset < _portAttempts; offset++) {
      final port = defaultPort + offset;
      try {
        final server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          port,
          shared: false,
        );
        _server = server;
        _subscription = server.listen(
          (request) => unawaited(_handle(request)),
          onError: (Object error, StackTrace stackTrace) {
            unawaited(
              DiagnosticLog.record(
                'Dashboard Windows',
                'Falha no servidor web local.',
                error: error,
                stackTrace: stackTrace,
              ),
            );
          },
        );
        await DiagnosticLog.record(
          'Dashboard Windows',
          'Painel local ouvindo em http://127.0.0.1:$port/.',
        );
        return;
      } catch (error) {
        lastError = error;
      }
    }
    throw HttpException(
      'Não foi possível iniciar o painel localhost entre as portas '
      '$defaultPort e ${defaultPort + _portAttempts - 1}: $lastError',
    );
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    if (!_isLocalRequest(request)) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }
    request.response.headers
      ..set(HttpHeaders.cacheControlHeader, 'no-store')
      ..set('X-Content-Type-Options', 'nosniff')
      ..set(
        'Content-Security-Policy',
        "default-src 'none'; style-src 'unsafe-inline'; "
            "script-src 'unsafe-inline'; connect-src 'self';",
      );

    if (request.method == 'GET' && request.uri.path == '/') {
      request.response.headers.contentType = ContentType.html;
      request.response.write(_dashboardHtml);
      await request.response.close();
      return;
    }
    if (request.method == 'GET' && request.uri.path == '/api/status') {
      await _writeJson(request.response, HttpStatus.ok, stateProvider());
      return;
    }
    if (request.method == 'GET' && request.uri.path == '/api/diagnostics') {
      request.response.headers.contentType = ContentType.text;
      request.response.write(await DiagnosticLog.export());
      await request.response.close();
      return;
    }
    if (request.method == 'POST' && request.uri.path == '/api/action') {
      if (!_isTrustedBrowserPost(request)) {
        await _writeJson(request.response, HttpStatus.forbidden, {
          'error': 'Origem local inválida.',
        });
        return;
      }
      try {
        final body = await _readJsonBody(request);
        final action = body['action'];
        if (action is! String || action.length > 32) {
          throw const FormatException('Ação inválida.');
        }
        await actionHandler(action, body);
        await _writeJson(request.response, HttpStatus.ok, {'ok': true});
      } catch (error, stackTrace) {
        await DiagnosticLog.record(
          'Dashboard Windows',
          'Ação local recusada.',
          error: error,
          stackTrace: stackTrace,
        );
        await _writeJson(request.response, HttpStatus.badRequest, {
          'error': error.toString(),
        });
      }
      return;
    }
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  bool _isLocalRequest(HttpRequest request) {
    final address = request.connectionInfo?.remoteAddress;
    final host = request.headers
        .value(HttpHeaders.hostHeader)
        ?.split(':')
        .first;
    return address?.isLoopback == true &&
        (host == '127.0.0.1' || host == 'localhost');
  }

  bool _isTrustedBrowserPost(HttpRequest request) {
    final origin = request.headers.value('origin');
    return origin == 'http://127.0.0.1:${_server?.port}' ||
        origin == 'http://localhost:${_server?.port}';
  }

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    final body = StringBuffer();
    var byteLength = 0;
    await for (final chunk in request) {
      byteLength += chunk.length;
      if (byteLength > 4096) {
        throw const FormatException('Corpo da solicitação excede 4 KB.');
      }
      body.write(utf8.decode(chunk));
    }
    final decoded = jsonDecode(body.toString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('JSON da ação inválido.');
    }
    return decoded;
  }

  Future<void> _writeJson(
    HttpResponse response,
    int statusCode,
    Map<String, Object?> body,
  ) async {
    response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await response.close();
  }
}

const String _dashboardHtml = r'''<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="color-scheme" content="light">
  <title>Open Remote Control — Servidor</title>
  <style>
    :root{font-family:"Segoe UI",Arial,sans-serif;color:#202124;background:#f5f6f5;font-synthesis:none}
    *{box-sizing:border-box}
    body{margin:0;min-height:100vh}
    button{font:inherit;cursor:pointer}
    .shell{display:grid;grid-template-columns:210px minmax(0,1fr);min-height:100vh}
    aside{background:#fff;border-right:1px solid #d8ded8;display:flex;flex-direction:column}
    .brand{height:58px;display:flex;align-items:center;gap:10px;padding:0 18px;border-bottom:1px solid #e1e4e1;color:#26362c;font-size:15px;font-weight:600}
    .brand-mark{width:25px;height:25px;border:3px solid #3c9827;border-left-color:transparent;border-bottom-color:transparent;border-radius:50%;transform:rotate(45deg);position:relative}
    .brand-mark:after{content:"";position:absolute;width:7px;height:7px;background:#2e6e25;border-radius:50%;left:0;bottom:0}
    nav{padding:12px 8px;display:grid;gap:3px}
    nav button{border:0;background:transparent;text-align:left;border-radius:4px;padding:11px 12px;color:#343a35;font-size:13px;font-weight:500}
    nav button:hover{background:#f0f4ef}
    nav button.active{background:#e9f3e7;color:#286f21;font-weight:650}
    .side-foot{margin-top:auto;padding:14px 18px;color:#778078;border-top:1px solid #e1e4e1;font-size:12px}
    main{min-width:0}
    .page-head{background:#398f24;color:white;min-height:122px;padding:22px clamp(22px,4vw,50px) 18px}
    .eyebrow{font-size:11px;letter-spacing:.08em;text-transform:uppercase;opacity:.88}
    h1{font-size:34px;font-weight:400;line-height:1.1;margin:8px 0 0}
    .head-actions{float:right;margin-top:18px}
    .head-actions button,.button{border:1px solid #c7cec7;background:white;border-radius:3px;padding:9px 13px;color:#29312a;font-size:13px}
    .head-actions button:hover,.button:hover{background:#f3f7f2}
    .head-actions .primary,.button.primary{background:#398f24;border-color:#398f24;color:white}
    .button.danger{color:#a52d24;border-color:#e0c2bf;background:white}
    .content{padding:25px clamp(22px,4vw,50px) 42px;max-width:1250px}
    h2{font-size:20px;font-weight:400;margin:0 0 15px}
    h3{font-size:16px;font-weight:600;margin:0}
    .section{margin:0 0 27px}
    .panel{background:#fff;border:1px solid #dfe3df;border-radius:3px;padding:18px 20px}
    .section-title{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:10px}
    .status-line{display:flex;align-items:center;gap:9px;font-weight:600;font-size:14px;padding:2px 0 15px}
    .indicator{width:9px;height:9px;border-radius:50%;background:#999}
    .indicator.good{background:#398f24}
    .indicator.bad{background:#d44940}
    .rows{border-top:1px solid #dfe3df}
    .row{display:grid;grid-template-columns:minmax(190px,1fr) minmax(180px,2fr);gap:20px;padding:12px 3px;border-bottom:1px solid #e3e6e3;font-size:13px;align-items:center}
    .row:last-child{border-bottom:0}
    .row-label{color:#555e57}
    .row-value{color:#2d342f;font-weight:600;overflow-wrap:anywhere}
    .row-value.ok{color:#328326}
    .row-value.off{color:#737a74}
    .actions{display:flex;flex-wrap:wrap;gap:8px;margin-top:16px}
    .empty{color:#69716b;font-size:13px;padding:14px 2px}
    .device-row{display:flex;align-items:center;justify-content:space-between;gap:16px;padding:12px 2px;border-bottom:1px solid #e3e6e3;font-size:13px}
    .device-row:last-child{border-bottom:0}
    .device-name{font-weight:600}
    .device-detail{color:#69716b;margin-top:4px}
    .notice{display:none;border:1px solid #e5c8c5;background:#fff4f3;color:#9d3028;padding:11px 13px;margin-bottom:18px;font-size:13px;white-space:pre-wrap;overflow-wrap:anywhere}
    .notice.visible{display:block}
    .log-output{font:12px/1.5 Consolas,monospace;white-space:pre-wrap;overflow-wrap:anywhere;max-height:65vh;overflow:auto;margin:0;color:#303832}
    .small{font-size:12px;color:#69716b;line-height:1.5}
    .hidden{display:none}
    @media(max-width:700px){.shell{grid-template-columns:1fr}aside{border-right:0;border-bottom:1px solid #d8ded8}.brand{height:50px}nav{grid-template-columns:repeat(3,1fr);padding:7px}nav button{padding:9px 7px;text-align:center}.side-foot{display:none}.page-head{min-height:105px}.head-actions{margin-top:14px}.row{grid-template-columns:1fr;gap:5px}.device-row{align-items:flex-start;flex-direction:column}}
  </style>
</head>
<body>
<div class="shell">
  <aside>
    <div class="brand"><span class="brand-mark" aria-hidden="true"></span><span>Open Remote</span></div>
    <nav aria-label="Navegação principal">
      <button class="active" data-page="status">Status</button>
      <button data-page="devices">Dispositivos</button>
      <button data-page="network">Rede</button>
      <button data-page="logs">Log</button>
      <button data-page="about">Sobre</button>
    </nav>
    <div class="side-foot">Servidor Windows</div>
  </aside>
  <main>
    <header class="page-head">
      <div class="head-actions"><button id="copyLogs">Copiar diagnóstico</button></div>
      <div class="eyebrow">Open Remote Control</div>
      <h1 id="pageTitle">Status</h1>
    </header>
    <div class="content">
      <div class="notice" id="notice" role="status"></div>
      <div id="page"></div>
    </div>
  </main>
</div>
<script>
const byId=id=>document.getElementById(id);
const pageNames={status:'Status',devices:'Dispositivos',network:'Rede',logs:'Log',about:'Sobre'};
let currentPage='status';
let latestState=null;
function node(tag,className,text){const item=document.createElement(tag);if(className)item.className=className;if(text!==undefined)item.textContent=text;return item;}
function section(title,body){const wrap=node('section','section');if(title){const heading=node('h2','',title);wrap.append(heading);}wrap.append(body);return wrap;}
function panel(){return node('div','panel');}
function row(label,value,state){const line=node('div','row');line.append(node('div','row-label',label));line.append(node('div','row-value'+(state?' '+state:''),value));return line;}
function showNotice(message){const box=byId('notice');box.textContent=message||'';box.classList.toggle('visible',Boolean(message));}
async function doAction(name,id,button){if(button)button.disabled=true;try{const response=await fetch('/api/action',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action:name,id:id})});const result=await response.json();if(!response.ok)throw new Error(result.error||'Ação recusada.');showNotice('');await refresh();}catch(error){showNotice(error.message);}finally{if(button)button.disabled=false;}}
function makeAction(label,action,id,kind){const button=node('button','button'+(kind?' '+kind:''),label);button.onclick=()=>doAction(action,id,button);return button;}
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
  actions.append(makeAction('Mostrar janela do aplicativo','show_app',null,''));
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
  rows.append(row('Endereços deste PC',(data.addresses||[]).join('  ·  ')||'Nenhum endereço IPv4 local')));
  rows.append(row('Painel neste computador','http://127.0.0.1:'+(data.dashboardPort||47654)+'/'));
  connections.append(rows);root.append(section('Conexões',connections));
  const help=panel();
  help.append(node('div','','Para conectar na mesma rede Wi-Fi, abra o app Android e toque em Solicitar.'));
  help.append(node('p','small','Se a descoberta automática não encontrar o PC, use o QR exibido no aplicativo Windows. O acesso por 4G depende de um relay ou de uma rota pública configurada.'));
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
}
function render(data){
  latestState=data;byId('pageTitle').textContent=pageNames[currentPage];
  if(currentPage==='status')renderStatus(data);
  if(currentPage==='devices')renderDevices(data);
  if(currentPage==='network')renderNetwork(data);
  if(currentPage==='logs')void renderLogs();
  if(currentPage==='about')renderAbout(data);
  showNotice(data.error||'');
}
async function refresh(){try{const response=await fetch('/api/status',{cache:'no-store'});if(!response.ok)throw new Error('Não foi possível ler o estado do servidor.');render(await response.json());}
catch(error){showNotice(error.message);}}
document.querySelectorAll('[data-page]').forEach(button=>button.addEventListener('click',()=>{currentPage=button.dataset.page;document.querySelectorAll('[data-page]').forEach(item=>item.classList.toggle('active',item===button));if(latestState)render(latestState);}));
byId('copyLogs').onclick=async event=>{const button=event.currentTarget;try{const response=await fetch('/api/diagnostics',{cache:'no-store'});const text=await response.text();await navigator.clipboard.writeText(text);button.textContent='Copiado';setTimeout(()=>button.textContent='Copiar diagnóstico',1600);}catch(error){showNotice('Falha ao copiar diagnóstico: '+error.message);}};
refresh();setInterval(refresh,3000);
</script>
</body>
</html>''';
