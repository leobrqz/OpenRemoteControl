// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Open Remote';

  @override
  String get language => 'Idioma';

  @override
  String get languageEnglish => 'English';

  @override
  String get languagePortuguese => 'Português (Brasil)';

  @override
  String get computers => 'Computadores';

  @override
  String get settings => 'Configurações';

  @override
  String get about => 'Sobre';

  @override
  String get mouse => 'Mouse';

  @override
  String get media => 'Mídia';

  @override
  String get keyboard => 'Teclado';

  @override
  String forgetHostTitle(String name) {
    return 'Esquecer $name?';
  }

  @override
  String get forgetHostBody =>
      'Será necessário autorizar este celular novamente para conectar.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get forget => 'Esquecer';

  @override
  String get reconnecting => 'Reconectando…';

  @override
  String get disconnected => 'Desconectado';

  @override
  String get reconnect => 'Reconectar';

  @override
  String get disconnect => 'Desconectar';

  @override
  String get searchComputers => 'Procurar computadores';

  @override
  String get addComputer => 'Adicionar computador';

  @override
  String get scanQr => 'Escanear QR';

  @override
  String get connectByIp => 'Conectar por IP';

  @override
  String get computerOptions => 'Opções do computador';

  @override
  String get connected => 'Conectado';

  @override
  String get paired => 'Pareado';

  @override
  String get available => 'Disponível';

  @override
  String get openControls => 'Abrir controles';

  @override
  String get requestConnection => 'Solicitar conexão';

  @override
  String get forgetComputer => 'Esquecer computador';

  @override
  String get connecting => 'Conectando…';

  @override
  String get searchingComputers => 'Procurando computadores…';

  @override
  String get noComputersFound => 'Nenhum computador encontrado';

  @override
  String get startServerConnectWifi =>
      'Inicie o servidor no PC e conecte os dois à mesma rede Wi-Fi.';

  @override
  String get connect => 'Conectar';

  @override
  String get computerIp => 'IP do computador';

  @override
  String get localIpValidation => 'Digite um IP local válido.';

  @override
  String get port => 'Porta';

  @override
  String get portValidation => 'Use uma porta de 1024 a 65535.';

  @override
  String get pairWithWindows => 'Parear com o Windows';

  @override
  String get scanServerQr =>
      'Aponte a câmera para o QR que aparece no servidor Windows.';

  @override
  String get volume => 'Volume';

  @override
  String get decreaseVolume => 'Diminuir';

  @override
  String get mute => 'Mudo';

  @override
  String get increaseVolume => 'Aumentar';

  @override
  String get previousTrack => 'Anterior';

  @override
  String get playPause => 'Pausar / tocar';

  @override
  String get nextTrack => 'Próxima';

  @override
  String get stop => 'Parar';

  @override
  String get sendText => 'Enviar texto';

  @override
  String get send => 'Enviar';

  @override
  String get space => 'Espaço';

  @override
  String get drag => 'Arrastar';

  @override
  String get leftClick => 'Esquerdo';

  @override
  String get middleClick => 'Meio';

  @override
  String get rightClick => 'Direito';

  @override
  String get scroll => 'Rolar';

  @override
  String get touchpad => 'Touchpad';

  @override
  String get dragToSelect => 'Arraste para selecionar';

  @override
  String get swipeToMove => 'Deslize para mover';

  @override
  String get tapToClick => 'Toque para clicar';

  @override
  String get manageComputers => 'Gerenciar computadores';

  @override
  String get copyDiagnostics => 'Copiar diagnóstico';

  @override
  String get restoreSettings => 'Restaurar configurações';

  @override
  String get restoreSettingsQuestion => 'Restaurar configurações?';

  @override
  String get pairedComputersKept => 'Os computadores pareados serão mantidos.';

  @override
  String get restore => 'Restaurar';

  @override
  String get mouseSettings => 'Mouse';

  @override
  String get mouseSettingsDescription => 'Gestos, sensibilidade e botões';

  @override
  String get connectionSettings => 'Conexão';

  @override
  String get connectionSettingsDescription =>
      'Descoberta, reconexão e segundo plano';

  @override
  String get appearanceSettings => 'Aparência e controles';

  @override
  String get appearanceSettingsDescription => 'Tema, navegação e tela';

  @override
  String get notificationPermissionBackground =>
      'Permita as notificações para manter a conexão em segundo plano.';

  @override
  String get backgroundConnectionFailed =>
      'Não foi possível ativar a conexão em segundo plano.';

  @override
  String get multiTouch => 'Multi-touch';

  @override
  String get multiTouchDescription =>
      'Dois dedos para rolar; toque com dois dedos para o botão secundário.';

  @override
  String get invertScroll => 'Inverter rolagem';

  @override
  String get swapButtons => 'Inverter botões';

  @override
  String get swapButtonsDescription =>
      'Trocar os botões primário e secundário.';

  @override
  String get limitMouseUpdates => 'Limitar atualizações do mouse';

  @override
  String get updatesPerSecond => 'Atualizações por segundo';

  @override
  String get gestureZoom => 'Zoom com gestos';

  @override
  String get gestureZoomDescription => 'Pinça para ampliar ou reduzir.';

  @override
  String get pointerSensitivity => 'Sensibilidade do ponteiro';

  @override
  String get scrollSensitivity => 'Sensibilidade da rolagem';

  @override
  String get doubleTapDrag => 'Arrastar com toque duplo';

  @override
  String get doubleTapDragDescription =>
      'Toque duas vezes e mantenha o segundo toque para arrastar.';

  @override
  String get swipeToOpenMenu => 'Abrir menu deslizando';

  @override
  String get swipeToOpenMenuDescription =>
      'Desative para evitar abrir o menu ao usar o mouse.';

  @override
  String get testMouse => 'Testar mouse';

  @override
  String get automaticDiscovery => 'Descoberta automática';

  @override
  String get automaticDiscoveryDescription =>
      'Procurar computadores na rede Wi-Fi.';

  @override
  String get updateComputerIp => 'Atualizar IP dos computadores';

  @override
  String get updateComputerIpDescription =>
      'Salvar o endereço encontrado quando o IP mudar.';

  @override
  String get automaticReconnect => 'Reconectar automaticamente';

  @override
  String get automaticReconnectDescription =>
      'Tentar novamente quando a conexão cair.';

  @override
  String get keepBackgroundConnection => 'Manter conexão em segundo plano';

  @override
  String get keepBackgroundConnectionDescription =>
      'Exibir uma notificação enquanto o PC estiver conectado.';

  @override
  String get showConnectionErrors => 'Mostrar erros de conexão';

  @override
  String get theme => 'Tema';

  @override
  String get system => 'Sistema';

  @override
  String get light => 'Claro';

  @override
  String get dark => 'Escuro';

  @override
  String get initialControl => 'Controle inicial';

  @override
  String get controlNavigation => 'Navegação dos controles';

  @override
  String get bottomBar => 'Barra inferior';

  @override
  String get sideMenu => 'Menu lateral';

  @override
  String get visibleControls => 'Controles visíveis';

  @override
  String get screenOrientation => 'Orientação da tela';

  @override
  String get automatic => 'Automática';

  @override
  String get portrait => 'Retrato';

  @override
  String get landscape => 'Paisagem';

  @override
  String get hapticFeedback => 'Retorno vibratório';

  @override
  String get hapticFeedbackDescription => 'Vibrar ao clicar e enviar comandos.';

  @override
  String get fullscreen => 'Tela inteira';

  @override
  String get fullscreenDescription => 'Ocultar as barras do sistema.';

  @override
  String get keepScreenAwake => 'Manter tela acesa';

  @override
  String get keepScreenAwakeDescription =>
      'Enquanto um controle estiver aberto.';

  @override
  String get restoreFailedKeepPairings =>
      'Não foi possível restaurar as configurações. Os computadores pareados foram mantidos.';

  @override
  String get restoreFailed => 'Não foi possível restaurar as configurações.';

  @override
  String get aboutVersion => 'Versão';

  @override
  String get unavailable => 'Indisponível';

  @override
  String get platform => 'Plataforma';

  @override
  String get license => 'Licença';

  @override
  String get project => 'Projeto';

  @override
  String get credits => 'Créditos';

  @override
  String get officialWebsite => 'Site oficial';

  @override
  String get personalGithub => 'GitHub pessoal';

  @override
  String get openLinkFailed => 'Não foi possível abrir o link.';

  @override
  String get diagnosticsCopied => 'Diagnóstico copiado.';

  @override
  String get connectToTestMouse =>
      'Conecte a um computador para testar o mouse.';

  @override
  String get forgetComputerFailed => 'Não foi possível esquecer o computador.';

  @override
  String get discoverComputersFailed => 'Falha ao procurar computadores.';

  @override
  String get connectionFailed =>
      'Não foi possível conectar. Verifique se o PC está disponível na rede e tente novamente.';

  @override
  String get noConnection => 'Nenhum PC está conectado.';

  @override
  String get accessLocalNetwork =>
      'Permita o acesso à rede local para conectar ao PC.';

  @override
  String get serverPairApproval =>
      'Aprove o pedido de conexão no computador Windows.';

  @override
  String get savedAuthorizationRemoved =>
      'O PC removeu a autorização deste celular. Solicite uma nova conexão.';

  @override
  String get savedComputerNeedsPairing =>
      'Este computador precisa ser pareado novamente.';

  @override
  String get pairingQrExpired =>
      'O QR de pareamento expirou. Gere outro no Windows.';

  @override
  String get accessDenied =>
      'Acesso recusado. Gere um novo QR ou confira se este celular ainda está pareado.';

  @override
  String get serverRefusedPairing => 'O servidor recusou o pareamento.';

  @override
  String get serverClosedConnection => 'O PC encerrou a conexão.';

  @override
  String get connectionLost => 'Conexão perdida. Verifique a rede e reconecte.';

  @override
  String get networkTimeout =>
      'O PC não respondeu dentro do prazo. Verifique o firewall e o isolamento de clientes no roteador.';

  @override
  String get networkFailure =>
      'Não foi possível alcançar o PC. Confira se o servidor está ativo e se o Firewall do Windows permite a conexão.';

  @override
  String get identityMismatch =>
      'A identidade do servidor não corresponde ao QR escaneado.';

  @override
  String get handshakeInvalid =>
      'O servidor enviou uma resposta de segurança inválida.';

  @override
  String get authenticationInvalid =>
      'O servidor enviou um desafio de autenticação inválido.';

  @override
  String get serverDescriptorInvalid =>
      'O IP e a porta não responderam como servidor Open Remote.';

  @override
  String get serverIdentityInvalid =>
      'O servidor enviou dados de identificação inválidos.';

  @override
  String get updateTitle => 'Atualizações';

  @override
  String installedVersion(String version) {
    return 'Versão instalada: $version';
  }

  @override
  String availableVersion(String version) {
    return 'Versão disponível: $version';
  }

  @override
  String downloadSize(String size) {
    return 'Download: $size MB';
  }

  @override
  String get releaseNotes => 'Notas da versão';

  @override
  String get checkForUpdates => 'Verificar atualizações';

  @override
  String get tryAgain => 'Tentar novamente';

  @override
  String get updateNow => 'Atualizar';

  @override
  String get notNow => 'Agora não';

  @override
  String get cancelUpdate => 'Cancelar atualização';

  @override
  String get installUpdate => 'Instalar atualização';

  @override
  String get allowInstall => 'Permitir instalação';

  @override
  String get viewUpdate => 'Ver atualização';

  @override
  String updateAvailableNotice(String version) {
    return 'Atualização $version disponível';
  }

  @override
  String get updateChecking => 'Verificando atualizações…';

  @override
  String get updateUpToDate =>
      'Você está na versão mais recente para este dispositivo.';

  @override
  String get updateAvailable => 'Atualização disponível.';

  @override
  String get updateDeferred =>
      'Atualização adiada até abrir o aplicativo novamente.';

  @override
  String get updateDownloading => 'Baixando atualização…';

  @override
  String get updateValidating => 'Validando o APK…';

  @override
  String get updateReady => 'APK validado. Pronto para instalar.';

  @override
  String get updateInstalling =>
      'Confirme a atualização no instalador do Android.';

  @override
  String get updateCancelled => 'Download cancelado.';

  @override
  String get updateInstallationCancelled =>
      'Instalação cancelada. Você pode tentar novamente.';

  @override
  String get updatePermissionRequired =>
      'Para instalar a atualização, permita que o Open Remote Control instale aplicativos na configuração do Android. Depois, volte aqui para continuar.';

  @override
  String get updateNetworkError =>
      'Falha de conexão. Verifique a internet e tente novamente.';

  @override
  String get updateUnavailableError =>
      'O arquivo da atualização não está disponível. Verifique novamente.';

  @override
  String get updateStorageError =>
      'Sem espaço suficiente. Libere espaço e tente novamente.';

  @override
  String get updateIntegrityError =>
      'O APK está incompleto ou corrompido. Baixe novamente.';

  @override
  String get updateIdentityError =>
      'O APK não pertence a este aplicativo. A instalação foi bloqueada.';

  @override
  String get updateSignatureError =>
      'A assinatura do APK não corresponde à versão instalada. A instalação foi bloqueada.';

  @override
  String get updateIncompatibleError =>
      'O APK não é compatível com este dispositivo.';

  @override
  String get updateInvalidPackageError =>
      'Não foi possível validar o APK. Baixe novamente.';

  @override
  String get updatePermissionError =>
      'A instalação não foi autorizada. Você pode continuar usando o aplicativo.';

  @override
  String get updateInstallerError =>
      'Não foi possível iniciar a instalação. Tente novamente.';

  @override
  String get updateInterruptedError =>
      'O download foi interrompido. Baixe novamente para continuar.';

  @override
  String get updateBusyError => 'Já existe uma atualização em andamento.';

  @override
  String get updateGenericError =>
      'Não foi possível atualizar. Tente novamente.';

  @override
  String get notificationDownloading => 'Baixando atualização';

  @override
  String get notificationValidating => 'Validando atualização';

  @override
  String get notificationReady => 'Atualização pronta para instalar';

  @override
  String get notificationChannel => 'Atualizações do aplicativo';

  @override
  String get rawError =>
      'Ocorreu um erro. Verifique a conexão e tente novamente.';

  @override
  String get pairingExpired =>
      'O pedido de pareamento expirou. Gere um novo QR no Windows.';

  @override
  String get pairingLimit =>
      'O servidor atingiu o limite de pareamentos. Remova um dispositivo antigo no Windows e tente novamente.';

  @override
  String get requestPending =>
      'Já existe um pedido de conexão aguardando aprovação no Windows.';

  @override
  String get pairingRejected => 'O pedido de conexão foi recusado no Windows.';

  @override
  String get authorizationRevoked =>
      'Este celular não está mais autorizado. Solicite uma nova conexão.';

  @override
  String get invalidAuthorization =>
      'A autorização salva é inválida. Pareie este celular novamente.';

  @override
  String get invalidQr =>
      'Este QR é inválido ou expirou. Escaneie um QR atual de pareamento do Open Remote.';

  @override
  String get secureConnectionFailed =>
      'Não foi possível estabelecer uma conexão segura com o PC. Confira se selecionou o computador correto e tente novamente.';

  @override
  String get preferencesReadFailed => 'Não foi possível ler as preferências.';

  @override
  String get saveFailed => 'Não foi possível salvar as configurações.';

  @override
  String get cameraStarting => 'Iniciando câmera…';

  @override
  String get cameraPermission =>
      'Permita o acesso à câmera nas configurações do Android e abra o leitor novamente.';

  @override
  String get cameraUnavailable =>
      'Não foi possível abrir a câmera. Tente novamente ou conecte ao PC por IP.';
}

