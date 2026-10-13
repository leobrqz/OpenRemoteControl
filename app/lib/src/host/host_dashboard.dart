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
  <meta name="color-scheme" content="dark">
  <title>Open Remote · Servidor local</title>
  <style>
    :root{font-family:Segoe UI,system-ui,sans-serif;color:#e7f0ef;background:#101719;font-synthesis:none}
    *{box-sizing:border-box}body{margin:0;min-height:100vh;background:radial-gradient(ellipse at 20% 0%,#17332f 0,transparent 42%),#101719}
    main{max-width:1000px;margin:0 auto;padding:44px 24px 72px}.brand{color:#77e4d3;font-size:13px;letter-spacing:.18em;text-transform:uppercase;font-weight:700}
    h1{font-size:clamp(32px,5vw,52px);line-height:1.04;letter-spacing:-.04em;margin:14px 0 10px}.muted{color:#9baead;line-height:1.55}
    .top{display:flex;align-items:center;justify-content:space-between;gap:20px;margin-bottom:28px}.card{background:#182225;border:1px solid #293639;border-radius:20px;padding:24px;margin:16px 0}
    .status{display:flex;align-items:center;gap:12px;font-weight:700;font-size:20px}.dot{width:12px;height:12px;border-radius:50%;background:#778383}.dot.on{background:#77e4d3;box-shadow:0 0 18px #77e4d377}
    .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px;margin-top:20px}.metric{padding:16px;border-radius:14px;background:#11191b}.metric strong{display:block;color:#77e4d3;font-size:12px;letter-spacing:.12em;text-transform:uppercase;margin-bottom:8px}.metric code{overflow-wrap:anywhere;font-size:15px}
    h2{font-size:20px;margin:0 0 8px}.row{display:flex;align-items:center;justify-content:space-between;gap:16px;padding:14px 0;border-bottom:1px solid #293639}.row:last-child{border-bottom:0}.row p{margin:4px 0 0;color:#9baead;font-size:14px}
    button{font:inherit;font-weight:650;border:0;border-radius:11px;padding:11px 15px;color:#101719;background:#77e4d3;cursor:pointer}button.secondary{color:#e7f0ef;background:#293639}button.danger{color:#ffe3df;background:#4a2926}button:disabled{opacity:.5;cursor:wait}
    .actions{display:flex;gap:8px;flex-wrap:wrap}.error{color:#ffa79b;white-space:pre-wrap}.empty{color:#9baead;padding:12px 0}.foot{color:#718482;font-size:13px;margin-top:25px}
    @media(max-width:600px){main{padding:28px 16px 48px}.top{align-items:flex-start;flex-direction:column}.card{padding:18px}.row{align-items:flex-start;flex-direction:column}.actions{width:100%}}
  </style>
</head>
<body>
<main>
  <div class="brand">Open Remote Control</div>
  <div class="top"><div><h1>Servidor Windows</h1><div class="muted">Painel local · nada é enviado para a nuvem.</div></div><button class="secondary" id="logs">Copiar diagnóstico</button></div>
  <section class="card">
    <div class="status"><span class="dot" id="dot"></span><span id="state">Carregando…</span></div>
    <div class="muted" id="error"></div>
    <div class="grid"><div class="metric"><strong>Endereço do PC</strong><code id="addresses">—</code></div><div class="metric"><strong>Porta do controle</strong><code id="controlPort">47652/TCP</code></div><div class="metric"><strong>Descoberta Wi‑Fi</strong><code>47653/UDP</code></div></div>
    <div class="actions" style="margin-top:18px"><button id="toggle">Parar servidor</button><button class="secondary" id="showApp">Mostrar janela do aplicativo</button></div>
  </section>
  <section class="card"><h2>Pedidos de conexão</h2><div class="muted">Aprove os celulares que podem controlar este computador.</div><div id="requests" class="empty">Nenhum pedido aguardando.</div></section>
  <section class="card"><h2>Celulares autorizados</h2><div id="clients" class="empty">Nenhum celular pareado.</div></section>
  <p class="foot">Se o celular encontrar este PC mas não conectar, libere a porta TCP 47652 no Firewall do Windows para redes privadas.</p>
</main>
<script>
const byId=id=>document.getElementById(id);
function make(tag,cls,text){const node=document.createElement(tag);if(cls)node.className=cls;if(text!==undefined)node.textContent=text;return node;}
async function action(name,id,button){if(button)button.disabled=true;try{const response=await fetch('/api/action',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action:name,id})});const data=await response.json();if(!response.ok)throw new Error(data.error||'Ação recusada');await refresh();}catch(error){byId('error').textContent=error.message;}finally{if(button)button.disabled=false;}}
function renderRows(root,items,kind){root.replaceChildren();if(!items.length){root.className='empty';root.textContent=kind==='request'?'Nenhum pedido aguardando.':'Nenhum celular pareado.';return;}root.className='';for(const item of items){const row=make('div','row');const info=make('div');info.append(make('strong','',item.name));info.append(make('p','',kind==='request'?item.address:(item.connected?'Conectado':'Pareado')));row.append(info);const buttons=make('div','actions');if(kind==='request'){const reject=make('button','danger','Recusar');reject.onclick=event=>action('reject',item.id,event.currentTarget);const approve=make('button','','Aprovar');approve.onclick=event=>action('approve',item.id,event.currentTarget);buttons.append(reject,approve);}else{const revoke=make('button','secondary','Revogar');revoke.onclick=event=>action('revoke',item.id,event.currentTarget);buttons.append(revoke);}row.append(buttons);root.append(row);}}
async function refresh(){try{const response=await fetch('/api/status',{cache:'no-store'});if(!response.ok)throw new Error('Painel indisponível');const data=await response.json();byId('dot').className=data.running?'dot on':'dot';byId('state').textContent=data.running?'Servidor ativo':'Servidor parado';byId('error').textContent=data.error||'';byId('addresses').textContent=(data.addresses||[]).join(' · ')||'—';byId('controlPort').textContent=(data.port||47652)+'/TCP';byId('toggle').textContent=data.running?'Parar servidor':'Iniciar servidor';byId('toggle').onclick=()=>action(data.running?'stop':'start');renderRows(byId('requests'),data.requests||[],'request');renderRows(byId('clients'),data.clients||[],'client');}catch(error){byId('state').textContent='Servidor indisponível';byId('error').textContent=error.message;}}
byId('logs').onclick=async()=>{try{const text=await(await fetch('/api/diagnostics')).text();await navigator.clipboard.writeText(text);byId('logs').textContent='Diagnóstico copiado';setTimeout(()=>byId('logs').textContent='Copiar diagnóstico',1800);}catch(error){byId('error').textContent=error.message;}};
byId('showApp').onclick=event=>action('show_app',undefined,event.currentTarget);
refresh();setInterval(refresh,2000);
</script>
</body>
</html>''';
