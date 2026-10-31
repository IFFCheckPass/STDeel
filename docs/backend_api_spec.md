# 思谛 STDeel — 前端 ↔ 后端接口契约（v0.9.10 及以前，历史参考）

> ⚠️ 已被 [`docs/backend_requirements.md`](backend_requirements.md)（v0.9.11 后端重写需求）取代。
> 本文档保留作历史参考；新后端以新版需求文档为准。

> 本文档按**前端现有代码**逐条整理，供后端重写/对齐使用。
> 依据：`lib/services/backend_api.dart`、`lib/services/sync_service.dart`、
> `lib/providers/solve_provider.dart`、`lib/services/data_integrity_service.dart`。
> 文中「前端行为」是已发布 APK 的真实行为；「后端需保证」是重写时必须满足的硬约束。

## 1. 通信总览

| 项 | 约定 |
|---|---|
| Base URL | 用户在设置页配置，默认 `https://api.stdeel.com/api/v1`；支持公网（`backend_url`）与内网（`backend_url_intranet`）双通道，开关 `backend_use_public` 默认 true，所选通道为空时自动回退另一通道 |
| URL 规范化 | 去首尾空格；无 `http://`/`https://` 前缀时自动补 `https://`；去掉末尾 `/`；**保留路径前缀** |
| 拼接方式 | 所有资源路径**直接追加**在 Base URL 之后（如 `{base}/solve-records`），后端可自定义前缀（如 `/stapi`） |
| 鉴权 | **无 Token / 无 Cookie / 无签名**，身份仅靠请求体或 query 里的 `user_id`；无自定义 Header |
| 数据格式 | 请求默认 `application/json`（图片上传为 `multipart/form-data`）；响应按 JSON 解析 |
| 超时/重试 | 除 `/healthz`（5s）外**未配置超时**；所有调用失败均被前端捕获，不重试（离线时靠本地 SQLite + 下次手动同步补传） |
| HTTP 成功判定 | Dio 2xx 视为成功；非 2xx 抛异常，按失败处理（不会解析错误体） |
| 平台标识 | 注册接口固定携带 `platform: "android"`（Windows 版同为 `android`） |

**重要**：前端不校验签名、不携带任何密钥，后端不能依赖 Header 鉴权；若要加鉴权需同步改前端。

---

## 2. 身份与注册

### 2.1 `device_id`
- 前端本地生成 UUID v4（`Random.secure`），持久化在 SQLite `app_settings`（key `device_id`）。
- 同一 `device_id` 重复注册应返回**同一个** `user_id`（后端按 device_id 复用用户）。

### 2.2 `user_id`
- 首次任何需要身份的请求前，前端自动调用注册接口并持久化 `user_id`（key `user_id`）。
- 之后所有接口均带该值；前端不做任何校验。

### 2.3 `POST /users/register`

**Body（两种形态，同一路由）**

```json
{ "device_id": "550e8400-e29b-41d4-a716-446655440000", "platform": "android" }
```

```json
{ "username": "张三", "platform": "android" }
```

- 形态 A：设备首次注册 / 复用。
- 形态 B：账号绑定。**后端需保证「仅传 username → 按 username 查找，不存在则创建，且返回该 username 唯一稳定的 user_id」**，这是跨设备找回数据的唯一凭据。

**响应（二选一，前端都认）**

```json
{ "user_id": "u_123" }
```

或

```json
{ "id": "u_123" }
```

- 值可为字符串或数字（前端统一 `toString()`）；**不能为空**，为空则前端抛「用户注册失败：响应缺少 user_id」。
- 失败时：首次启动自动注册失败 → 该次上传/注册调用报错（业务调用方多为静默处理，不阻塞 UI）。

**启动自愈**：本地存在 `username` 但 `user_id` 缺失时，每次启动会再次调用形态 B 重新绑定。

---

## 3. 接口清单

> 路径均相对 Base URL；`{id}` 均为**后端主键**（前端称 `remoteId`），数字类型。