/// The translations for Portuguese, as used in Brazil (`pt_BR`).
class AppLocalizationsPtBr extends AppLocalizationsPt {
  AppLocalizationsPtBr() : super('pt_BR');

  @override
  String get appTitle => 'Open Remote';

  @override
  String get language => 'Idioma';

  @override
  String get languageEnglish => 'English';

  @override
  String get languagePortuguese => 'Português (Brasil)';

  @override
  String get computers => 'Computadores';

  @override
  String get settings => 'Configurações';

  @override
  String get about => 'Sobre';

  @override
  String get mouse => 'Mouse';

  @override
  String get media => 'Mídia';

  @override
  String get keyboard => 'Teclado';

  @override
  String forgetHostTitle(String name) {
    return 'Esquecer $name?';
  }

  @override
  String get forgetHostBody =>
      'Será necessário autorizar este celular novamente para conectar.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get forget => 'Esquecer';

  @override
  String get reconnecting => 'Reconectando…';

  @override
  String get disconnected => 'Desconectado';

  @override
  String get reconnect => 'Reconectar';

  @override
  String get disconnect => 'Desconectar';

  @override
  String get searchComputers => 'Procurar computadores';

  @override
  String get addComputer => 'Adicionar computador';

  @override
  String get scanQr => 'Escanear QR';

