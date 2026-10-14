<p align="center">
  <a href="https://openremotecontrol.sourceforge.io/">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="app/assets/branding/mark-light.svg">
    <img src="app/assets/branding/mark.svg" width="64" height="64" alt="Open Remote Control logo">
  </picture>
  </a>
</p>

<h1 align="center"><a href="https://openremotecontrol.sourceforge.io/">Open Remote Control</a></h1>

<p align="center">Use your Android phone as a mouse, keyboard and media remote for Windows.</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0--only-3C9827" alt="GPL-3.0-only license"></a>
  <img src="https://img.shields.io/badge/Windows-x64-0078D4" alt="Windows x64">
  <img src="https://img.shields.io/badge/Android-7.0%2B-3C9827" alt="Android 7.0 or later">
</p>

<p align="center">
  <a href="https://github.com/leobrqz/OpenRemoteControl/releases/latest"><img src="https://img.shields.io/badge/Download-GitHub-24292f?style=for-the-badge&amp;logo=github&amp;logoColor=white" alt="Download from GitHub" height="36"></a>
  <a href="https://sourceforge.net/projects/openremotecontrol/files/latest/download"><img src="https://a.fsdn.com/con/app/sf-download-button" alt="Download OpenRemoteControl" height="36"></a>
</p>

## Controls

- **Mouse:** trackpad, clicks, dragging, two-finger scrolling and pinch zoom.
- **Keyboard:** text, function keys and shortcuts.
- **Media:** volume, mute, play/pause and previous/next track.

The Android menu includes saved mouse, connection, theme and display settings.

Android and the Windows dashboard default to US English. Choose **English** or **Português (Brasil)** in the sidebar footer (below **About** on Android); changes apply immediately without disconnecting. Android saves its choice in the app; the dashboard saves it in the current browser profile.

## Build

On Windows, install Flutter, the Android SDK, Node.js, the .NET SDK (build only) and Visual Studio's **Desktop development with C++** workload. Velopack SDK and CLI are pinned to 1.2.161. From the repository root:

```powershell
.\scripts\build_windows.ps1
.\scripts\build_android.ps1
```

Packages and SHA-256 checksums are written to `output/windows/` and `output/android/`.

## Repository

| Path | Purpose |
| --- | --- |
| `app/` | Android Flutter client: views, view models and repositories |
| `web/src/` | Browser dashboard; `npm run build` in `web/` produces `web/dist/` |
| `web/server/` | Windows background host, tray and native input integration |
| `packages/remote_core/` | Shared Dart protocol, encryption and diagnostics |
| `site/` | Static project website; `npm run dev` previews it locally |

Android and Windows have separate dependencies and builds. The Windows ZIP includes the dashboard.

Run `npm run dev` from `site/` to preview the website at `http://127.0.0.1:4173/`.

For dashboard development, start the Windows app and run `npm run dev` from `web/`. Open `http://127.0.0.1:5173/`; source changes reload automatically and API requests use the running Windows dashboard. Set `ORC_DASHBOARD_URL` if its loopback port differs from 47654.

## Connect

1. Extract the Windows ZIP into a user-writable directory and run its root `Open Remote Control.exe` launcher. Double-click its tray icon to open the dashboard in your browser.
2. Install the Android APK and connect both devices to the same local network.
3. Select the discovered PC and approve the phone in the dashboard, or scan the pairing QR. Access is saved for future connections.

Windows checks for updates after startup; approve downloading and restarting under **About > Updates** in the dashboard. From 0.2.1, stop the old server and extract the first managed ZIP into a new user-writable directory. Identity and paired phones are retained.
Keep the managed directory in place: updates retain the executable path and its existing Windows Firewall authorization.

Android checks for compatible updates on startup and in **About > Updates**. Downloads require approval, can continue in the background, and can be cancelled. Android asks for installation permission and confirmation; updating preserves saved PCs and settings. Google Play and a Google account are not required.