| # | 方法 | 路径 | 用途 | 当前是否实际调用 |
|---|---|---|---|---|
| 1 | POST | `/users/register` | 设备注册 / 用户名绑定 | ✅ 是 |
| 2 | PUT | `/users/api-key` | 用户 AI Key 跨端同步 | ✅ 启动时后台调用（条件满足时） |
| 3 | POST | `/solve-records` | 解题记录批量上传（含 questions 数组） | ✅ 解题完成后自动 |
| 4 | POST | `/solve-records` | 单条记录补传（扁平结构，**同一路由不同结构**） | ✅ 手动同步 |
| 5 | PATCH | `/solve-records/{id}/feedback` | 反馈更新 | ✅ 点击「正确/部分错误/错误」 |
| 6 | DELETE | `/solve-records/{id}` | 删除记录（body 带 user_id） | ✅ 历史页删除 |
| 7 | GET | `/solve-records` | 下拉解题记录（双向同步） | ✅ 手动同步 |
| 8 | GET | `/knowledge/mastery` | 知识点掌握度 | ⚠️ 有代码但当前 UI 未调用（预留） |
| 9 | GET | `/knowledge/weak` | 薄弱知识点 | ⚠️ 有代码但当前 UI 未调用（预留） |
| 10 | POST | `/answer-library` | 上传标准答案 | ✅ 手动新增 / 文档导入（仅有题干的条目） |
| 11 | POST | `/answer-library/match` | 后端相似题匹配 | ✅ 本地命中失败后 |
| 12 | POST | `/files/upload` | 图片上传（multipart） | ❌ 已封装但无调用点（可暂不实现） |
| 13 | GET | `/healthz` | 连通性测试（**host 根路径**，不带 API 前缀） | ✅ 设置页 |

**历史文档中的 `GET /users/{user_id}/mastery`、`GET /knowledge/points` 前端已不再调用，重写时无需实现。**

---

## 4. 逐接口明细

### 4.1 `PUT /users/api-key`

**调用时机**：每次启动 `SettingsProvider.load()` 后（已绑定 username 且至少有一个配置完整的供应商时），后台 fire-and-forget 上传全部 Key。

**Body**

```json
{
  "user_id": "u_123",
  "api_keys": [
    { "api_key": "sk-xxx", "name": "通义千问", "enabled": true }
  ]
}
```

- 语义：**全量覆盖该用户的 Key 列表**（同一 key 可重复上送，后端应幂等）。
- 前端注释表明后端也可兼容纯字符串数组 `["sk-..."]`，但实际只发对象数组。
- 空数组不发送（前端直接短路）。
- 响应：任意 2xx 即可；非 2xx 前端仅提示「API Key 同步失败」。

> 安全提示：无鉴权，知道 `user_id` 即可读写 Key；正式上线建议后端自行加签名/令牌，并在前端同步增加 Header。

### 4.2 `POST /solve-records` — 形态 A：批量（解题完成）

**触发**：每轮解题成功、写本地 SQLite 后异步上传；每题一行本地记录，但**一次请求携带全部小题**。

**Body**

```json
{
  "user_id": "u_123",
  "ai_model": "qwen-vl-max",
  "latency_ms": 3200,
  "tokens_used": 512,
  "source": "ai",
  "image_path": "/data/user/0/com.stdeel.steel/cache/xxx.jpg",
  "questions": [
    {
      "id": 18,
      "content": "题目内容（可能含小题编号）",
      "knowledge_points": ["三角函数", "两角和差公式"],
      "answer": "答案",
      "solution": "简略解答过程",
      "confidence": 0.95,
      "subject": "数学",
      "question_no": 0,
      "action_type": "solve",
      "user_feedback": "none"
    }
  ]
}
```

字段说明：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | int | **本地 SQLite 主键，不是后端 id**，后端应忽略或仅作日志 |
| `content` | string | 题干；大题已按小题拆分，一条对应一个小题 |
| `knowledge_points` | string[] | 该小题知识点 |
| `answer` / `solution` | string | 答案 / 过程（可能含 LaTeX） |
| `confidence` | double | AI 置信度 0~1 |
| `subject` | string | 科目，见 §5 |
| `question_no` | int | 卷内题号，未知为 0 |
| `action_type` | string | 该题最近动作，见 §5（初始为 `solve`） |
| `user_feedback` | string | 该题反馈，见 §5（初始为 `none`） |
| `image_path` | string | **设备本地绝对路径**，不是 URL，后端视为不透明字符串或忽略 |
| `source` | string | `ai` / `answer_library` / `error` |

