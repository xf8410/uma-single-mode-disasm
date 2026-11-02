# uma-single-mode-disasm

剧本15（Single Mode / Scenario Festa）反汇编与协议解码档案。

> **纪律**：每条结论必须标证据 —— **[测]** 实测 / **[码]** 代码 / **[文]** 文档 / **[无证]** 未验证。
> 手解助记符一律标 **[手解·待复核]**，不当作结论引用。

---

## 一、结论速查

| 主题 | 结论 | 证据 |
|:--|:--|:-:|
| 协议载荷 | **不加密**，明文 msgpack | [测] |
| 协议嵌套 | 单条请求最长 **9 层** | [测] |
| 内存引用链 | **6 层** | [测] |
| 速度训练命令 | `command_type 1` / `command_id 101` | [测] |
| `CommandGainActGaugeArray` | 只含 type **3/4/7/8**，不参与普通训练 | [测] |
| `GetGainActGaugeAmount` | **无计算**，纯 `TryGetValue` 尾调用 | [码] |
| `_gainActGaugeAmountDict` | `IReadOnlyDictionary<ActType, Int32>`，偏移 **+24** | [码] |
| 字典填充点 | 构造函数内**一次外部调用**，非内联常量 | [手解·待复核] |
| 训练后 Act 对象 | **已被回收**，指针悬空 | [测] |

---

## 二、文档索引

| 文档 | 内容 |
|:--|:--|
| [`docs/SCENARIO-15-PROTOCOL.md`](docs/SCENARIO-15-PROTOCOL.md) | 协议 msgpack 逐字段解码、`command_info_array` 全表 |
| [`docs/NESTING-LAYERS.md`](docs/NESTING-LAYERS.md) | 嵌套层实测（协议 9 层 / 内存 6 层） |
| [`docs/OBSERVATION-POINTS.md`](docs/OBSERVATION-POINTS.md) | 训练结果可观测端点全表（8 个，成功失败都记） |
| [`docs/DISASM-GET-GAIN-ACT-GAUGE.md`](docs/DISASM-GET-GAIN-ACT-GAUGE.md) | getter 反汇编：值全由字典决定 |
| [`docs/DISASM-CREATE-COMMAND-ENTITY.md`](docs/DISASM-CREATE-COMMAND-ENTITY.md) | 命令实体构造入口反汇编 |
| [`docs/DISASM-ENTITY-CTOR.md`](docs/DISASM-ENTITY-CTOR.md) | 构造函数手解记录（**待 capstone 复核**） |
| [`docs/SCENARIO-15-GAUGE.md`](docs/SCENARIO-15-GAUGE.md) | 演目计量表与 `cset` 更正 |

---

## 三、关键地址

| 符号 | 地址 |
|:--|:--|
| `TrainingCommandEntity.GetGainActGaugeAmount` | `0x7547a565e0` |
| `TrainingCommandEntity..ctor` | `0x7547a5e304` |
| `TrainingCommandRepository.CreateCommandEntity` | `0x7547a62284` |
| `bl` 目标（构造函数内） | `0x70e43844` **[手解·待复核]** |

---

## 四、数据结构速查

### `TrainingCommandEntity`

| 偏移 | 字段 | 类型 |
|--:|:--|:--|
| +16 | CommandId | `TrainingCommandId` |
| **+24** | **`_gainActGaugeAmountDict`** | `IReadOnlyDictionary<ActType, Int32>` |
| +32 | IsUpperTrainingEventOccurred | `bool` |

### `WorkSingleModeScenarioFestaDataSet`

| 偏移 | 字段 |
|--:|:--|
| +16 | FestaInfo |
| +24 | CommandInfoArray |
| +32 | EvaluationInfoArray |
| +40 | AdviceInfoArray |
| **+48** | **ActInfoArray** |
| +56 | CheckPointResultArray |
| +64 | CommandGainActGaugeArray |
| +72 | NotUpParameterInfo |
| +80 | AutoSettingInfo |

> 字段偏移**每次现查** `/il2cpp/dump`，不背。

---

## 五、工具链

```
raw/<name>_0x<addr>.txt   ← /il2cpp/disassemble 的 hex（"0000: xx xx ..." 格式）
        │
        ▼  GitHub Actions: .github/workflows/disasm.yml
      tools/disasm.py  (capstone)
        │
        ▼
out/<name>.asm      逐条汇编
out/<name>.consts   立即数扫描
```

**手解禁止入结论**：先落 `raw/` → CI 出 asm → 再讨论语义。

---

## 六、已知缺口

| # | 缺口 | 状态 |
|:-:|:--|:--|
| 1 | `_gainActGaugeAmountDict` 的填充逻辑 | [无证] |
| 2 | 演目进度增量的真实来源 | [无证] |
| 3 | 命令条数三处不一致（12 / 10 / 7） | [无证] |
| 4 | `target_type` 全枚举语义 | [无证] |
| 5 | `+0x20` 的 `& 3` 承载几个布尔 | [无证] |
