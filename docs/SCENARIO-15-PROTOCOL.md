# 剧本15 协议结构（msgpack 逐字段解码）

> 采集 2026-11-02 11:10，`POST /umamusume/single_mode_festa/load`，响应 25851 字节。
> 取数方式：`/api/sniff` 与 `/api/sniff/metadata` 均超 16 KiB 上限，
> 改用 `uma_protocol_metadata` 一次性取全部 10 条（5 请求 / 5 响应），**绕过限制成功**。

---

## 1. 传输层：**载荷不加密**

| 项 | 实测值 |
|:--|:--|
| Content-Type | `application/x-msgpack` |
| Body | **明文 msgpack**，可直接解码 **[测]** |
| APP-VER | `2.32.0` |
| RES-VER | `10021210:Tcxkvfn+yCx3` |
| ViewerID | `541816716` |
| Device | `2` / SubType `1` |
| SID | **每请求不同**（5 请求 5 个值） |

**结论：协议没有"加密"层，只有 msgpack 序列化 + 会话头。**
需要防的是签名与时效，不是解密。**[测]**

---

## 2. `home_info.command_info_array`（10 条）

### 2.1 普通训练（command_type = 1）

| command_id | 参数增量 `{target_type: value}` | is_enable | level |
|:-:|:--|:-:|:-:|
| **101** | `{1:+30}{3:+4}{30:+19}{10:−20}` | 1 | 1 |
| **102** | `{2:+9}{3:+14}{30:+14}{10:−21}` | 1 | 1 |
| **103** | `{1:+5}{3:+4}{4:+27}{30:+23}{10:−21}` | 1 | 1 |
| **105** | `{2:+15}{4:+4}{30:+10}{10:−16}` | 1 | 1 |
| **106** | `{1:+2}{5:+9}{30:+7}{10:+5}` | 1 | 1 |

每条另带：`training_partner_array`、`tips_event_partner_array: []`、`sub_command_partner_array: []`、`failure_rate: 0`。

### 2.2 其他命令（command_type 3 / 4 / 7 / 8）

| command_type | command_id | 参数数组 | is_enable |
|:-:|:-:|:--|:-:|
| 3 | 301 | **空** | 1 |
| 3 | 390 | **空** | 1 |
| 4 | 401 | **空** | **0** |
| 7 | 701 | **空** | 1 |
| 8 | 801 | **空** | 0 |

**这 5 条在本局全部无参数增量。**

---

## 3. 与 `CommandGainActGaugeArray` 的关系

| 事实 | 证据 |
|:--|:--|
| 该表只含 CommandType **3 / 4 / 7 / 8** | **[测]** 内存 |
| 速度训练是 `command_type 1 / command_id 101` | **[测]** 协议 |
| 故速度训练**不经过**该表 | **[测]** 两侧对照 |
| 该表 4 项预设 `{ActType 2, +1}` 与运行时 3/4/7/8 空参数的关系 | **[无证]** |

---

## 4. 演目进度增量的位置：**不在这条命令里**

command 101 的解码结果只含属性增量（`target_type` 1/2/3/4/5/10/30），
**没有任何演目（5101–5105）相关字段**。**[测]**

因此 11:07 那次速度训练实测的 `Act1 +2 / Act3 +1 / Act5 +1`
**来源不在 `command_info_array`**，需在训练完成后的请求里找。**[无证]**

---

## 5. `target_type` 语义

| target_type | 观测 | 语义 |
|:-:|:--|:--|
| 1 | 101 中 +30（最大项） | 未验证 **[无证]** |
| 2 | 102 中 +9 | 未验证 **[无证]** |
| 3 | 多条中 +4 / +14 | 未验证 **[无证]** |
| 4 | 103 中 +27 | 未验证 **[无证]** |
| 5 | 106 中 +9 | 未验证 **[无证]** |
| 10 | **每条训练均为负值** | 未验证 **[无证]** |
| 30 | 每条训练均为正值 | 未验证 **[无证]** |

> 曾口头把 10 说成「体力」、1/2/3/4/5 说成「速耐力根智」，
> **这些都没有直接证据**，本文档不采纳。需用「一次训练前后属性变化」实测确认。

---

## 6. 其他已确认存在但未完全解码的数组

| 数组 | 状态 |
|:--|:--|
| `evaluation_info_array` | 19 条，含 `target_id` / `evaluation` / `is_outing` / `story_step` |
| `training_level_info_array` | 10 条，command_id 落在 101–110 与 5101–5105 区间，level 多为 1 |
| `race_condition_array` / `race_random_program_array` | 存在，未解 |
| `support_card_array` | 6 条，含 `support_card_id` / `limit_break_count` / `exp` |
| `skill_array` / `skill_tips_array` | 存在，未解 |

---

## 7. 已知缺口

| # | 缺口 | 状态 |
|:-:|:--|:--|
| 1 | `command_id 104` 未出现在 `command_info_array`（但存在于 `training_level_info_array`） | 待确认是配置缺失还是解码遗漏 |
| 2 | `training_level_info_array` 头部标 10 条，解出的 id 数量与之不符 | **[低置信]**，未定 |
| 3 | 演目进度增量的真实来源 | 未定位 |
| 4 | `target_type` 全枚举 | 未验证 |
