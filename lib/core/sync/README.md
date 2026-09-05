# core/sync —— 局域网同步（P3，先计划后实施）

对应 `.zcode/skills/jianli-app/references/flutter-port.md` 第 7 节：

- **同步模型**：所有业务表以 `key`/`id` 为主键 → 同步 = 按主键幂等 upsert。
- **发现**：mDNS/NSD 同局域网找对端（借鉴 LocalSend，它本身就是 Flutter 项目）。
- **传输**：本端起本地 HTTP（`shelf`），选中表序列化 JSON 推送，对端按主键 upsert。
- **冲突**：`updateTime`/`updated_at` 最后写入胜出（新表设计需带时间戳）。
- **安全**：含 vault 字段的数据必须走会话密钥加密，禁止明文过局域网；
  vault 文件跨设备迁移需用「用户口令」重新包装主密钥，禁止直传设备绑定密钥。

> 实施前置：P1 加密 PoC 通过、首批功能表全部接入 drift 之后才动工。
