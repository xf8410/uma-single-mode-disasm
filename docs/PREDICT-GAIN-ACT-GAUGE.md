# 找到了：增量值来自协议层的 `PredictGainActGaugeArray`

> 2026-11-02 15:07 现查。全部 **[测]**（`/debug/dumpclass` 直接读字段表）。

---

## 1. 完整数据链

```
协议 msgpack
   └─ command_info_array[i]
        ├─ command_type        (ObscuredInt)
        ├─ command_id          (ObscuredInt)
        ├─ params_inc_dec_info_array
        ├─ predict_gain_act_gauge_array   ← ★ 就是它
        └─ is_upper_training_event_occurred (ObscuredBool)
              │
              ▼  客户端反序列化
        ObscuredSingleModeFestaCommandInfo
              │
              ▼  TrainingCommandRepository.CreateCommandEntity
        TrainingCommandEntity
              └─ _gainActGaugeAmountDict : IReadOnlyDictionary<ActType,int>
```

---

## 2. 字段表对照 **[测]**

### `ObscuredSingleModeFestaCommandInfo`（数据集 `+24` 的元素）

| 偏移 | 字段 | 类型 |
|--:|:--|:--|
| +16 | CommandType | `ObscuredInt` |
| +36 | CommandId | `ObscuredInt` |
| +56 | ParamsIncDecInfoArray | `SingleModeParamsIncDecInfo[]` |
| **+64** | **PredictGainActGaugeArray** | `ObscuredSingleModeFestaPredictGainActGauge[]` |
| +72 | IsUpperTrainingEventOccurred | `ObscuredBool` |

### `ObscuredSingleModeFestaPredictGainActGauge`（就是那对键值）

| 偏移 | 字段 | 类型 |
|--:|:--|:--|
| +16 | **ActType** | `ObscuredInt` |
| +36 | **GainActGauge** | `ObscuredInt` |

**两个字面字段：一个 act 编号，一个增量。没有第三层。**

### `TrainingCommandEntity`（投影结果）

| 偏移 | 字段 | 对应来源 |
|--:|:--|:--|
| +16 | CommandId | ← CommandInfo `+36` |
| **+24** | `_gainActGaugeAmountDict` | ← **CommandInfo `+64` 数组转换而来** |
| +32 | IsUpperTrainingEventOccurred | ← CommandInfo `+72` |

---

## 3. 结论

**增量的数值不在客户端。**

- 不是 `SingleModeScenarioFestaDefine` 的常量（该表不存在）
- 不是 MDB 表（该表不存在）
- 不是 getter 里算的（纯 `TryGetValue`）
- 不是构造函数里写的常量（`found_constants` 为空）

**它随 `command_info` 一条一条从服务器下发。**

⇒ 之前六条排除全部为空的**原因就是这个**：我在客户端找一张本来就不存在的表。

---

## 4. 这也解释了「buff 跟着卡走」 **[文→测]**

服务器已经算好了「这条训练命令上，哪些 act 各加多少」，客户端只负责显示。

卡一挪动 ⇒ 服务器下一帧下发的 `predict_gain_act_gauge_array` 就换了归属
⇒ 客户端字典跟着重建 ⇒ 角标跟随。

**客户端没有位置逻辑，位置逻辑在服务器。**

---

## 5. 待验证

| # | 待办 | 方法 |
|:-:|:--|:--|
| 1 | 协议报文里是否真的带 `predict_gain_act_gauge_array` 字段 | 抓一次 `/api/sniff`，在 `command_info_array` 里搜 |
| 2 | 该数组长度与 `ActType` 5 个成员的关系 | 同上 |
| 3 | 命令条数 12 / 10 / 7 的差异 | 用本字段做锚点重新数 |

**第 1 条是关键**：如果报文里有，链路闭合，剩下的都是工程量；如果没有，说明还有一层换算没找到。
