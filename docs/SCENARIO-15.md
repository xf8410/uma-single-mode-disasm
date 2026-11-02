# 剧本15（Festa / 骏大祭）实测记录

> 采集时间 2026-11-02，游戏处于育成主界面。
> 证据标记：`[表]` MDB / `[码]` 反汇编·类型系统 / `[测]` 内存实测 / `[文]` UI 文案 / `[无证]` 无证据。

---

## 1. 地址链（现取现用，跨操作失效）

```
/scenario
 └ scenario_obj = 0x76c065e000   (WorkSingleModeScenarioFesta)
   dataset_obj  = 0x76a35ff5a0   (WorkSingleModeScenarioFestaDataSet)
        +0x10 FestaInfo                = 0x76a353c9c0
        +0x18 CommandInfoArray         = 0x76aad13910   len 5
        +0x20 EvaluationInfoArray      = 0x76a3601690
        +0x28 AdviceInfoArray          = 0x76aad13870
        +0x30 ActInfoArray             = 0x76aad13820   len 5
        +0x38 CheckPointResultArray    = 0x76a35f5480
        +0x40 CommandGainActGaugeArray = 0x76aad137d0   len 4
        +0x48 NotUpParameterInfo       = 0x76aad1cd40
        +0x50 AutoSettingInfo          = 0x76aad1cd00
```

`+0x10 ~ +0x50` 全部由 `/scenario` + 一次 `read_mem(0x76a35ff5a0, size=0x400)` 得来。**[测]**

---

## 2. 运行时类字段表

### 2.1 `ActEntity`（Gallop.SingleMode.ScenarioFesta）

**9 字段，全是裸 int32 —— 不加密。** **[码]**

| 偏移 | 字段 | 类型 |
|--:|:--|:--|
| +16 | ActType | ActType 枚举 |
| +20 | AttachedAdviceId | int32 |
| +24 | ActMemberCharaIdList | IReadOnlyList\<int\> |
| +32 | MaxActTrainingLevel | int32 |
| +36 | ActTrainingState | ActTrainingState 枚举 |
| +40 | ActTrainingEffectVo | ActTrainingEffectVO |
| +48 | UrafActTrainingEffectVo | UrafActTrainingEffectVO |
| +56 | CurrentActGauge | int32 |
| **+60** | **LevelUpByFriendOuting** | int32 |

> ⚠️ **易错点**：`FriendOutingGainActLevel = +0x88` 属于 **master 行类**
> `ObscuredSingleModeFestaActInfo`，**不是**运行时 `ActEntity`。两套偏移不能混用。

### 2.2 `TrainingCommandEntity`

| 偏移 | 字段 |
|--:|:--|
| +16 | CommandId |
| **+24** | **`_gainActGaugeAmountDict`（Dictionary）** |
| +32 | IsUpperTrainingEventOccurred（bool） |

- 填充点：`TrainingCommandRepository.CreateCommandEntity` **[码]**
- 取用点：`TrainingCommandEntity.GetGainActGaugeAmount` @ `0x7547a565e0` **[码]**
- 该方法整段 2048 字节**无 202/203 立即数**（扫 `0x52801940` / `0x52801960`）**[码]**
- 字典内容：**未读到** **[无证]**

### 2.3 进度字典的两层结构

| 类 | 字段 |
|:--|:--|
| `ObscuredSingleModeFestaCommandGainActGauge` | +16 CommandType / +40 PredictGainActGaugeArray |
| `ObscuredSingleModeFestaPredictGainActGauge` | +16 ActType / +36 GainActGauge |

`[码]` `/il2cpp/dump` 实测。

---

## 3. `CommandGainActGaugeArray` 全表

key 恒为 `0x6C81C`，`value = int2 ^ int1`。**[测]**

| idx | 对象 | CommandType | PredictGainActGaugeArray | 内容 |
|:-:|:--|:-:|:--|:--|
| 0 | `0x76aad1ce40` | **3** | `0x76a35f5450` len 1 | `{ActType 2, Gain 1}` @`0x76aad1de40` |
| 1 | `0x76aad1ce00` | **4** | `0x76a35f5420` len 1 | `{ActType 2, Gain 1}` @`0x76aad1de00` |
| 2 | `0x76aad1cd80` | **8** | `0x76a35f53c0` **len 0** | 空 |
| 3 | `0x76aad1cdc0` | **7** | `0x76a35f53f0` len 1 | `{ActType 2, Gain 1}` @`0x76aad1ddc0` |

**观察**：3 / 4 / 7 都只给 ActType 2 加 1 格；8 不给任何演目加进度。
**CommandType 与训练种类的对应表未查** **[无证]**。

### 原始字节

