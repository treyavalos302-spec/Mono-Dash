# Mono Dash

Language: English | [简体中文](README.zh-CN.md)

Mono Dash is an open-source, third-party mobile management client for
[1Panel](https://github.com/1Panel-dev/1Panel).

Connect to your own 1Panel servers and manage daily operations from your phone
with a focused, native interface.

[![Download on the App Store](https://img.shields.io/badge/Download_on_the-App_Store-0D0D0D?style=for-the-badge&logo=apple&logoColor=white)](https://apps.apple.com/app/mono-dash-made-for-1panel/id6766814493)
[![Get it on Google Play](https://img.shields.io/badge/Get_it_on-Google_Play-0D0D0D?style=for-the-badge&logo=googleplay&logoColor=white)](https://play.google.com/store/apps/details?id=cc.boring_lab.monodash)

> Mono Dash is an independent third-party client. It is not an official 1Panel
> product and is not affiliated with, endorsed by, or sponsored by 1Panel.

<p>
  <img src="store_assets/Appstore/app-store-poster-1284x2778_en.png" width="160" alt="Mono Dash App Store screenshot">
  <img src="store_assets/Appstore/mobile-1panel-poster-1284x2778_en.png" width="160" alt="Mobile 1Panel management screenshot">
  <img src="store_assets/Appstore/multi-server-poster-1284x2778_en.png" width="160" alt="Multi-server management screenshot">
  <img src="store_assets/Appstore/server-files-poster-1284x2778_en.png" width="160" alt="Server files screenshot">
  <img src="store_assets/Appstore/docker-containers-poster-1284x2778_en.png" width="160" alt="Docker containers screenshot">
  <img src="store_assets/Appstore/feature-map-poster-1284x2778_en.png" width="160" alt="Feature map screenshot">
</p>

## Features

- Monitor CPU, memory, disk, network traffic, load, uptime, and host details
- Manage websites, domains, HTTPS certificates, logs, and website configuration
- Browse, upload, download, edit, move, compress, decompress, share, and delete
  server files
- Work with databases, containers, images, compose projects, and app updates
- View system, login, operation, SSH, website, container, and task logs
- Open terminal sessions and manage SSH-related settings
- Manage backups, snapshots, cron jobs, firewall rules, processes, runtimes, and
  toolbox tasks
- Add multiple 1Panel servers and switch between them from a mobile-first
  interface

## Open Source

Mono Dash is developed as an open-source project. You can review the source
code, follow development, report issues, and contribute through this repository.

- Source code: <https://github.com/bin64/Mono-Dash>
- Issues: <https://github.com/bin64/Mono-Dash/issues>

## Free and In-App Purchase

The free version lets you add and manage one 1Panel server.

Mono Dash Unlimited is an optional one-time in-app purchase that unlocks
unlimited server management and future premium features where available.
Purchases are processed by the App Store or Google Play where applicable and
can be restored in the app.

## Privacy and Data

Mono Dash stores server connection settings on your device and connects directly
to the 1Panel servers you configure. Mono Dash does not operate a backend for
collecting your 1Panel server data.

Purchase status may be processed through Apple, Google Play, and RevenueCat for
entitlement management, depending on the platform and distribution channel.

Read the full policies:

- [Privacy Policy](PRIVACY.md) | [隐私政策](PRIVACY.zh-CN.md)
- [Terms of Use](TERMS.md) | [使用条款](TERMS.zh-CN.md)

## Important Notice

Use Mono Dash only with servers you own, administer, or are authorized to
access. Server management actions can affect websites, databases, containers,
files, backups, firewall rules, scheduled jobs, and other production resources.
Review destructive operations carefully and keep independent backups of
important data.

Mono Dash depends on the 1Panel API and may not be compatible with every 1Panel
version, plugin, server configuration, or deployment environment.

## Development

This repository contains the Flutter client source code.

### Requirements

- Flutter SDK with Dart compatible with `^3.11.1`
- Xcode for iOS builds
- Android Studio and Android SDK for Android builds

### Run Locally

```bash
flutter pub get
flutter run
```

### Checks

```bash
flutter analyze
flutter test
```

## Project Links

- Repository: <https://github.com/bin64/Mono-Dash>
- Privacy Policy: <https://github.com/bin64/Mono-Dash/blob/main/PRIVACY.md>
- Terms of Use: <https://github.com/bin64/Mono-Dash/blob/main/TERMS.md>
- 1Panel: <https://github.com/1Panel-dev/1Panel>

## License

This project is licensed under the GNU General Public License v3.0. See
[LICENSE](LICENSE) for details.
