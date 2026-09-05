# lib/features —— 移植功能域（feature-first）

按 flutter-port.md 的移植顺序，每个模块一个目录，目录内按需建立：
`api / models / repositories / components / composables / utils`。

| 模块 | 移动端处理 | 状态 |
|---|---|---|
| `twofactor` | 解密 vault + HMAC-SHA1 出 TOTP（最早可交付，兼作加密 PoC 验收） | 未启动 |
| `notes` | flutter_quill 直接消费 note_book.html | 未启动 |
| `habit` | reminders → 本地通知；打卡按 `habitKey#date` 幂等 upsert | 未启动 |
| `todo` | 每日实例用 workmanager；父子/重复任务字段已在表定义中 | 未启动 |
| `pomodoro` | 状态机来自 reminders(stateful)；需前台服务保活（iOS 受限） | 未启动 |
| `file_vault` | 密文文件拷入沙盒，同套 AES-256-GCM 解密 | 未启动 |
| `ebook` | epubx 解析；进度/划线按 content_hash 映射，不依赖桌面 file_path | 未启动 |
| `conversation` | 先定 LLM 后端（自建 API / 本地模型） | 未启动 |
| `screenshots` | 重设计：相册导入（image_picker）/ 系统分享收纳 | 未启动 |

不移植到移动端的桌面能力：悬浮小窗、全局热键、资源管理器右键菜单、系统级剪贴板常驻监听。
