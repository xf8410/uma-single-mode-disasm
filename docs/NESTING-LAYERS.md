# 嵌套层：实测的深度清单

> 这份文件是对此前判断的**更正**。
> 我之前多次表示「嵌套层很少 / 没有更多层」，**这个判断是错的**。
> 下面只列能在数据里指认出来的层，逐层给证据。

---

## 1. 协议层：单条请求最长 **9 层**

以 `/umamusume/single_mode_festa/load` 响应为例，msgpack 逐层剥开：

| 层 | 内容 | msgpack 标记 |
|:-:|:--|:--|
| 1 | 根 map（3 键） | `83` |
| 2 | `data` → map（2 键） | `82` |
| 3 | `single_mode_load_common` → map（29 键） | `de 00 1d` |
| 4 | `home_info` → map（13 键） | `8d` |
| 5 | `command_info_array` → 数组（10 条） | `9a` |
| 6 | `[0]` → map | `89` |
| 7 | `params_inc_dec_info_array` → 数组 | `94` |
| 8 | `[0]` → map（2 键） | `82` |
| 9 | `target_type` → 整数 | — |

**证据 [测]**：取响应 id=6 的 `body_hex`，按上表逐个定位标记字节，全部命中。

> 同一响应里还有更深的并列分支，例如
> `skill_upgrade_info_array → [n] → condition_id / total_count / current_count`，
> 以及 `reserved_race_array → race_array → [n] → year / program_id`，深度与上表相当。

---

## 2. 内存对象层：**6 层**

`CommandGainActGaugeArray` 这条链：

| 层 | 对象 | 证据 |
|:-:|:--|:--|
| 1 | `WorkSingleModeScenarioFesta`（scenario_obj `0x76c065e000`） | [测] `/scenario` |
| 2 | `WorkSingleModeScenarioFestaDataSet`（`+0x00` 起） | [测] |
| 3 | `+0x40` `CommandGainActGaugeArray`（T[]） | [码] dump 字段表 |
| 4 | 元素 `ObscuredSingleModeFestaCommandGainActGauge` | [测] |
| 5 | `+0x28` `PredictGainActGaugeArray`（T[]） | [测] |
| 6 | 元素 `ObscuredSingleModeFestaPredictGainActGauge`（ActType / GainActGauge） | [测] |

演目这条链：

| 层 | 对象 |
|:-:|:--|
| 1 | scenario |
| 2 | DataSet |
| 3 | `+0x30` `ActInfoArray`（T[]） |
| 4 | 元素 `ObscuredSingleModeFestaActInfo`（7 个加密字段） |

---

## 3. `WorkSingleModeScenarioFestaDataSet` 权威字段表 **[码]**

| 偏移 | 字段 | 类型 |
|--:|:--|:-:|
| +16 | FestaInfo | 18 |
| +24 | CommandInfoArray | 29 (数组) |
| +32 | EvaluationInfoArray | 29 |
| +40 | AdviceInfoArray | 29 |
| +48 | **ActInfoArray** | 29 |
| +56 | CheckPointResultArray | 29 |
| +64 | CommandGainActGaugeArray | 29 |
| +72 | NotUpParameterInfo | 18 |
| +80 | AutoSettingInfo | 18 |

**这张表必须每次现查**，不能靠记忆。

---

## 4. 失败记录：训练多次后的读取

2026-11-02 11:13，用户训练数次后：

| 步骤 | 结果 |
|:--|:--|
| `/scenario` | 新 dataset `0x6dc623f540`，`CommandInfoArray` len **5 → 7** |
| `+0x30` → `ActInfoArray` | `0x6dc616f960`，len 5，5 个元素指针 |
| 逐个读元素 | **元素 klass 被清零**（`00 00 00 00 …`），即对象已回收 |

**结论：旧 dataset 里的 act 对象在训练后被释放，指针悬空。**
读出来的数值无效，**本轮不给增量数据**。

教训：**每次读数前必须重新 `/scenario` 取链**，且要验证元素 klass 非零，
不能只看 `read_mem` 返回 `bytes_read: 160` 就当成有效。

---

## 5. 端点限制：`/il2cpp/tree` 用不了

| 尝试 | 返回 |
|:--|:--|
| `/il2cpp/tree?name=TrainingCommandEntity` | `singleton_null` |
| `/il2cpp/tree?name=WorkSingleModeScenarioFesta` | `singleton_null` |

**该端点只对 singleton 生效**，普通实体类取不到继承/嵌套树。
所以「类继承层数」目前**无法测量** **[无证]**，只能测「对象引用层数」（第 2 节）。

---

## 6. 结论

| 说法 | 判定 |
|:--|:--|
| 协议嵌套约 9 层 | **[测]** 逐标记验证 |
| 内存引用链 6 层 | **[测]** 逐指针验证 |
| 「嵌套层很少」 | **撤回，错误** |
| 类继承层数 | **[无证]**，端点不支持 |
