# 思谛 STDeel 后端重写需求（v0.9.11）

> 本文档面向**后端重写**：定义客户端（Android APK / Windows 桌面版，同一套 Flutter 代码）
> 对服务端的全部依赖、数据契约与验收标准。
> 依据当前客户端实现：`lib/services/backend_api.dart`、`lib/services/sync_service.dart`、
> `lib/providers/solve_provider.dart`、`lib/services/data_integrity_service.dart`。
> 替代旧版 `docs/backend_api_spec.md`（旧文档仅作历史参考）。

---

## 1. 项目定位

后端**只做数据同步与账号归属**，不承担 AI 推理：

- AI 解题：客户端直连用户自配的 OpenAI 兼容端点（Bearer 用户自己的 Key），不经过本后端。
- 版本更新：客户端直连 GitHub Releases，不经过本后端。
- 后端负责：设备/用户名注册、解题记录上传与拉取、题目状态（反馈）、删除同步、
  知识点统计、标准答案库上传与匹配、用户 AI Key 跨端同步。

**技术栈不限**，但必须满足第 3~6 章的契约与第 8 章验收用例。

---

## 2. 客户端通信约定

| 项 | 约定 |
|---|---|
| Base URL | 用户可在设置页配置；默认 `https://api.stdeel.com/api/v1`；支持公网/内网双通道切换 |
| 前缀 | Base URL 可带任意路径前缀（如 `https://host/stapi`），后端所有路由需适配前缀 |
| URL 规范化 | 客户端会去掉末尾 `/`；无协议时自动补 `https://` |
| 鉴权 | **当前无 Token / Cookie / 签名**，身份仅为请求体或 query 中的 `user_id` |
| Header | 无自定义 Header；Windows 桌面版 `platform` 同样传 `android` |
| 请求体 | JSON（`application/json`）；图片上传为 `multipart/form-data` |
| 超时 | 仅 `/healthz` 超时 5s，其余接口客户端未设超时（后端应尽快响应，避免挂死） |
| 成功判定 | **仅 2xx 视为成功**；非 2xx 一律按失败处理，客户端不解析错误体 |
| 重试 | 客户端不自动重试；依赖本地 SQLite 缓存 + 用户手动同步补传 |

> 安全现状：知道 `user_id` 即可读写该用户数据。重写时建议后端**预留鉴权扩展位**，
> 但若加 Token/签名，必须同步修改客户端 Header（需联调）。

---

## 3. 数据模型建议

后端可自行设计库表，但需能完整保存/回传下列字段（字段名与客户端契约一致）。

### 3.1 users
| 字段 | 类型 | 约束/说明 |
|---|---|---|
| `id` | 自增主键 | 对客户端以字符串或数字形式返回均可 |
| `device_id` | string | 唯一；同 device_id 重复注册返回同一用户 |
| `username` | string | 唯一（可空）；仅传 username 注册时按它查找/创建 |
| `api_keys` | JSON | 全量覆盖式保存 `[{api_key,name,enabled}]` |
| `created_at` | datetime | |

### 3.2 solve_records（核心）
| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | 自增主键 | **必须为数字**，客户端用它做幂等与 PATCH/DELETE |
| `user_id` | string | 归属用户 |
| `local_id` | int/null | 客户端本地主键（单条补传时携带），强烈建议 `(user_id, local_id)` 唯一用于去重 |
| `question_text` / `answer` / `solution` | text | 可含 LaTeX；`answer`/`solution` 可空串 |
| `knowledge_points` | JSON 数组 | 如 `["三角函数","两角和差公式"]` |
| `subject` | string | 科目枚举，见 §5 |
| `ai_model` | string | 模型名 |
| `latency_ms` / `tokens_used` | int | 耗时与 token 数 |
| `matched` | bool | 是否命中答案库 |
| `action_type` | string | **题目最近动作，见 §5；必须落库并回传** |
| `user_feedback` | string | **正确/部分错误/错误，见 §5；必须落库并回传** |
| `source` | string | `ai` / `answer_library` / `error`（批量上传携带） |
| `confidence` | double/null | AI 置信度（仅批量上传的 question 内携带） |
| `question_no` | int/null | 卷内题号，未知为 0 |
| `image_path` | text | 客户端设备本地路径（不可访问），视为不透明字符串 |
| `created_at` | datetime | **以服务端接收时间为准**更可靠；需回传 ISO-8601 |

