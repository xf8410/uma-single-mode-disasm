# 方法论：怎么找到、怎么反汇编、需要准备什么

> 这份文档回答三个问题：**从哪儿入手**、**用什么工具**、**踩过哪些坑**。
> 所有端点、参数、返回值结构均为实测 **[测]**。

---

## 0. 前置准备

| 项 | 要求 |
|:--|:--|
| 环境 | 安卓设备（已 root 或可注入），游戏运行中 |
| 注入层 | `hlpatch` 的 so，提供本地 HTTP 端点 |
| 端点基址 | `127.0.0.1:18765` |
| Unity 后端 | IL2CPP（`libil2cpp.so` + `global-metadata.dat`） |
| 必要状态 | **游戏停在育成主界面且静止**（换界面会重建对象，地址全失效） |

**开局第一件事**：确认 SO 活着，再取一次链。不要复用旧地址。

---

## 1. 端点清单（实测可用）

### 1.1 场景/状态

| 端点 | 作用 | 关键返回 |
|:--|:--|:--|
| `/scenario` | 当前剧本与数据集根 | `scenario_id`、`dataset_obj`、部分数组指针 |

### 1.2 类型系统

| 端点 | 作用 | 示例 |
|:--|:--|:--|
| `/il2cpp/classes` | 全类清单（32000+ 类） | 大，慎用全量 |
| `/il2cpp/search_classes?keyword=X` | 按类名模糊搜 | `keyword=Obscured` → 315 命中 |
| `/il2cpp/search_methods?keyword=X` | 按方法名模糊搜 | 返回 class / ns / params / return_type |
| `/il2cpp/dump?name=X` | 类字段表 + 实例指针 | **字段偏移的主来源** |
| `/il2cpp/disassemble?class=X&method=Y` | 方法体 | `method_addr` + `hex_dump` |
| `/il2cpp/call?class=X&method=Y` | 调用方法 | **只支持 singleton**，否则 `singleton_null` |

### 1.3 内存

| 端点 | 作用 | 备注 |
|:--|:--|:--|
| `/il2cpp/read_mem?addr=0x...` | 读内存 | 默认 4096 字节 |
| `/il2cpp/read_mem?addr=0x...&size=64` | **指定长度** | 关键技巧，见 §4 |

### 1.4 主数据（MDB）

| 端点 | 作用 |
|:--|:--|
| `/mdb/raw?sql=SELECT ...` | 直接 SQL 查询游戏内嵌表 |

表命名规律：`single_mode_<剧本号>_<模块>`，例：
`single_mode_15_advice`、`single_mode_15_advice_effect`、`single_mode_15_act_effect`、`single_mode_15_outing_effect`。

---

## 2. 标准定位流程

```
/search_classes  找类名
      ↓
/dump?name=X     拿字段偏移（判断加密与否、字段顺序）
      ↓
/search_methods  或 /dump 的 methods 拿方法名
      ↓
/disassemble     拿 method_addr + hex
      ↓
/read_mem        拿实例地址的真实字节，验证解码
```

**不要跳过第 2 步。** 字段偏移决定了你后面怎么解字节；跳过就会把 master 行类
（Obscured，20 字节/字段）当成运行时类（裸 int32）来读——**这个错犯过**。

---

## 3. 反汇编：工具只给 hex，助记符要自己解

`/il2cpp/disassemble` 返回：

```json
{
  "class": "...", "method": "...",
  "method_addr": "0x7547a565e0",
  "bytes_read": 2048,
  "code_section": "0x6d824b4000-0x778d21c000",
  "hex_dump": "0000: fe 0f 1d f8 ...",
  "found_constants": []
}
```

**没有助记符。** 所以：

### 3.1 小函数：直接手解

短方法（<64 字节）手解可行。常见模式：

| hex | 含义 |
|:--|:--|
| `00 0c 40 f9` | `ldr x0, [x0, #0x18]` |
| `c0 03 5f d6` | `ret` |
| `00 80 40 39` | `ldrb w0, [x0, #0x20]` |
| `28 00 80 52` | `movz w8, #1` |
| `08 01 40 b9` | `ldr w8, [x8]` |
| `1f 01 09 6b` | `cmp w8, w9` |
| `e0 17 9f 1a` | `cset w0, ne` |

小端存储，读 hex 时按 4 字节反转。

### 3.2 大函数（数百字节以上）：**不要硬解**

会解错，而且解一个要半小时。改走**常量扫描**：

**目标**：找某个枚举值 / 常量 N 是否出现在方法体里。

**方法**：算 `movz w?, #N` 的机器码，然后 byte-search：

```
MOVZ Wd, #imm16  →  0x5280_0000 | (imm16 << 5) | d
```