  @override
  String get connectByIp => 'Conectar por IP';

  @override
  String get computerOptions => 'Opções do computador';

  @override
  String get connected => 'Conectado';

  @override
  String get paired => 'Pareado';

  @override
  String get available => 'Disponível';

  @override
  String get openControls => 'Abrir controles';

  @override
  String get requestConnection => 'Solicitar conexão';

  @override
  String get forgetComputer => 'Esquecer computador';

  @override
  String get connecting => 'Conectando…';

  @override
  String get searchingComputers => 'Procurando computadores…';

  @override
  String get noComputersFound => 'Nenhum computador encontrado';

  @override
  String get startServerConnectWifi =>
      'Inicie o servidor no PC e conecte os dois à mesma rede Wi-Fi.';

  @override
  String get connect => 'Conectar';

  @override
  String get computerIp => 'IP do computador';

  @override
  String get localIpValidation => 'Digite um IP local válido.';

  @override
  String get port => 'Porta';

  @override
  String get portValidation => 'Use uma porta de 1024 a 65535.';

  @override
  String get pairWithWindows => 'Parear com o Windows';

  @override
  String get scanServerQr =>
      'Aponte a câmera para o QR que aparece no servidor Windows.';

  @override
  String get volume => 'Volume';

  @override
  String get decreaseVolume => 'Diminuir';

