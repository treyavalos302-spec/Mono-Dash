# Mono Dash

语言：[English](README.md) | 简体中文

Mono Dash 是一个开源的 1Panel 第三方移动端管理客户端。

你可以连接自己拥有或有权管理的 1Panel 服务器，并在手机上通过更聚焦的原生界面完成日常运维操作。

[![Download on the App Store](https://img.shields.io/badge/Download_on_the-App_Store-0D0D0D?style=for-the-badge&logo=apple&logoColor=white)](https://apps.apple.com/app/mono-dash-made-for-1panel/id6766814493)
[![Get it on Google Play](https://img.shields.io/badge/Get_it_on-Google_Play-0D0D0D?style=for-the-badge&logo=googleplay&logoColor=white)](https://play.google.com/store/apps/details?id=cc.boring_lab.monodash)

> Mono Dash 是独立的第三方客户端，不是 1Panel 官方产品，也不隶属于、
> 不代表、不受 1Panel 认可或赞助。

<p>
  <img src="store_assets/Appstore/app-store-poster-1284x2778_zh.png" width="160" alt="Mono Dash App Store 截图">
  <img src="store_assets/Appstore/mobile-1panel-poster-1284x2778_zh.png" width="160" alt="移动端 1Panel 管理截图">
  <img src="store_assets/Appstore/multi-server-poster-1284x2778_zh.png" width="160" alt="多服务器管理截图">
  <img src="store_assets/Appstore/server-files-poster-1284x2778_zh.png" width="160" alt="服务器文件管理截图">
  <img src="store_assets/Appstore/docker-containers-poster-1284x2778_zh.png" width="160" alt="Docker 容器管理截图">
  <img src="store_assets/Appstore/feature-map-poster-1284x2778_zh.png" width="160" alt="功能地图截图">
</p>

## 功能特性

- 监控 CPU、内存、磁盘、网络流量、负载、运行时间和主机信息
- 管理网站、域名、HTTPS 证书、日志和网站配置
- 浏览、上传、下载、编辑、移动、压缩、解压、分享和删除服务器文件
- 管理数据库、容器、镜像、Compose 项目和应用更新
- 查看系统日志、登录日志、操作日志、SSH 日志、网站日志、容器日志和任务日志
- 打开终端会话，并管理 SSH 相关设置
- 管理备份、快照、计划任务、防火墙规则、进程、运行环境和工具箱任务
- 添加多个 1Panel 服务器，并通过移动端优先的界面快速切换

## 开源

Mono Dash 作为开源项目开发。你可以在本仓库查看源码、关注开发进度、提交 Issue 或参与贡献。

- 源代码：<https://github.com/bin64/Mono-Dash>
- 问题反馈：<https://github.com/bin64/Mono-Dash/issues>

## 免费版与应用内购买

免费版可以添加并管理一个 1Panel 服务器。

Mono Dash Unlimited 是可选的一次性应用内购买项目，用于解锁无限服务器管理，以及在可用情况下解锁未来的高级功能。购买由 App Store 或 Google Play 等适用平台处理，并可在 App 内恢复购买。

## 隐私与数据

Mono Dash 会将服务器连接设置保存在你的设备本地，并直接连接你配置的 1Panel 服务器。Mono Dash 不运营用于收集你的 1Panel 服务器数据的后端服务。

根据平台和分发渠道，购买状态可能会通过 Apple、Google Play 和 RevenueCat 处理，用于权益管理。

请阅读完整政策：

- [Privacy Policy](PRIVACY.md) | [隐私政策](PRIVACY.zh-CN.md)
- [Terms of Use](TERMS.md) | [使用条款](TERMS.zh-CN.md)

## 重要说明

请仅将 Mono Dash 用于你拥有、管理或已获授权访问的服务器。服务器管理操作可能影响网站、数据库、容器、文件、备份、防火墙规则、计划任务和其他生产资源。请谨慎确认删除、修改、重启等高风险操作，并为重要数据保留独立备份。

Mono Dash 依赖 1Panel API，不保证兼容所有 1Panel 版本、插件、服务器配置或部署环境。

## 开发

本仓库包含 Flutter 客户端源码。

### 环境要求

- Flutter SDK，Dart 版本需兼容 `^3.11.1`
- 构建 iOS 版本需要 Xcode
- 构建 Android 版本需要 Android Studio 和 Android SDK

### 本地运行

```bash
flutter pub get
flutter run
```

### 检查

```bash
flutter analyze
flutter test
```

## 项目链接

- 仓库：<https://github.com/bin64/Mono-Dash>
- 隐私政策：<https://github.com/bin64/Mono-Dash/blob/main/PRIVACY.md>
- 使用条款：<https://github.com/bin64/Mono-Dash/blob/main/TERMS.md>
- 1Panel：<https://github.com/1Panel-dev/1Panel>

## 许可证

本项目使用 GNU General Public License v3.0 许可证。详见 [LICENSE](LICENSE)。
