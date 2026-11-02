# `TrainingCommandEntity.GetGainActGaugeAmount` 反汇编解读

> 2026-11-02 11:45 现取。
> `/il2cpp/disassemble?class=TrainingCommandEntity&method=GetGainActGaugeAmount`
> `method_addr = 0x7547a565e0`，`bytes_read = 2048`

---

## 1. 先记方法学

`ret_offsets` 本次有 **17 个**：

```
132, 404, 444, 804, 828, 876, 944, 988, 1016,
1060, 1104, 1140, 1168, 1212, 1220, 2012, 2028
```

**同样不是 17 条出口** —— 与 `CreateCommandEntity` 那次一样，
该端点按「地址 + 2048 字节」返回一整块代码，**里面是多个函数**。

只有 `0x0000` 起那一段是 `GetGainActGaugeAmount` 本体。

---

## 2. 本体只有 ~24 条指令 **[码]**

```asm
0000  fe 0f 1d f8   str   x29, [sp, #-0x30]!
0004  f6 57 01 a9   stp   x22, x21, [sp, #0x10]
0008  f4 4f 02 a9   stp   x20, x19, [sp, #0x20]
000c  b6 49 02 f0   adrp  x22, ...
0010  f5 ab 00 90   adrp  x21, ...
0014  c8 f6 69 39   ldrb  w8, [x22, #0x27d]     ; 静态初始化标志
0018  b5 0a 46 f9   ldr   x21, [x21, #0xc10]
001c  f3 03 01 2a   mov   w19, w1                ; ← 参数2 = ActType
0020  f4 03 00 aa   mov   x20, x0                ; ← 参数1 = this
0024  c8 00 00 37   tbnz  w8, #0, +0x30          ; 已初始化则跳过
...
0038  28 00 80 52   mov   w8, #1
003c  c8 f6 29 39   strb  w8, [x22, #0x27d]
0040  80 0e 40 f9   ldr   x0, [x20, #0x18]       ; ← this + 0x18 = _gainActGaugeAmountDict
0044  a3 02 40 f9   ldr   x3, [x21]
0048  e1 03 13 2a   mov   w1, w19                ; key = ActType
004c  f4 4f 42 a9   ldp   x20, x19, [sp, #0x20]
0050  e2 03 1f 2a   mov   w2, wzr                ; out value 初值 0
0054  fe 07 43 f8   ldr   x29, [sp], #0x30
0058  68 ba e3 16   b     <Dictionary.TryGetValue>  ; **尾调用**
```

---

## 3. 结论：这个 getter 里**没有任何计算**

| 观察 | 证据 |
|:--|:--|
| `+0x18` 被当作字典基址读出 | `ldr x0, [x20, #0x18]` **[码]** |
| 键来自参数 `w1`（ActType 枚举） | `mov w1, w19` **[码]** |
| 直接尾调 `TryGetValue`，**没有回退分支、没有算术、没有立即数** | `b` + `found_constants: []` **[码]** |

**⇒ 返回值 100% 由 `_gainActGaugeAmountDict` 决定，getter 不做任何变形。**

这条同时否定了「getter 里可能藏着公式」的猜想 —— 以前我不敢排除这条。

---

## 4. 字典的完整类型 **[码]**

`/debug/dumpclass?name=TrainingCommandEntity`：

```
System.Collections.Generic.IReadOnlyDictionary<
    Gallop.SingleMode.ScenarioFesta.SingleModeScenarioFestaDefine.ActType,
    System.Int32>
```

- 键类型：**`ActType` 枚举**（剧本15 专用命名空间 `ScenarioFesta`）
- 值类型：`int`
- 字段偏移：**+24**

⇒ 这就是「哪个演目加几格」的权威数据结构。

---

## 5. 唯一未解的一环

**字典由谁填充？** 目前**没有证据**。

已排除的：

| 猜想 | 结论 |
|:--|:--|
| getter 内计算 | **否**，见 §3 |
| 来自 MDB 表 `command_gain_act_gauge` | **否**，该表不存在（早前 `query_failed`） |

未做的：

| # | 待办 |
|:-:|:--|
| 1 | 反汇编 `TrainingCommandEntity..ctor`（构造函数）—— 最可能的填充点 |
| 2 | 反汇编 `TrainingCommandRepository.CreateCommandEntity` 里**传入 dict 的那段**（`0x00`–`0x0280` 段内有大量 `ldr [x8,#...]` 间接取址，需逐条核） |
| 3 | 定位 live 实例读字典（若实体是临时的，可能读不到） |

---

## 6. 一处必须纠正的旧说法

我此前把 `0x7547a565e0` 用作 **capstone 自检样本地址**，
那是随手取的 8 条已知语义指令，**不是任何真实方法的片段**。

现在这个地址确认归属 `TrainingCommandEntity.GetGainActGaugeAmount`。
两者**没有关系**，不要混淆。
