# 剧本15 MDB 表清单（逆向边界）

> 用途：**先知道有哪些表，再决定要不要去反汇编。**
> 这一节的价值是"排除"——不在表里的东西，只能从代码或内存拿。

---

## 1. 全部表（`sqlite_master` 实测）**[表]**

`SELECT name FROM sqlite_master WHERE name LIKE 'single_mode_15%'` → **17 行 = 12 张数据表 + 5 张索引**

### 1.1 数据表（12）

| 表名 | 行数（已知） | 内容 |
|:--|:-:|:--|
| `single_mode_15_act_info` | 5 | act_type ↔ command_id |
| `single_mode_15_act_effect` | — | 演目等级效果 |
| `single_mode_15_act_member` | — | 演目成员 |
| `single_mode_15_advice` | 10 | 教誨 id / fusion_type / add_schedule_type |
| `single_mode_15_advice_effect` | — | 教誨等级效果 |
| `single_mode_15_advice_recommend` | — | 教誨推荐 |
| `single_mode_15_schedule` | — | 日程 |
| `single_mode_15_fusion_effect` | — | 融合效果 |
| `single_mode_15_check_point_effect` | — | 检查点效果 |
| `single_mode_15_finals_act_effect` | — | 决赛演目效果 |
| `single_mode_15_outing_effect` | — | 友人外出效果 |
| `single_mode_15_act_effect_0_level` | — | 索引 |

### 1.2 索引（5）

`act_effect_0_level`、`act_member_0_act_type`、`advice_effect_0_advice_id_1_level`、
`fusion_effect_0_advice_id`、`check_point_effect_0_schedule_id_1_result_state`、`outing_effect_0_support_card_id`

---

## 2. 关键否定结论

**剧本15 没有任何 "gain" 相关的 gauge 表。**

`SELECT name FROM sqlite_master WHERE name LIKE '%gain%'` 命中 5 张，全部属于其他剧本：

| 表 | 归属 |
|:--|:--|
| `single_mode_hint_gain` | 通用 |
| `single_mode_hint_gain_0_hint_id` | 通用索引 |
| `single_mode_11_gain_training_pt` | 剧本11 |
| `single_mode_14_special_gain_turn` | 剧本14 |
| `single_mode_14_finals_gain_skill` | 剧本14 |

⇒ **`CommandGainActGaugeArray` 不是表驱动的**（该表名的查询直接 `query_failed`）。**[表]**

它的数据来源只剩两种可能：代码内常量 / 运行时由其他字段算出。
**具体是哪种，未验证 [无证]。**

---

## 3. `single_mode_15_act_info` 全表 **[表]**

| act_type | command_id |
|:-:|:-:|
| 1 | 5101 |
| 2 | 5102 |
| 3 | 5103 |
| 4 | 5104 |
| 5 | 5105 |

5 个演目 ↔ 5 个 command。**`CommandType`（3/4/7/8）与 act_type 不是同一套编号**，对应关系未查 **[无证]**。

---

## 4. `CreateCommandEntity` 反汇编状态

| 项 | 值 |
|:--|:--|
| 地址 | `0x7547a62284` |
| 长度 | 2048 字节 |
| `ret_offsets` | 640 / 892 / 1036 / 1528 / 1672 / 1812 / 1968（7 个出口） |
| `found_constants` | 空 |
| 202 / 203 立即数 | **无**（`0x52801940` / `0x52801960` 均未命中） |

**语义：未解出 [无证]。** 原因：该端点只返回 hex_dump，不给助记符；
函数体 2048 字节、7 个出口、约 20 处 `bl` 调用，手工还原不可靠 —— 不做。

**可确认的形态**：函数开头是典型的静态字段惰性初始化守卫
（`ldrb` 标志 → `cmp` → 分支 → `strb #1`），与其它 IL2CPP 类的静态构造同型。**[码]**

---

## 5. 给后续剧本的复用结论

1. **先列 `sqlite_master`**，拿到 12 张表再动手，能省掉大量反汇编。
2. 表名规律 `single_mode_<剧本号>_<模块>`，索引表带 `_0_` 前缀字段名。
3. **凡是表里没有的机制，只有两条路**：代码常量 / 运行时计算。**先查表，再进内存。**
