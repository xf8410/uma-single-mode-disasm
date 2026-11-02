# 上游追查：数值不在 `Define` 静态表

> 2026-11-02 12:01。三条现查证据 + 一条否定结论。

---

## 1. `SingleModeScenarioFestaDefine`：17 个字段，**没有增量表** **[测]**

`/debug/dumpclass` 全表：

| 偏移 | 字段 | 类型 |
|--:|:--|:--|
| 0–48 | `ACT_GAUGE_GAIN_BADGE_POSITION_*` ×7 | `Vector2`（**纯 UI 坐标**） |
| 56 | `COLOR_ADVICE_CHANGE` | `Color` |
| 72 | `ACT_MOTION_NAME_DIC` | `Dictionary<ActType, string>` |
| 80 / 88 | `CHECK_POINT_NAME_LIST` / `..._SHORT_NAME_LIST` | `IReadOnlyList<TextId>` |
| 96 / 104 / 112 / 120 | `AUTO_SETTING_*_DEGREE_LIST` ×4 | `IReadOnlyList<...>` |
| 128 / 136 | `SCENARIO_LINK_CHARA_ID_ARRAY` / `ENDING_LIVE_...` | `Int32[]` |

**关键否定**：这个类里**没有任何 `ActType → 增量` 的表**。
仅有的 `ActType` 相关字典是 `ACT_MOTION_NAME_DIC`（→ `string`，动画名）。

⚠️ 名称陷阱：`ACT_GAUGE_GAIN_BADGE_POSITION_*` 里带 `GAIN`，但类型是 `Vector2`，
是**角标位置**，与增量无关。**不能凭字段名当语义证据。**

---

## 2. `TrainingCommandRepository`：0 字段，6 个真方法 **[测]**

| 方法 | 参数 |
|:--|:-:|
| `Get` | — |
| `GetByBackup` | — |
| `GetList` | — |
| `GetListByBackup` | — |
| **`CreateCommandEntity`** | — |
| `get_FestaDataSet` / `get_ChangeParameterInfoScenarioFesta` | — |

**0 实例字段** ⇒ 它不持有命令实体，实体是**临时构造**的。
这也解释了为什么内存里找不到存活的 `TrainingCommandEntity` 去读字典。

---

## 3. `search_methods?keyword=GainActGauge`：20 个命中 **[测]**

12 个类里出现，可归类：

| 类别 | 类 |
|:--|:--|
| 数据（Obscured） | `ObscuredSingleModeFestaCommandGainActGauge` / `ObscuredSingleModeFestaPredictGainActGauge` / `ObscuredSingleModeFestaCommandInfo` |
| DataSet 访问器 | `ObscuredSingleModeFestaDataSet` / `WorkSingleModeScenarioFestaDataSet` |
| **实体** | `TrainingCommandEntity.GetGainActGaugeAmount` |
| **UI 控制器** | `TrainingParamChangeSharedPartsControllerScenarioFesta.SetupGainActGaugeAmount` |
| **UI 静态** | `TrainingParamChangeUI.SetParameterInfoByScenarioFestaGainActGauge`（3 参，static） |
| **UI 视图** | `PartsSingleModeScenarioFestaMainView.SetupGainActGaugeAmount`、`...MainViewActInfo.Setup/UpdateGainActGaugeAmount`、`...ActInfoList.Setup/Update/ResetGainActGaugeAmount` |
| 闭包 | `<>c__DisplayClass24_0.<SetupGainActGaugeAmount>b__0` |

**注意**：这些全是**读端**（显示用），没有一个看起来是"计算/来源"端。

---

## 4. 累积排除清单

| # | 已排除的来源 | 依据 |
|--:|:--|:--|
| 1 | getter 内计算 | `[码]` 纯 `TryGetValue` |
| 2 | 构造函数内内联常量 | `[码]` `found_constants` 为空 |
| 3 | MDB 表 `command_gain_act_gauge` | `[测]` 表不存在 |
| 4 | `SingleModeScenarioFestaDefine` 静态表 | `[测]` 17 字段无此表 |
| 5 | 通用集合装配层 `0x754342a684` | `[码]` 纯装配 |
| 6 | 内存里存活实体 | `[测]` Repository 0 字段，实体临时构造 |

**六条排除，一条没找到正面来源。**

---

## 5. 下一步：正面打 `CreateCommandEntity`

它是唯一同时满足「造实体」+「在 Repository 里」的方法。

该函数 2048 字节里含多个相邻函数（`GetList` 等），
需要**按 256 字节分块**取，落 `raw/` → CI → 在 asm 里搜
`bl #0x7547a5e304`（构造函数地址），命中的就是调用点，
其前面几条 `mov x1/x2/x3` 就揭示 `arg3`（那份集合）从哪来。

**这是目前唯一还没试的正面路径。**
