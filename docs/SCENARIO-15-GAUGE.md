# 剧本15 演目进度增量（CommandGainActGaugeArray）实测

> 采集 2026-11-02 10:47，育成主界面。
> 所有数值均为 `read_mem` 原始字节按 `value = [4] ^ [0]` 解出，可逐字节复算。

---

## 1. 结构（两层）

| 类 | 字段 |
|:--|:--|
| `ObscuredSingleModeFestaCommandGainActGauge` | +16 `CommandType` / +40 `PredictGainActGaugeArray` |
| `ObscuredSingleModeFestaPredictGainActGauge` | +16 `ActType` / +36 `GainActGauge` |

`[码]` `/il2cpp/dump` 实测。

---

## 2. 全 4 项（本局快照）

key 恒 `0x6C81C`。`[测]`

| idx | 对象地址 | CommandType | 预测数组 | 长度 | 内容 |
|:-:|:--|:-:|:--|:-:|:--|
| 0 | `0x76aad1ce40` | **3** | `0x76a35f5450` | 1 | `{ActType 2, GainActGauge 1}` |
| 1 | `0x76aad1ce00` | **4** | `0x76a35f5420` | 1 | `{ActType 2, GainActGauge 1}` |
| 2 | `0x76aad1cd80` | **8** | `0x76a35f53c0` | **0** | 空 |
| 3 | `0x76aad1cdc0` | **7** | `0x76a35f53f0` | 1 | `{ActType 2, GainActGauge 1}` |

**观察**：3 / 4 / 7 都只给 ActType 2 加 1 格；8 不加任何演目。

---

## 3. 原始字节

```
# 容器数组 @0x76aad137d0  (dataset +0x40)
+0x18: 04 00 00 00                      -> len 4
+0x20: 40 ce d1 aa 76 00 00 00
+0x28: 00 ce d1 aa 76 00 00 00
+0x30: c0 cd d1 aa 76 00 00 00
+0x38: 80 cd d1 aa 76 00 00 00

# idx0 @0x76aad1ce40
+0x10: 1c c8 06 00 | 1f c8 06 00   -> 0x6C81C ^ 0x6C81F = 3
+0x28: 50 54 5f a3 76 00 00 00     -> 0x76a35f5450
#   预测数组 len 1 -> 元素 0x76aad1de40
#   +0x10: 1c c8 06 00 | 1e c8 06 00 -> 2   (ActType)
#   +0x24: 1c c8 06 00 | 1d c8 06 00 -> 1   (GainActGauge)

# idx1 @0x76aad1ce00
+0x10: 1c c8 06 00 | 18 c8 06 00   -> 4
+0x28: 20 54 5f a3 76 00 00 00     -> 0x76a35f5420 (len 1 -> 0x76aad1de00)

# idx2 @0x76aad1cd80
+0x10: 1c c8 06 00 | 14 c8 06 00   -> 8
+0x28: c0 53 5f a3 76 00 00 00     -> 0x76a35f53c0 (len 0)

# idx3 @0x76aad1cdc0
+0x10: 1c c8 06 00 | 1b c8 06 00   -> 7
+0x28: f0 53 5f a3 76 00 00 00     -> 0x76a35f53f0 (len 1 -> 0x76aad1ddc0)
```

对象步长 **0x40**，四个元素在内存里连续排列 —— 可用一次 `read_mem(..., size=128)` 读两个。

---

## 4. 数据来源：**不是 MDB**

见 `SCENARIO-15-TABLES.md`：剧本15 的 12 张表里没有任何 gauge 表，
`single_mode_15_command_gain_act_gauge` 直接 `query_failed`。**[表]**

⇒ 来源只可能是「代码常量」或「运行时计算」。**是哪种未验证 [无证]。**

---

## 5. 更正：METHOD.md 里一条手解错误

`METHOD.md` §3.1 指令对照表把

```
e0 17 9f 1a
```

写成 `cset w0, ne`。**错了，应为 `cset w0, eq`。**

依据：CI 用 capstone 反汇编 run `41380464073` 的输出

```
0x7547a565f0  e0 17 9f 1a  cset  w0, eq
```

**以后手解一律以 capstone 输出为准，不以记忆为准。**

---

## 6. 未验证项

| 项 | 状态 |
|:--|:--|
| `CommandType`（3/4/7/8）与训练种类的对应 | **[无证]** |
| 与 `TrainingCommandEntity._gainActGaugeAmountDict` 是否同源 | **[无证]** |
| 换一局后是否这 4 项仍相同 | **[无证]** |
| 内存读数与游戏内实际格子变化是否一致 | **待黑盒实测** |
