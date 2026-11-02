# 训练结果的观测点清单（不要只盯一个地方）

> 教训来源：用户指出「训练又不是一个地方能看，好几个地方都能看」。
> 下面把**所有试过的观测点**列出来，成功失败都记，避免以后重复踩。

---

## 1. 观测点全表（2026-11-02 11:15 实测）

| 端点 | 返回 | 可用性 | 能拿到什么 |
|:--|:--|:-:|:--|
| `/training/result` | `{result_type:2, sub_id:1, hooked:true, result_name:"Failure"}` | **✅** | 最近一次训练的结果等级 |
| `/debug/laststep` | `{step:452, last_step:"S:after_read_speed"}` | **✅** | 最后一步的 hook 标签（能看出训练种类） |
| `/debug/cmdinfo` | 12 条命令 + 字段表 + elem0 hex | **✅** | 命令的 type/id/可用性 |
| `/debug/training_seed` | `fixed_turn_chara_seed:541818554`，`rng_observation_valid:false` | **⚠️ 部分** | 种子；RNG 状态不可读，原因见下 |
| `/debug/training_log` | **返回的其实是 seed 字段，不是日志** | **⚠️ 名不副实** | 无训练历史 |
| `/debug/paramsincdec` | `{error:"not_ramen", sid:15}` | **❌** | 只支持拉面剧本 |
| `/log/turn` | 响应 > 32 KiB | **❌ 超限** | 需分页/范围端点 |
| 内存 `ActInfoArray` | 元素 klass 归零 | **❌ 悬空** | 训练后对象被回收 |

### `rng_observation_valid` 为什么是 false

```
"rng_invalid_reason": "offset_0x198_is_ObscuredInt_not_u32x4"
```

即：该工具预期 `+0x198` 是 4×u32 的 PRNG 状态，实际是 **ObscuredInt**。
⇒ **不能把 `+0x198` 当明文 PRNG 状态读。** **[测]**

---

## 2. `SingleModeCommandInfoData` 字段表 **[码]**

`/debug/cmdinfo` 现查，不走记忆：

| 偏移 | 字段 | 实际类型 |
|--:|:--|:--|
| +16 | CommandType | `ObscuredInt` |
| +36 | CommandId | `ObscuredInt` |
| +56 | IsEnable | `ObscuredInt` |
| +80 | TrainingPartnerArray | `ObscuredInt[]` |
| +88 | TipsEventPartnerArray | `ObscuredInt[]` |
| +96 | ParamsIncDecInfoArray | `SingleModeParamsIncDecInfoData[]` |
| +104 | FailureRate | `ObscuredInt` |

**注意**：`ParamsIncDecInfoArray` 的类型是**运行时类**，不是 ObscuredInt[]。

---

## 3. 元素 0 解码（`/debug/cmdinfo` 的 hex）

key = `444444`（= `0x6C81C`），解码式 `value = [4] ^ [0]`：

| 偏移 | 两值 | 结果 | 字段 |
|--:|:--|:-:|:--|
| +0x10 / +0x14 | 444444 / 444445 | **1** | CommandType |
| +0x24 / +0x28 | 444444 / 444537 | **101** | CommandId |
| +0x38 / +0x3C | 444444 / 444445 | **1** | IsEnable |
| +0x68 / +0x6C | 444444 / 444444 | **0** | FailureRate |

⇒ 元素 0 = **type 1 / id 101 / 可用 / 失败率 0**，与协议 msgpack 解出的 101 一致。**[测]**

---

## 4. 三处计数不一致（未解释）

| 来源 | 命令条数 |
|:--|:-:|
| `/debug/cmdinfo` `cmd_len` | **12** |
| 协议 `command_info_array` | **10** |
| `/scenario` `CommandInfoArray` len | **7** |

三个数字互不相同，**原因未查明 [无证]**。

可能方向（均未验证）：
- 三者是不同阶段/不同过滤口径的列表
- 内存数组 len 与协议数组 len 本就不同

**在查清前，任何「训练有 N 条命令」的说法都不能用。**

---

## 5. 待反汇编清单（capstone 流水线可跑）

| # | 目标 | 目的 |
|:-:|:--|:--|
| 1 | `TrainingCommandRepository.CreateCommandEntity` `0x7547a62284` | 建命令实体时是否填充演目增量 |
| 2 | `GetGainActGaugeAmount` | 已扫过无 202/203，需看调用方 |
| 3 | `SingleModeParamsIncDecInfoData` 相关 | 确认 `target_type` 语义 |
| 4 | 训练结果结算方法 | 演目进度真实来源 |

**还没做**：以上 4 项都只是列出来，**尚未反汇编**。

---

## 6. 本轮的硬结论

| 结论 | 证据 |
|:--|:--|
| 最近一次训练结果是 **Failure**（`result_type 2 / sub_id 1`） | **[测]** `/training/result` |
| 最后一步是 `after_read_speed` | **[测]** `/debug/laststep` |
| `+0x198` 是 ObscuredInt，不是 PRNG u32×4 | **[测]** 工具自报原因 |
| 元素 0 = type1/id101 | **[测]** 双源一致 |
| 三处命令计数 12 / 10 / 7 | **[测]** 数字，原因 [无证] |