> **状态字段必须落库**：`action_type` / `user_feedback` 是题目状态（正确/部分错误/错误/疑问/重答）的唯一载体。
> 后端 `POST /solve-records`、`PATCH .../feedback`、`GET /solve-records` 必须原样存取这两个字段；
> 若后端落库或回传时丢失它们，前端会看到状态被清空。
> 前端已做保护：① 后端**未回传明确反馈**（缺失/空串/`none`）时，不会覆盖本地已有的 `correct/partial/wrong`；
> ② 本地存在**尚未上传**的新状态时，以本地为准；只有后端明确回传反馈且本地无待传状态，才以后端为准。

**响应（前端会递归收集所有数字 `id`）**

任选一种形状（按 `questions` 顺序一一对应）：

```json
[{ "id": 1001 }, { "id": 1002 }]
```

```json
{ "items": [{ "id": 1001 }, { "id": 1002 }] }
```

```json
{ "data": { "items": [{ "id": 1001 }, { "id": 1002 }] } }
```

**硬约束**

- 返回的 id **数量必须等于 `questions` 数量且顺序一致**，前端才会写回 `remoteId` 并标记已同步。
- 数量不匹配或未返回 id：前端保持「未同步」，**下次手动同步会用形态 B 逐条重传**。若后端此时已落库，会产生重复记录 → **后端务必返回 id**，并建议按 `(user_id, question_text, created_at≈)` 或前端 `local_id` 做去重。
- `id` 必须为 **数字**（JSON number），字符串 id 会被丢弃。

### 4.3 `POST /solve-records` — 形态 B：单条补传

**触发**：用户在设置页点「手动同步」时，对本地 `synced=false` 的记录逐条 POST。

**Body（扁平结构，无 `questions`，与形态 A 不含同一字段集）**

```json
{
  "user_id": "u_123",
  "local_id": 18,
  "question_text": "题干",
  "answer": "答案",
  "solution": "过程",
  "ai_model": "qwen-vl-max",
  "latency_ms": 3200,
  "tokens_used": 512,
  "matched": false,
  "action_type": "solve",
  "user_feedback": "none",
  "image_path": "/data/.../xxx.jpg",
  "subject": "数学"
}
```

**与形态 A 的差异（后端需注意）**

- 无 `knowledge_points`、无 `source`、无 `confidence`、无 `question_no`。
- 多 `local_id`（本地主键，可用于幂等）、`action_type`、`user_feedback`、`matched`。

**响应硬约束**

- 必须返回**恰好 1 个**数字 id（`{"id": 1001}` 或 `{"items":[{"id":1001}]}` 等）。
- 返回 0 个或多个 → 前端记为失败，下次再传（同样有重复落库风险）。

**建议**：后端在同一路由内按是否存在 `questions` 数组区分形态 A / B。

### 4.4 `PATCH /solve-records/{id}/feedback`

**Body**

```json
{ "feedback": "correct", "user_id": "u_123" }
```

- `feedback` ∈ `correct | partial | wrong`（0.9.10 新增 `partial` = 部分错误）。
- `{id}` 为后端主键；本地无 `remoteId` 时**前端直接跳过**（等下次整条补传时随 `user_feedback` 带过去）。
- 响应任意 2xx；前端成功后把该条标记为已同步。
- **注意**：PATCH 失败时前端静默丢弃、**不会重试也不会把记录标脏**；因此后端应保证接口幂等、可重复调用（例如用户再次点同一按钮会再次 PATCH）。
- 后端收到 `partial` 后，知识点掌握度口径建议：`correct +1` 且 `wrong +1`（「半掌握」）。

### 4.5 `DELETE /solve-records/{id}`

**Body**（HTTP DELETE 带 body）

```json
{ "user_id": "u_123" }
```

- 2xx 视为删除成功；失败时前端把 `{id}` 写入本地「待删除队列」。
- **待删除队列在每次 App 启动、以及每次手动同步时重试**；后端删除接口应幂等（重复 DELETE 也返回 2xx，避免队列堆积）。
- 前端本地 `remoteId=0`（从未同步）时视为成功，不请求后端。

