## 1.0.0

* 首次发布 `1.0.0` 正式版本，支持 **Android、iOS、macOS、Windows、Linux、Web (PWA)** 全 6 端接收系统及外部应用分享的文本、URL 链接、图片、视频、音频及任意类型单文件/多文件。
* 支持冷启动拉起接收（`getInitialSharing`）与运行期间热启动实时数据流监听（`onSharingReceived`）。
* 支持 macOS 系统“共享”菜单扩展（Share Extension，`com.apple.share-services`）、Finder“服务”菜单（`NSServices`）、“打开方式”及拖拽到 Dock 图标接收文件。
* 提供冷启动缓存清理（`clearInitialSharing`）与临时缓存文件清理（`cleanupTempFiles`）能力。
* 按照 Dart 官方规范内置随包分发的 AI Agent Skill（`skills/xue_hua_navite_accept_sharing-usage/SKILL.md`）。