  @override
  String get mute => 'Mudo';

  @override
  String get increaseVolume => 'Aumentar';

  @override
  String get previousTrack => 'Anterior';

  @override
  String get playPause => 'Pausar / tocar';

  @override
  String get nextTrack => 'Próxima';

  @override
  String get stop => 'Parar';

  @override
  String get sendText => 'Enviar texto';

  @override
  String get send => 'Enviar';

  @override
  String get space => 'Espaço';

  @override
  String get drag => 'Arrastar';

  @override
  String get leftClick => 'Esquerdo';

  @override
  String get middleClick => 'Meio';

  @override
  String get rightClick => 'Direito';

  @override
  String get scroll => 'Rolar';

  @override
  String get touchpad => 'Touchpad';

  @override
  String get dragToSelect => 'Arraste para selecionar';

  @override
  String get swipeToMove => 'Deslize para mover';

  @override
  String get tapToClick => 'Toque para clicar';

  @override
  String get manageComputers => 'Gerenciar computadores';

  @override
  String get copyDiagnostics => 'Copiar diagnóstico';

  @override
  String get restoreSettings => 'Restaurar configurações';

  @override
  String get restoreSettingsQuestion => 'Restaurar configurações?';

  @override
  String get pairedComputersKept => 'Os computadores pareados serão mantidos.';