### 4.6 `GET /solve-records`

**Query**

| 参数 | 必填 | 说明 |
|---|---|---|
| `user_id` | ✅ | 当前用户 |
| `correct_days` | ❌ | 正确记录回看天数，前端固定传 `30` |
| `wrong_days` | ❌ | 错误记录回看天数，前端固定传 `90` |

**响应**

```json
{
  "total": 123,
  "items": [
    {
      "id": 1001,
      "question_text": "...",
      "answer": "...",
      "solution": "...",
      "knowledge_points": ["三角函数"],
      "ai_model": "qwen-vl-max",
      "latency_ms": 3200,
      "tokens_used": 512,
      "matched": true,
      "action_type": "correct",
      "user_feedback": "correct",
      "subject": "数学",
      "created_at": "2026-10-31T12:00:00Z"
    }
  ]
}
```

前端实际读取的字段：

| 字段 | 类型 | 缺省行为 |
|---|---|---|
| `id` | int | **必须 >0**，否则整条跳过（幂等 upsert 依据） |
| `question_text` / `answer` / `solution` | string | 缺省空串 |
| `knowledge_points` | string[]（**数组**） | 非数组按 `[]` 存 |
| `ai_model` | string | 空串 |
| `latency_ms` / `tokens_used` | int | 0 |
| `matched` | bool | `true` 才算命中 |
| `action_type` 或 `status` | string | 优先取 `action_type`，其次 `status` |
| `user_feedback` | string | 见 §5；缺省 `none` |
| `subject` | string | 空/缺失 → `未分类` |
| `created_at` | string(ISO-8601) | `DateTime.tryParse`，解析失败用本地当前时间 |

- 语义：`correct` 记录取近 30 天、`wrong`（含 `partial`）取近 90 天，取并集按时间倒序（前端不排序，直接 upsert）。
- `action_type`/`status`/`user_feedback` 任一为 `correct|partial|wrong` 时，前端同时写入 `action_type` 与 `user_feedback`（知识点页错题查询依赖 `wrong + partial`）。
- **不要**给无反馈记录回填 `correct`（前端据此避免误标）。

### 4.7 `GET /knowledge/mastery`（预留，当前 UI 未调用）

Query：`user_id`；响应 `{ "items": [ { "knowledge_point": "三角函数", "correct_count": 12, "wrong_count": 3 } ] }`

前端会按 `knowledge_point + correct_count + wrong_count` 写入本地（`subject` 取默认 `未分类`）。

### 4.8 `GET /knowledge/weak`（预留，当前 UI 未调用）

Query：`user_id`；响应 `{ "items": [ ... ] }`，前端原样透传给上层（当前无消费方）。

### 4.9 `POST /answer-library`

**Body**

```json
{
  "user_id": "u_123",
  "question_text": "题干",
  "question_hash": "sha256hex",
  "answer": "标准答案",
  "solution": "解答过程",
  "knowledge_points": ["三角函数"],
  "subject": "数学"
}
```

- `question_hash` = 题干 `trim` 后把连续空白压缩为单个空格，再做 SHA-256（小写 hex）。
- **无题干条目（答案册只有题号+答案）前端只存本地，不上传**；因此不传 `paper_id` / `question_no`。
- 2xx 即成功；失败静默，本地仍保留。

### 4.10 `POST /answer-library/match`

**Body**

```json
{
  "user_id": "u_123",
  "question_text": "题干",
  "question_hash": "sha256hex"
}
```

**响应**

```json
{
  "hit": true,
  "similarity": 0.93,
  "answer": {
    "answer": "标准答案",
    "solution": "过程",
    "subject": "数学",
    "knowledge_points": "[\"三角函数\",\"两角和差公式\"]"
  }
}
```

**注意字段类型陷阱**

- 前端判定条件：`hit == true` **且** `similarity >= 0.85`。
- `answer.knowledge_points` 前端按 **JSON 字符串**解析（`jsonDecode`），必须返回
  `"[\"三角函数\"]"` 这种字符串；若返回真正的数组会解析失败 → 知识点为空。
- 与 `GET /solve-records` 的 `knowledge_points`（数组）**类型不同，切勿统一**。

