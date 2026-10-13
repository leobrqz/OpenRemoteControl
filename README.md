# Open Remote Control

Controle remoto open source para usar um celular Android como mouse, teclado e controle de mídia de um PC Windows. A comunicação usa a rede Wi-Fi local; o projeto não usa Bluetooth nem serviços de nuvem.

## Uso

1. Extraia `output/windows/OpenRemoteControl-Windows-x64.zip` e abra `open_remote_control.exe`.
2. O servidor inicia automaticamente e fica na bandeja do Windows. Clique duas vezes no ícone para abrir o painel local no navegador; clique com o botão direito para abrir o painel ou sair.
3. Abra o APK em `output/android/` no celular. O PC aparece pela busca local; solicite o primeiro pareamento e aprove o celular no painel do Windows. Depois disso, a autorização fica salva no aparelho.

O painel de configuração aceita pedidos de conexão, mostra celulares autorizados, controla o servidor e copia os diagnósticos. Ele só escuta em `127.0.0.1` neste PC. No celular, a porta padrão é detectada automaticamente; a conexão manual por IPv4 local e porta está disponível como alternativa. QR também permanece disponível como opção.

Descoberta usa UDP `47653`; comandos e conexão usam TCP `47652`. Na primeira execução, aceite o pedido do Firewall para redes privadas se ele aparecer.

## Recursos do MVP

- Mouse: movimento, botões esquerdo/direito/meio, arrasto e rolagem.
- Teclado: texto, teclas comuns, teclas de função e modificadores para atalhos.
- Mídia e áudio: volume, mudo, tocar/pausar, faixa seguinte e anterior.
- Pareamento persistente, aprovação inicial no Windows e revogação de aparelhos.
- Diagnóstico detalhado em `%LOCALAPPDATA%\OpenRemoteControl\logs\open-remote.log` no Windows e exportação pelo app Android.

O Android exige API 24 ou mais recente (Android 7.0+). O APK é universal. A compilação Android local usa a chave de debug do Flutter; ela serve para instalação manual, mas não para publicação ou atualizações pela Play Store.

## Estrutura

- `app/` — aplicativo Flutter para Windows e Android.
- `scripts/build_windows.ps1` — cria o ZIP Windows x64 e o checksum em `output/windows/`.
- `scripts/build_android.ps1` — cria o APK universal e o checksum em `output/android/`.
- `LICENSE` — GNU GPL versão 3.0 somente.

## Compilar

No PowerShell, com Flutter, Node.js/npm e os componentes de build do Windows instalados, a partir da raiz do repositório:

```powershell
.\scripts\build_windows.ps1
.\scripts\build_android.ps1
```

O protocolo e a interface do aplicativo são próprios deste projeto, sob GPL-3.0-only. O painel usa Tailwind CSS e daisyUI, servidos localmente pelo executável. A página de funcionalidades do Unified Remote foi usada como referência de escopo e experiência, sem reutilizar código ou recursos do produto: [Unified Remote — Features](https://www.unifiedremote.com/features).