  @override
  String get restore => 'Restaurar';

  @override
  String get mouseSettings => 'Mouse';

  @override
  String get mouseSettingsDescription => 'Gestos, sensibilidade e botões';

  @override
  String get connectionSettings => 'Conexão';

  @override
  String get connectionSettingsDescription =>
      'Descoberta, reconexão e segundo plano';

  @override
  String get appearanceSettings => 'Aparência e controles';

  @override
  String get appearanceSettingsDescription => 'Tema, navegação e tela';

  @override
  String get notificationPermissionBackground =>
      'Permita as notificações para manter a conexão em segundo plano.';

  @override
  String get backgroundConnectionFailed =>
      'Não foi possível ativar a conexão em segundo plano.';

  @override
  String get multiTouch => 'Multi-touch';

  @override
  String get multiTouchDescription =>
      'Dois dedos para rolar; toque com dois dedos para o botão secundário.';

  @override
  String get invertScroll => 'Inverter rolagem';

  @override
  String get swapButtons => 'Inverter botões';

  @override
  String get swapButtonsDescription =>
      'Trocar os botões primário e secundário.';

  @override
  String get limitMouseUpdates => 'Limitar atualizações do mouse';

  @override
  String get updatesPerSecond => 'Atualizações por segundo';

  @override
  String get gestureZoom => 'Zoom com gestos';