### 3.3 knowledge_mastery
| 字段 | 类型 | 说明 |
|---|---|---|
| `user_id` | string | |
| `knowledge_point` | string | |
| `subject` | string | 默认「未分类」 |
| `correct_count` / `wrong_count` | int | 累计次数 |

口径：`correct` → correct+1；`partial`（部分错误）→ **correct+1 且 wrong+1**（半掌握）；`wrong` → wrong+1。
可在 PATCH 反馈时增量维护，或从 solve_records 聚合。

### 3.4 answer_library
| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | 自增主键 | |
| `question_text` | text | 题干 |
| `question_hash` | string | 题干规范化后的 SHA-256 小写 hex |
| `answer` / `solution` | text | |
| `knowledge_points` | JSON | |
| `subject` | string | |
| `created_at` | datetime | |

建议 `(user_id, question_hash)` 唯一（按用户隔离；若做共享题库则改为全局 + 用户可见性策略）。
`question_hash` 生成规则：题干 `trim` → 连续空白压缩为单个空格 → UTF-8 → SHA-256。

### 3.5 删除墓碑
客户端本地删除失败时会把后端 id 记入本地队列，每次启动、每次手动同步都会重试 `DELETE`。
因此 **DELETE 必须幂等**（记录不存在也返回 2xx）。

### 3.6 去重与幂等（重要）
客户端存在重传路径（离线补传、批量返回 id 缺失后逐条重传、删除重试），后端必须：

1. 单条补传（带 `local_id`）时按 `(user_id, local_id)` upsert，避免重复行；
2. 批量上传（`questions[]` 不带 local_id）建议用 `(user_id, question_text 哈希, 接收时间窗口)`
   或客户端 `questions[].id`（本地主键，仅设备内唯一）做辅助去重；
3. `PATCH` / `DELETE` 幂等。

---

## 4. 接口需求明细

> `{base}` = 用户配置的 Base URL；下表路径均相对它。`{id}` 为后端主键（数字）。

| # | 方法 | 路径 | 必须实现 |
|---|---|---|---|
| 1 | POST | `/users/register` | ✅ |
| 2 | PUT | `/users/api-key` | ✅ |
| 3 | POST | `/solve-records` | ✅（同一路由支持两种 body） |
| 4 | PATCH | `/solve-records/{id}/feedback` | ✅ |
| 5 | DELETE | `/solve-records/{id}` | ✅ |
| 6 | GET | `/solve-records` | ✅ |
| 7 | POST | `/answer-library` | ✅ |
| 8 | POST | `/answer-library/match` | ✅ |
| 9 | GET | `/healthz` | ✅（host 根路径，不带 API 前缀） |
| 10 | GET | `/knowledge/mastery` | ⚠️ 客户端已封装但当前 UI 未调用，可后置 |
| 11 | GET | `/knowledge/weak` | ⚠️ 同上，可后置或不实现 |
| 12 | POST | `/files/upload` | ⚠️ 客户端已封装但无调用点，可暂不实现 |

### 4.1 POST /users/register

**请求（设备注册）**
```json
{ "device_id": "550e8400-e29b-41d4-a716-446655440000", "platform": "android" }
```
**请求（用户名绑定）**
```json
{ "username": "张三", "platform": "android" }
```

**响应**
```json
{ "user_id": "u_123" }
```
或 `{ "id": "u_123" }`（客户端两者都认；值可为字符串/数字，不能为空）。

**规则**
- 同 `device_id` 必须复用同一 `user_id`。
- 仅传 `username` 时：查找该 username，不存在则创建；返回**唯一稳定**的 user_id。
- 该接口是跨设备找回数据的唯一凭据，username 必须唯一。

