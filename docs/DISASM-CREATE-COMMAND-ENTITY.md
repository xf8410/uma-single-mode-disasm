# CreateCommandEntity 反汇编记录 + TrainingCommandEntity 字段

> 2026-11-02 11:40 现取。`/il2cpp/disassemble?class=TrainingCommandRepository&method=CreateCommandEntity`

---

## 1. 基本参数 **[测]**

| 项 | 值 |
|:--|:--|
| method_addr | `0x7547a62284` |
| bytes_read | **2048** |
| code_section | `0x6d824b4000-0x778d21c000` |
| ret_offsets | `[640, 892, 1036, 1528, 1672, 1812, 1968]` |
| found_constants | **空** |

**`found_constants` 为空 ⇒ 函数体里没有 202 / 203 之类的明文立即数。**
（与之前字节扫描结论一致：`0x52801940` / `0x52801960` 均未出现）

---

## 2. 关键发现：这 2048 字节不是一个函数

`ret_offsets` 有 **7 个**，且偏移 640/892/1036/1528/1672/1812/1968 处都是 `c0 03 5f d6`（`ret`）收尾。

逐段看，段首都是**标准的函数序言**：

| 段起点 | 序言 | 判断 |
|--:|:--|:--|
| `0x00` | `ff 43 02 d1` sub sp,sp,#0x90 | 主函数 |
| `0x0284` | `fe 0f 1d f8` str x30,[sp,#-0x30]! | 新函数 |
| `0x0388` | `fe 0f 1e f8` | 新函数 |
| `0x0414` | `fe 0f 1d f8` | 新函数 |
| `0x04d4` | `fe 0f 1d f8` | 新函数 |
| `0x05a4` | `fe 0f 1e f8` | 新函数 |
| `0x0604` | `ff 83 01 d1` sub sp,sp,#0x60 | 新函数 |
| `0x0694` | `ff 83 01 d1` | 新函数 |
| `0x0724` | `ff 83 01 d1` | 新函数 |
| `0x07b8` | `ff 83 01 d1` | 新函数 |

⇒ **该端点按「地址 + 2048 字节」返回，不按函数边界裁剪。**
所以「7 个 ret」不是 7 条出口，而是**至少 10 个相邻函数**。

**这条必须记下来**：以后不能把 `ret_offsets` 当成单条函数的出口数。

---

## 3. 顺带确认一条手解错误

`0x0794` 附近：

```
08 12 40 b9   ldr w8, [x0, #0x10]
1f 00 08 6b   cmp w0, w8
e0 17 9f 1a   cset w0, eq
```

`e0 17 9f 1a` = **`cset w0, eq`**（capstone 输出）。
与 `SCENARIO-15-GAUGE.md` 的更正一致，**`ne` 是错的**。

这段逻辑：取 `[x0 + 0x10]`（`TrainingCommandEntity.CommandId`）与另一值比较，
返回布尔 ⇒ 是 **CommandId 相等判断**。**[码]**

---

## 4. `TrainingCommandEntity` 字段表 **[码]**

`/il2cpp/dump` 现查：

| 偏移 | 字段 | 说明 |
|--:|:--|:--|
| +16 | CommandId | `ObscuredInt` |
| **+24** | **`_gainActGaugeAmountDict`** | 字典（type 21） |
| +32 | IsUpperTrainingEventOccurred | bool |

**演练目标就在这里**：`+24` 那个字典，键应为 ActType，值为增量。
本局尚未读该字典实例 —— **[未验证]**。

---

## 5. 尚未完成

| # | 待办 | 状态 |
|:-:|:--|:--|
| 1 | 定位 live `TrainingCommandEntity` 实例并读 `+24` 字典 | 未做 |
| 2 | 用 capstone 把 2048 字节拆成可读 asm | 未做（hex 未入 raw/） |
| 3 | 命令条数 12 / 10 / 7 的差异 | 未做 |
| 4 | `target_type` 语义 | 未做 |

---

## 6. 方法结论

- `/il2cpp/disassemble` 只返回 hex，**不给助记符**，且**不按函数边界裁剪**
- 手工翻译 2048 字节不可靠（已有 `cset ne` 的前车之鉴）
- 正确路径：hex 入 `raw/` → CI capstone → `out/*.asm`

**本轮未把 hex 写入 `raw/`，因为需逐字节转录 2048 字节，转录错误会污染反汇编结果。**
下一步应考虑让工具直接落盘，而不是人肉抄写。