  @override
  String get gestureZoomDescription => 'Pinça para ampliar ou reduzir.';

  @override
  String get pointerSensitivity => 'Sensibilidade do ponteiro';

  @override
  String get scrollSensitivity => 'Sensibilidade da rolagem';

  @override
  String get doubleTapDrag => 'Arrastar com toque duplo';

  @override
  String get doubleTapDragDescription =>
      'Toque duas vezes e mantenha o segundo toque para arrastar.';

  @override
  String get swipeToOpenMenu => 'Abrir menu deslizando';

  @override
  String get swipeToOpenMenuDescription =>
      'Desative para evitar abrir o menu ao usar o mouse.';

  @override
  String get testMouse => 'Testar mouse';

  @override
  String get automaticDiscovery => 'Descoberta automática';

  @override
  String get automaticDiscoveryDescription =>
      'Procurar computadores na rede Wi-Fi.';

  @override
  String get updateComputerIp => 'Atualizar IP dos computadores';

  @override
  String get updateComputerIpDescription =>
      'Salvar o endereço encontrado quando o IP mudar.';

  @override
  String get automaticReconnect => 'Reconectar automaticamente';

  @override
  String get automaticReconnectDescription =>
      'Tentar novamente quando a conexão cair.';

  @override
  String get keepBackgroundConnection => 'Manter conexão em segundo plano';

  @override
  String get keepBackgroundConnectionDescription =>
      'Exibir uma notificação enquanto o PC estiver conectado.';

  @override
  String get showConnectionErrors => 'Mostrar erros de conexão';

  @override
  String get theme => 'Tema';

  @override
  String get system => 'Sistema';

  @override
  String get light => 'Claro';

  @override
  String get dark => 'Escuro';

  @override
  String get initialControl => 'Controle inicial';

  @override
  String get controlNavigation => 'Navegação dos controles';

  @override
  String get bottomBar => 'Barra inferior';

  @override
  String get sideMenu => 'Menu lateral';

  @override
  String get visibleControls => 'Controles visíveis';

  @override
  String get screenOrientation => 'Orientação da tela';

  @override
  String get automatic => 'Automática';

  @override
  String get portrait => 'Retrato';

  @override
  String get landscape => 'Paisagem';

  @override
  String get hapticFeedback => 'Retorno vibratório';

  @override
  String get hapticFeedbackDescription => 'Vibrar ao clicar e enviar comandos.';

  @override
  String get fullscreen => 'Tela inteira';

  @override
  String get fullscreenDescription => 'Ocultar as barras do sistema.';

  @override
  String get keepScreenAwake => 'Manter tela acesa';

  @override
  String get keepScreenAwakeDescription =>
      'Enquanto um controle estiver aberto.';

  @override
  String get restoreFailedKeepPairings =>
      'Não foi possível restaurar as configurações. Os computadores pareados foram mantidos.';

  @override
  String get restoreFailed => 'Não foi possível restaurar as configurações.';