### 4.2 PUT /users/api-key

**请求**
```json
{
  "user_id": "u_123",
  "api_keys": [
    { "api_key": "sk-xxx", "name": "通义千问", "enabled": true }
  ]
}
```
- 语义：**全量覆盖**该用户 Key 列表；后端需支持幂等覆盖。
- 触发时机：客户端启动时（已绑定 username 且至少有一个完整供应商）后台调用。
- 响应：任意 2xx。

### 4.3 POST /solve-records — 形态 A（解题完成，批量）

**请求**
```json
{
  "user_id": "u_123",
  "ai_model": "qwen-vl-max",
  "latency_ms": 3200,
  "tokens_used": 512,
  "source": "ai",
  "image_path": "/data/user/0/com.stdeel.steel/cache/x.jpg",
  "questions": [
    {
      "id": 18,
      "content": "题干",
      "knowledge_points": ["三角函数"],
      "answer": "答案",
      "solution": "过程",
      "confidence": 0.95,
      "subject": "数学",
      "question_no": 0,
      "action_type": "solve",
      "user_feedback": "none"
    }
  ]
}
```

- `questions[].id` 是**客户端本地 SQLite 主键**，不是后端 id，后端不得直接复用为自身主键（可用于辅助去重）。
- 初始解出时 `action_type=solve`、`user_feedback=none`；如用户在极短时间内已标记，可能直接携带最新状态。
- **响应必须按 `questions` 顺序返回等量数字 id**（前端会递归收集所有 `id` 数字）：

```json
{ "items": [ { "id": 1001 }, { "id": 1002 } ] }
```
也兼容 `[{ "id": 1001 }]`、`{ "data": { "items": [...] } }`。

**硬约束**
- id 数量 ≠ questions 数量，或未返回 id → 客户端不写 remoteId、保持未同步，下次手动同步逐条重传；
  若后端此时已落库而没给 id，会产生**重复记录**（请务必返回 id）。
- id 必须是 JSON number。

### 4.4 POST /solve-records — 形态 B（单条补传，同一路由）