### 4.11 `POST /files/upload`（已封装，当前无调用）

`multipart/form-data`：`user_id`、`file`。响应 `{ "url": "..." }` 或 `{ "file_url": "..." }`。
当前版本图片仅用于本地解题，不上传后端；可暂缓实现。

### 4.12 `GET /healthz`

- 地址为 **Base URL 的 host 根**：`{scheme}://{host}[:port]/healthz`（**忽略 API 路径前缀**）。
- 任意 `200~499` 视为可达；5xx 或网络错误视为不可达；前端超时 5s。

---

## 5. 字段与枚举字典

| 字段 | 取值 | 说明 |
|---|---|---|
| `user_feedback` | `none` / `correct` / `partial` / `wrong` | 本地默认 `none`；`partial` 为 0.9.10 新增「部分错误」 |
| `action_type` | `solve` / `retry` / `detail` / `correct` / `wrong` | 本地「最近动作」；云端仅需原样存取；`partial` 目前只写 `user_feedback` |
| `source` | `ai` / `answer_library` / `error` | 仅批量上传携带 |
| `subject` | `数学` `语文` `英语` `物理` `化学` `生物` `政治` `历史` `地理` `其他` `未分类` | AI 归类，缺省 `未分类` |
| `matched` | bool | 是否命中答案库 |
| `confidence` | 0~1 double | 仅批量上传的 questions 内 |
| `created_at` | ISO-8601 字符串 | 建议 UTC（带 `Z`） |
| 所有 id | JSON number(int) | 字符串 id 会被前端丢弃 |

---

## 6. 前端调用时序（便于后端对齐）

1. **启动**：`load()` → 若有 username 且有完整供应商 → 异步 `PUT /users/api-key`；若 username 有但 user_id 无 → `POST /users/register`（username 形态）；首页异步清理「待删除队列」（`DELETE /solve-records/{id}`）。
2. **解题完成**：本地入库（每题一行）→ `POST /solve-records`（形态 A，一次全部小题）→ 按返回 id 写回 `remoteId`。
3. **点反馈**：本地更新 → `PATCH /solve-records/{id}/feedback`。
4. **删除记录**：`DELETE /solve-records/{id}` → 成功删本地；失败入待删队列。
5. **手动同步（设置页）**：① 重试待删队列 → ② 对未同步记录逐条 `POST /solve-records`（形态 B）→ ③ `GET /solve-records` 回写本地。
6. **答案库**：手动新增/文档导入（仅有题干）→ `POST /answer-library`；解题时本地 hash 未命中 → `POST /answer-library/match`。

---

## 7. 后端重写验收清单（必须满足）

1. `POST /users/register` 支持 device_id / username 两种形态，返回 `user_id`（或 `id`），同 device_id 或同 username 稳定复用。
2. `POST /solve-records` 同时接受「批量 questions」与「扁平单条」两种结构。
3. 批量上传**按顺序返回等量数字 id**；单条补传**恰好返回 1 个数字 id**（否则前端重试 → 需后端按 `local_id` 或内容去重）。
4. `GET /solve-records` 返回 `{items:[...]}`，`id` 数字且 >0，`knowledge_points` 为**数组**，其余字段按 §4.6 回传。
5. `PATCH` / `DELETE` 幂等，`DELETE` 允许 body 携带 `user_id`。
6. `POST /answer-library/match` 的 `answer.knowledge_points` 必须是 **JSON 字符串**，`similarity` 与 `hit` 按 0.85 阈值联调。
7. 所有接口无鉴权依赖，`user_id` 从 body/query 读取；不要强制要求 Header 或 Cookie。
8. 允许 Base URL 带任意路径前缀（如 `https://host/stapi`），且 `healthz` 在 host 根。
9. 时间字段统一 ISO-8601；非 2xx 前端不会解析错误体，建议 2xx + 业务结果放 body。
10. 接口需容忍重复提交（离线补传、删除队列重试都会产生重复请求）。
11. **必须持久化并回传 `action_type` / `user_feedback`**（批量上传每个 question、单条补传、PATCH、GET 四处都要）；
    后端若存成默认值或回传空值，用户已标记的题目状态会「同步一次就丢」。