```
# 数组头 @0x76aad137d0
+0x18: 04 00 00 00            -> len 4
+0x20: 40 ce d1 aa 76 00 00 00
+0x28: 00 ce d1 aa 76 00 00 00
+0x30: c0 cd d1 aa 76 00 00 00
+0x38: 80 cd d1 aa 76 00 00 00

# 元素 0 @0x76aad1ce40
+0x10: 1c c8 06 00 | 1f c8 06 00   -> 0x6C81C ^ 0x6C81F = 3  (CommandType)
+0x28: 50 54 5f a3 76 00 00 00     -> 0x76a35f5450

# 预测数组 @0x76a35f5450
+0x18: 01 00 00 00                 -> len 1
+0x20: 40 de d1 aa 76 00 00 00     -> 0x76aad1de40

# 预测元素 @0x76aad1de40
+0x10: 1c c8 06 00 | 1e c8 06 00   -> 2  (ActType)
+0x24: 1c c8 06 00 | 1d c8 06 00   -> 1  (GainActGauge)

# 元素 1 @0x76aad1ce00
+0x10: 1c c8 06 00 | 18 c8 06 00   -> 4
+0x28: 20 54 5f a3 76 00 00 00     -> 0x76a35f5420

# 元素 2 @0x76aad1cd80
+0x10: 1c c8 06 00 | 14 c8 06 00   -> 8
+0x28: c0 53 5f a3 76 00 00 00     -> 0x76a35f53c0 （len 0）

# 元素 3 @0x76aad1cdc0
+0x10: 1c c8 06 00 | 1b c8 06 00   -> 7
+0x28: f0 53 5f a3 76 00 00 00     -> 0x76a35f53f0
```

---

## 4. 教誨 / 助力（MDB）

### 4.1 `single_mode_15_advice` 全表 10 行 **[表]**

| id | fusion_type | add_schedule_type |
|--:|:-:|:-:|
| 101 | 1 | 1 |
| 201 | 1 | 1 |
| 301 | 1 | 1 |
| **401** | 1 | 1 |
| 501 | 1 | 1 |
| 601 | 2 | 2 |
| 701 | 2 | 2 |
| 801 | 2 | 3 |
| 901 | 2 | 3 |
| 1001 | 2 | 3 |

### 4.2 `single_mode_15_advice_effect` advice_id=401（助力教誨）

每级 2 行，共 20 行 **[表]**：

| level | effect_type | condition_type | effect_value_2 / _4 |
|:-:|:-:|:-:|:-:|
| 1 | 203 | 3 | 20 |
| 2 | 203 | 3 | 22 |
| 3 | 203 | 3 | 24 |
| 4 | 203 | 3 | 26 |
| 5 | 203 | 3 | 28 |
| 6 | 203 | 3 | 30 |
| 7 | 203 | 3 | 32 |
| 8 | 203 | 3 | 34 |
| 9 | 203 | 3 | 37 |
| 10 | 203 | 3 | 40 |

外加每级一行：`effect_type 20 / condition_type 0 / effect_value_4 = 47`（恒定，语义 **[无证]**）。

**UI 交叉验证** **[文]**：游戏内「未触发友情训练时训练效果提升 20%…40%」——
与 20→40 完全一致 ⇒ **`condition_type 3` = 未触发友情训练**。

### 4.3 助力支撑

**UI 原文** **[文]**：「演目排练中获得『助力支撑』（最多 3 次 训练效果提升 5%）」
⇒ 固定 5%、可用 3 次，不随演目等级变。

`single_mode_15_act_effect` 的 `effect_type 202`（Lv1→10 = 2,3,4,5,6,7,8,10,12,15）
**不是**助力支撑。其语义 **[无证]**。

助力支撑的 `5` 与 `3` 落在哪个字段：**未找到** **[无证]**。

---

## 5. 友人外出（吾妻）

- `single_mode_15_outing_effect` 仅 4 列：`support_card_id / story_step / add_level`，**无 act_type 列** **[表]**
- 因此「加给哪个演目」不在表里，由运行时决定 **[表]**
- 运行时 `ActEntity.LevelUpByFriendOuting`（+60）在观测时全为 0 **[测]**
- 选择逻辑位于 `DialogSingleModeScenarioFestaOutingPartnerSelectItemViewModel`，
  其 `ActTypeLevelUpByFriendOutingDict` 由构造器生成；**比较规则未解出** **[无证]**

---

## 6. 加密

| 项 | 值 |
|:--|:--|
| `Obscured*` 类数量 | **315** **[码]** |
| 布局 | 20 字节/字段 **[测]** |
| 解码 | `value = [4] ^ [0]` **[测]** |
| 本局 key | `0x6C81C`（全局，同批对象一致） **[测]** |
| 跨进程是否变 | 未验证 **[无证]** |
| 运行时实体是否加密 | **否**，裸 int32 **[测]** |

两套并存：模型/DTO 层加密，运行时工作对象明文。

---

## 7. 待办

| # | 事项 | 状态 |
|:-:|:--|:--|
| 1 | `CreateCommandEntity` 反汇编，确认字典由谁填 | 未做 |
| 2 | `_gainActGaugeAmountDict` 内容与 `CommandGainActGaugeArray` 是否同源 | 未验证 |
| 3 | CommandType → 训练种类 对应 | 未查 |
| 4 | 友人外出「同级优先」比较规则 | 未解出 |
| 5 | 助力支撑 5/3 的存储位置 | 未找到 |
| 6 | `effect_type 202` 语义 | 未验证 |
| 7 | `effect_type 20 / value 47` 语义 | 未验证 |
| 8 | `condition_type` 全枚举 | 仅确认 3 |