**请求**
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
  "action_type": "correct",
  "user_feedback": "correct",
  "image_path": "/data/.../x.jpg",
  "subject": "数学"
}
```

- 与形态 A 差异：扁平结构、无 `questions`、**无 knowledge_points/source/confidence/question_no**，多 `local_id`。
- 响应必须**恰好 1 个数字 id**（如 `{"id":1001}`）。
- 建议后端用「body 是否含 `questions` 数组」区分两种形态。

### 4.5 PATCH /solve-records/{id}/feedback

**请求**
```json
{ "feedback": "correct", "user_id": "u_123" }
```
- `feedback` ∈ `correct | partial | wrong`。
- `{id}` 为**后端主键**（客户端只对已拿到 remoteId 的记录调用；未同步记录跳过，随整条补传）。
- 响应任意 2xx；客户端成功即标记已同步。
- **必须幂等**：用户重复点击会重复 PATCH。
- 失败时客户端不重试、不标脏，因此建议后端尽量不失败；若失败，客户端下次整条补传时会带 `user_feedback`（但可能产生重复行，见 §3.6）。

### 4.6 DELETE /solve-records/{id}

**请求（HTTP DELETE 带 body）**
```json
{ "user_id": "u_123" }
```
- 2xx 视为成功；失败会被客户端写入待删除队列，在每次启动/每次手动同步时重试。
- **必须幂等**（记录不存在也返回 2xx），否则队列永远清不掉。

### 4.7 GET /solve-records

**Query**
| 参数 | 必填 | 说明 |
|---|---|---|
| `user_id` | ✅ | |
| `correct_days` | ❌ | 客户端固定传 `30` |
| `wrong_days` | ❌ | 客户端固定传 `90` |

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

**客户端实际读取字段**

| 字段 | 类型 | 缺省行为 |
|---|---|---|
| `id` | number | **必须 >0**，否则整条跳过（幂等 upsert 依据） |
| `question_text`/`answer`/`solution` | string | 空串 |
| `knowledge_points` | **数组** | 非数组按 `[]` |
| `ai_model` | string | 空串 |
| `latency_ms`/`tokens_used` | int | 0 |
| `matched` | bool | 仅 `true` 算命中 |
| `action_type`（或 `status`） | string | 优先 `action_type`，其次 `status` |
| `user_feedback` | string | 缺省 `none` |
| `subject` | string | 空/缺失 → `未分类` |
| `created_at` | ISO-8601 字符串 | 解析失败用本地当前时间 |

**语义**：`correct/partial/wrong` 记录按窗口返回（正确 30 天、错误/部分错误 90 天），取并集按时间倒序。
**务必回传 `action_type` 与 `user_feedback`**，否则客户端只能显示「解题」。

### 4.8 POST /answer-library

```json
{
  "user_id": "u_123",
  "question_text": "题干",
  "question_hash": "sha256hex",
  "answer": "标准答案",
  "solution": "过程",
  "knowledge_points": ["三角函数"],
  "subject": "数学"
}
```
- 仅「有题干」的条目上传；答案册里只有题号+答案的条目**只存客户端本地**，不上传（因此无 paper_id/question_no）。
- 建议按 `(user_id, question_hash)` upsert。

### 4.9 POST /answer-library/match

**请求**
```json
{ "user_id": "u_123", "question_text": "题干", "question_hash": "sha256hex" }
```

**响应**
```json
{
  "hit": true,
  "similarity": 0.93,
  "answer": {
    "answer": "答案",
    "solution": "过程",
    "subject": "数学",
    "knowledge_points": "[\"三角函数\",\"两角和差公式\"]"
  }
}
```

**两个陷阱**
1. 客户端判定：`hit == true` 且 `similarity >= 0.85`。
2. `answer.knowledge_points` 必须是 **JSON 字符串**（客户端 `jsonDecode`），不能是数组；
   这与 `GET /solve-records` 的数组类型**相反**，务必分别处理。

### 4.10 GET /healthz

- 地址：`{scheme}://{host}[:port]/healthz`，**忽略 Base URL 的路径前缀**。
- 2xx~4xx 视为服务可达；5xx/网络错误视为不可达。

---

## 5. 枚举与字段字典

| 字段 | 取值 |
|---|---|
| `user_feedback` | `none` / `correct` / `partial`（部分错误，v0.9.10 起） / `wrong` |
| `action_type` | `solve`（初始解题） / `retry`（重答） / `detail`（疑问） / `correct` / `partial` / `wrong` |
| `source` | `ai` / `answer_library` / `error` |
| `subject` | `数学` `语文` `英语` `物理` `化学` `生物` `政治` `历史` `地理` `其他` `未分类` |
| `platform` | 恒为 `android`（含 Windows 版） |
| `confidence` | 0~1 |
| `question_hash` | SHA-256（小写 hex），见 §3.4 |

**状态优先级**：`user_feedback` 是「正确/部分错误/错误」的唯一判定；`action_type` 用于区分疑问/重答。
客户端展示状态时优先看 `user_feedback`，其次 `action_type`。

---

## 6. 客户端同步时序（后端需按此对齐）

1. **启动**
   - 无 `user_id` → `POST /users/register`（device_id）。
   - 有 `username` 无 `user_id` → 自愈重绑（username 形态 register）。
   - 有 username + 完整供应商 → 异步 `PUT /users/api-key`。
   - 重试本地「待删除队列」（`GET/DELETE` 幂等要求）。
2. **解题完成**：本地每题入库 → 批量 `POST /solve-records`（形态 A）→ 按返回 id 写回 remoteId。
3. **点反馈**：本地更新 → `PATCH /solve-records/{id}/feedback`。
4. **删记录**：`DELETE /solve-records/{id}` → 失败入墓碑。
5. **手动同步（设置页）**：墓碑重试 → 未同步记录逐条 `POST`（形态 B）→ `GET /solve-records` 回写本地。
6. **答案库**：新增/导入（有题干）→ `POST /answer-library`；解题时本地 hash 未命中 → `POST /answer-library/match`。