  @override
  String get aboutVersion => 'Versão';

  @override
  String get unavailable => 'Indisponível';

  @override
  String get platform => 'Plataforma';

  @override
  String get license => 'Licença';

  @override
  String get project => 'Projeto';

  @override
  String get credits => 'Créditos';

  @override
  String get officialWebsite => 'Site oficial';

  @override
  String get personalGithub => 'GitHub pessoal';

  @override
  String get openLinkFailed => 'Não foi possível abrir o link.';

  @override
  String get diagnosticsCopied => 'Diagnóstico copiado.';

  @override
  String get connectToTestMouse =>
      'Conecte a um computador para testar o mouse.';

  @override
  String get forgetComputerFailed => 'Não foi possível esquecer o computador.';

  @override
  String get discoverComputersFailed => 'Falha ao procurar computadores.';

  @override
  String get connectionFailed =>
      'Não foi possível conectar. Verifique se o PC está disponível na rede e tente novamente.';

  @override
  String get noConnection => 'Nenhum PC está conectado.';

  @override
  String get accessLocalNetwork =>
      'Permita o acesso à rede local para conectar ao PC.';

  @override
  String get serverPairApproval =>
      'Aprove o pedido de conexão no computador Windows.';

  @override
  String get savedAuthorizationRemoved =>
      'O PC removeu a autorização deste celular. Solicite uma nova conexão.';

  @override
  String get savedComputerNeedsPairing =>
      'Este computador precisa ser pareado novamente.';

  @override
  String get pairingQrExpired =>
      'O QR de pareamento expirou. Gere outro no Windows.';

  @override
  String get accessDenied =>
      'Acesso recusado. Gere um novo QR ou confira se este celular ainda está pareado.';

  @override
  String get serverRefusedPairing => 'O servidor recusou o pareamento.';

  @override
  String get serverClosedConnection => 'O PC encerrou a conexão.';

  @override
  String get connectionLost => 'Conexão perdida. Verifique a rede e reconecte.';

  @override
  String get networkTimeout =>
      'O PC não respondeu dentro do prazo. Verifique o firewall e o isolamento de clientes no roteador.';

  @override
  String get networkFailure =>
      'Não foi possível alcançar o PC. Confira se o servidor está ativo e se o Firewall do Windows permite a conexão.';

  @override
  String get identityMismatch =>
      'A identidade do servidor não corresponde ao QR escaneado.';

  @override
  String get handshakeInvalid =>
      'O servidor enviou uma resposta de segurança inválida.';

  @override
  String get authenticationInvalid =>
      'O servidor enviou um desafio de autenticação inválido.';

  @override
  String get serverDescriptorInvalid =>
      'O IP e a porta não responderam como servidor Open Remote.';

  @override
  String get serverIdentityInvalid =>
      'O servidor enviou dados de identificação inválidos.';

  @override
  String get updateTitle => 'Atualizações';

  @override
  String installedVersion(String version) {
    return 'Versão instalada: $version';
  }

  @override
  String availableVersion(String version) {
    return 'Versão disponível: $version';
  }

  @override
  String downloadSize(String size) {
    return 'Download: $size MB';
  }

  @override
  String get releaseNotes => 'Notas da versão';

  @override
  String get checkForUpdates => 'Verificar atualizações';

  @override
  String get tryAgain => 'Tentar novamente';

  @override
  String get updateNow => 'Atualizar';

  @override
  String get notNow => 'Agora não';

  @override
  String get cancelUpdate => 'Cancelar atualização';

  @override
  String get installUpdate => 'Instalar atualização';

  @override
  String get allowInstall => 'Permitir instalação';

  @override
  String get viewUpdate => 'Ver atualização';

  @override
  String updateAvailableNotice(String version) {
    return 'Atualização $version disponível';
  }

  @override
  String get updateChecking => 'Verificando atualizações…';

  @override
  String get updateUpToDate =>
      'Você está na versão mais recente para este dispositivo.';

  @override
  String get updateAvailable => 'Atualização disponível.';

