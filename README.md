<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="app/assets/branding/mark-light.svg">
    <img src="app/assets/branding/mark.svg" width="64" height="64" alt="Open Remote Control logo">
  </picture>
</p>

<h1 align="center">Open Remote Control</h1>

<p align="center">Use your Android phone as a mouse, keyboard and media remote for Windows.</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0--only-3C9827" alt="GPL-3.0-only license"></a>
  <img src="https://img.shields.io/badge/Windows-x64-0078D4" alt="Windows x64">
  <img src="https://img.shields.io/badge/Android-7.0%2B-3C9827" alt="Android 7.0 or later">
</p>

[Download APK and Windows server](https://github.com/leobrqz/OpenRemoteControl/releases/latest)

## Controls

- **Mouse:** trackpad, clicks, dragging, two-finger scrolling and pinch zoom.
- **Keyboard:** text, function keys and shortcuts.
- **Media:** volume, mute, play/pause and previous/next track.

The Android menu includes saved mouse, connection, theme and display settings.

## Build

On Windows, install Flutter, the Android SDK, Node.js and Visual Studio's **Desktop development with C++** workload. From the repository root:

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

Android and Windows have separate dependencies and builds. The Windows ZIP includes the dashboard.

## Connect

1. Extract the Windows ZIP and run `open_remote_control.exe`. Double-click its tray icon to open the dashboard in your browser.
2. Install the Android APK and connect both devices to the same local network.
3. Select the discovered PC and approve the phone in the dashboard, or scan the pairing QR. Access is saved for future connections.
