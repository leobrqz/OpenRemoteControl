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

## Controls

- **Mouse:** trackpad, left/right/middle clicks, dragging and scrolling.
- **Keyboard:** text, function keys and shortcuts.
- **Media:** volume, mute, play/pause and previous/next track.

## Build

On Windows, install Flutter, the Android SDK, Node.js and Visual Studio's **Desktop development with C++** workload. From the repository root:

```powershell
.\scripts\build_windows.ps1
.\scripts\build_android.ps1
```

Packages and SHA-256 checksums are written to `output/windows/` and `output/android/`.
Package names include the version from `app/pubspec.yaml`; the Windows dashboard shows it under **About**.

## Releases

Update `app/pubspec.yaml` and increment its build number. Commit, then push an annotated `vMAJOR.MINOR.PATCH` tag with an English title and short changelog in its message. GitHub Actions builds both packages, verifies their versions and publishes the release with checksums. The Android signing key is stored in a repository secret to preserve updates.

## Connect

1. Extract the Windows ZIP and run `open_remote_control.exe`. Double-click its tray icon to open the dashboard in your browser.
2. Install the Android APK and connect both devices to the same local network.
3. Select the discovered PC and approve the phone in the dashboard, or scan the pairing QR. Access is saved for future connections.