---

## 7. 非功能需求

1. **幂等**：`POST /solve-records`（形态 B，按 local_id upsert）、`PATCH`、`DELETE`、`PUT /users/api-key`。
2. **去重**：见 §3.6；批量上传务必返回等量 id。
3. **时间**：统一 ISO-8601（建议 UTC `Z`）；`GET /solve-records` 按 `created_at` 倒序。
4. **容量**：单次批量题目数通常 ≤ 10；单用户历史数千条；无分页需求，但建议支持 `limit` 以免一次返回过大。
5. **兼容**：后端需兼容旧客户端（≤0.9.10）——批量 `questions[]` 可能**不带** `action_type/user_feedback`；缺失时按 `solve`/`none` 落库即可，并在 GET 回传。
6. **可用性**：`/healthz` 必须快速响应（客户端 5s 超时）；其余接口建议 < 3s。
7. **日志**：按 `user_id` 记录请求，便于排查「状态丢失」类问题（保留 `action_type`/`user_feedback` 的入参日志）。
8. **扩展**：若后续加鉴权（Bearer/Signature），需与客户端同步发版联调。

---

## 8. 验收用例（后端必须全部通过）

| # | 场景 | 预期 |
|---|---|---|
| 1 | 首次启动（无 user_id） | 自动注册，返回非空 user_id；同 device_id 再次注册得到同一 id |
| 2 | 用户名绑定 | 仅传 username → 返回稳定 user_id；两台设备同名 → 同一 id |
| 3 | 解题上传（2 道小题） | 返回 2 个数字 id，顺序与 questions 一致；客户端历史 2 条均标记已同步 |
| 4 | **标记「正确」→ PATCH → 手动同步 → GET** | 本地与云端均为 `correct`；**状态不被清空**（v0.9.11 回归点） |
| 5 | 标记「部分错误」 | 云端 `user_feedback=partial`；GET 回传 partial；知识点 correct+1、wrong+1 |
| 6 | PATCH 重复调用 | 结果一致，不重复计数（幂等） |
| 7 | 删除记录 | DELETE 2xx；GET 不再返回该 id；重复 DELETE 仍 2xx |
| 8 | 离线解题后联网同步 | 单条补传返回 1 个 id；同 local_id 重复补传不产生重复行 |
| 9 | 批量上传未返回 id（异常） | 客户端保持未同步并重传；后端按 §3.6 去重不得产生脏数据 |
| 10 | 换机 + username 绑定 | GET 能拉回历史记录，且 `user_feedback/action_type` 原样恢复（含 partial） |
| 11 | 答案库上传 + 匹配 | 上传成功；匹配返回 `hit/similarity/answer`，`answer.knowledge_points` 为 **JSON 字符串** |
| 12 | `/healthz` | host 根路径返回 2xx（即使 Base URL 带 `/stapi` 前缀） |
| 13 | 缺字段容错 | GET 返回缺 `subject`/`knowledge_points`/`action_type` 时客户端不崩、按默认值展示 |

---

## 9. 不在本需求范围

- AI 模型调用与流式推理解析（客户端直连第三方 OpenAI 兼容端点）。
- 版本更新检查与 APK/EXE 下载（GitHub Releases）。
- 本地备份导入导出（纯客户端文件操作）。
- 图片存储/CDN（客户端当前不上传图片；`/files/upload` 可暂缓）。

---

## 10. 交付物清单（给后端）

1. 上述 12 个接口的可联调环境（Base URL 可配置）。
2. OpenAPI/Swagger（可选，但需与本契约字段一致）。
3. 数据库迁移脚本 + 字段说明。
4. 第 8 章 13 条验收用例的自测记录。
5. 若与本文档有偏差，逐条列出并说明原因，联调前双方确认。