  @override
  String get updateDeferred =>
      'Atualização adiada até abrir o aplicativo novamente.';

  @override
  String get updateDownloading => 'Baixando atualização…';

  @override
  String get updateValidating => 'Validando o APK…';

  @override
  String get updateReady => 'APK validado. Pronto para instalar.';

  @override
  String get updateInstalling =>
      'Confirme a atualização no instalador do Android.';

  @override
  String get updateCancelled => 'Download cancelado.';

  @override
  String get updateInstallationCancelled =>
      'Instalação cancelada. Você pode tentar novamente.';

  @override
  String get updatePermissionRequired =>
      'Para instalar a atualização, permita que o Open Remote Control instale aplicativos na configuração do Android. Depois, volte aqui para continuar.';

  @override
  String get updateNetworkError =>
      'Falha de conexão. Verifique a internet e tente novamente.';

  @override
  String get updateUnavailableError =>
      'O arquivo da atualização não está disponível. Verifique novamente.';

  @override
  String get updateStorageError =>
      'Sem espaço suficiente. Libere espaço e tente novamente.';

  @override
  String get updateIntegrityError =>
      'O APK está incompleto ou corrompido. Baixe novamente.';

  @override
  String get updateIdentityError =>
      'O APK não pertence a este aplicativo. A instalação foi bloqueada.';

  @override
  String get updateSignatureError =>
      'A assinatura do APK não corresponde à versão instalada. A instalação foi bloqueada.';

  @override
  String get updateIncompatibleError =>
      'O APK não é compatível com este dispositivo.';

  @override
  String get updateInvalidPackageError =>
      'Não foi possível validar o APK. Baixe novamente.';

  @override
  String get updatePermissionError =>
      'A instalação não foi autorizada. Você pode continuar usando o aplicativo.';

  @override
  String get updateInstallerError =>
      'Não foi possível iniciar a instalação. Tente novamente.';

  @override
  String get updateInterruptedError =>
      'O download foi interrompido. Baixe novamente para continuar.';

  @override
  String get updateBusyError => 'Já existe uma atualização em andamento.';

  @override
  String get updateGenericError =>
      'Não foi possível atualizar. Tente novamente.';

  @override
  String get notificationDownloading => 'Baixando atualização';

  @override
  String get notificationValidating => 'Validando atualização';

  @override
  String get notificationReady => 'Atualização pronta para instalar';

  @override
  String get notificationChannel => 'Atualizações do aplicativo';

  @override
  String get rawError =>
      'Ocorreu um erro. Verifique a conexão e tente novamente.';

  @override
  String get pairingExpired =>
      'O pedido de pareamento expirou. Gere um novo QR no Windows.';

  @override
  String get pairingLimit =>
      'O servidor atingiu o limite de pareamentos. Remova um dispositivo antigo no Windows e tente novamente.';

  @override
  String get requestPending =>
      'Já existe um pedido de conexão aguardando aprovação no Windows.';

  @override
  String get pairingRejected => 'O pedido de conexão foi recusado no Windows.';

  @override
  String get authorizationRevoked =>
      'Este celular não está mais autorizado. Solicite uma nova conexão.';

  @override
  String get invalidAuthorization =>
      'A autorização salva é inválida. Pareie este celular novamente.';

  @override
  String get invalidQr =>
      'Este QR é inválido ou expirou. Escaneie um QR atual de pareamento do Open Remote.';

  @override
  String get secureConnectionFailed =>
      'Não foi possível estabelecer uma conexão segura com o PC. Confira se selecionou o computador correto e tente novamente.';

  @override
  String get preferencesReadFailed => 'Não foi possível ler as preferências.';

  @override
  String get saveFailed => 'Não foi possível salvar as configurações.';

  @override
  String get cameraStarting => 'Iniciando câmera…';

  @override
  String get cameraPermission =>
      'Permita o acesso à câmera nas configurações do Android e abra o leitor novamente.';

  @override
  String get cameraUnavailable =>
      'Não foi possível abrir a câmera. Tente novamente ou conecte ao PC por IP.';
}