| 常量 | `movz w8, #N` 的 4 字节 |
|--:|:--|
| 202 (0xCA) | `48 19 80 52` |
| 203 (0xCB) | `68 19 80 52` |
| 203 (w0) | `60 19 80 52` |

扫不到 ⇒ **该方法不含这个常量**，可以排除。

> 实例：`TrainingCommandEntity.GetGainActGaugeAmount` 全 2048 字节里
> 没有 202/203 ⇒ 进度增益不在那里按 `effect_type` 分支。**[码]**

### 3.3 已知局限（必须承认）

| 局限 | 影响 |
|:--|:--|
| 无 mnemonic | 大函数语义无法可靠还原 |
| `found_constants` 常为空 | 无法依赖工具帮找常量 |
| 每次 2048 字节 | 大函数要多次调用拼接，且没有"下一段"参数 |
| 内联优化 | 没有独立方法名，只能靠调用图反推 |

**遇到这些情况：宁可写「未解出」，也不要编语义。**

---

## 4. 三个省命技巧

### 4.1 `read_mem` 带 `size`

默认 4096 字节，一次读回来约 9 KB 文本。**只用 64 字节就够了的时候，务必写 `&size=64`。**

实例：读完 `CommandGainActGaugeArray` 的 4 个元素，用默认长度要 4 次 × 9 KB；
用 `size=128` 一次能读两个（同批对象在内存里是**连续排列**的）。

### 4.2 同批对象连续排列

同类对象由 GC 批量分配，往往地址相邻且步长固定。

实例：元素 0x76aad1ce40 / ce00 / cdc0 / cd80，**步长 0x40**。
读 `cd80` 起始 128 字节，一次拿到 cd80 + cdc0 两个。

### 4.3 数组对象布局

`T[]` 的固定头：

| 偏移 | 内容 |
|--:|:--|
| +0x00 | klass |
| +0x08 | monitor |
| +0x10 | bounds |
| **+0x18** | **length（int）** |
| +0x20 | 第 0 个元素指针 |

`List<T>` 另有 `+0x10 items` / `+0x18 size`，**别和数组混用**。

---

## 5. Obscured 加密：识别与解码

### 5.1 怎么认出来

`/il2cpp/dump` 一个类，如果字段偏移**步长是 20 字节**（16, 36, 56, 76 …），
且类型名是 `Obscured*` / `CodeStage.AntiCheat.ObscuredTypes.*` ⇒ 该字段加密。

对比：运行时实体类字段步长 4/8，类型是 `System.Int32` ⇒ 明文。

### 5.2 解码

```
20 字节 = [0] cryptoKey  (int32)
          [4] hiddenValue(int32)
          [8] 常量
          [12] 0

value = hiddenValue ^ cryptoKey
```

**验证样本（剧本15，全中）**：

| hidden | ^ 0x6C81C | value |
|:--|:-:|:-:|
| 0x6C81F | | 3 |
| 0x6C818 | | 4 |
| 0x6C81B | | 7 |
| 0x6C814 | | 8 |
| 0x6C81E | | 2 |
| 0x6C81D | | 1 |
| 0x6C81C | | 0 |

### 5.3 两条边界

- **key 是全局的**：同一进程内不同对象、不同字段的 key 相同。**[测]**
- **跨进程是否变**：未验证 **[无证]**。
- 第 3 个 int 恒为 1 且与 value 无关，**其语义未知**，不要叫它 `fakeValue`。**[测]+[无证]**

---

## 6. 失败模式清单（都是真踩过的）

| 现象 | 原因 | 对策 |
|:--|:--|:--|
| `read_failed`, `bytes_read: 0` | 地址过期（对象被回收 / 换过界面） | 现取现用，重取链 |
| `singleton_null` | `/il2cpp/call` 只支持 singleton | 改用 read_mem 找实例 |
| 数组读到一堆陌生 klass | 读超了对象边界，读进了邻接对象 | 先看 +0x18 的 length |
| 字段值对不上 | 混用 master 行类与运行时类的偏移 | 先 dump 类，看步长 |
| `movz` 扫不到常量 | 常量在别的层（表驱动）或在寄存器里拼 | 去查 MDB，不要硬找 |

---

## 7. 开新剧本的准备清单

1. `/scenario` 确认 `scenario_id`，记下 `dataset_obj`
2. `/il2cpp/search_classes?keyword=SingleModeScenario<名字>` 拿逻辑层类清单
3. 读 `dataset` 前 0x60 字节，**逐字段 dump 类**确认每个 `+0xNN` 是哪个数组
   （不要凭顺序假定，DataSet 字段顺序每个剧本都不同）
4. 先做**字段表**，再做**字典/数组内容**，最后才反汇编
5. MDB 先查表结构（`SELECT * ... LIMIT 1`），再按条件查

> 顺序错了会浪费几十分钟。字段表没做对，后面所有字节都是错的。
