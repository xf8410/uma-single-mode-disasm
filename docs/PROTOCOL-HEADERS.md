# 协议实测：请求头 + 载荷是否加密（2026-11-02 15:17）

来源：`uma_protocol_metadata` 实抓，id 1–4，两次请求 `payment/item_list` 与 `single_mode_festa/load`。

---

## 1. 请求头（逐字） **[测]**

| 头 | 值 |
|:--|:--|
| `SID` | 每次请求不同（`b573ed10…` / `6133e9df…`）→ **会话令牌** |
| `APP-VER` | `2.32.0` |
| `RES-VER` | `10021210:Tcxkvfn+yCx3` |
| `Content-Type` | `application/x-msgpack` |
| `ViewerID` | `541816716` |
| `Device` | `2` |
| `Device-SubType` | `1` |

**没有** `Authorization`、没有 `Sign`、没有自定义加密头。

---

## 2. 载荷**不加密** **[测]**

`Content-Type: application/x-msgpack`，body 是**明文 msgpack**，直接可解。

请求体字段（`single_mode_festa/load`，357 B）：

```
viewer_id / device=2 / device_id / device_name(OPPO PKZ110) /
graphics_device_name(Mali-G720 MC7) / ip_address / platform_os_version(Android 16) /
carrier / keychain=00 / locale=JPN / button_info /
dmm_viewer_id=null / dmm_onetime_token=null / steam_id=null / steam_session_auth_ticket=null
```

响应结构：
```
response_code / data_header(viewer_id, sid, server_time, result_code) / notifications /
data.single_mode_load_common
    ├─ chara_info
    ├─ support_card_array (6 张)
    ├─ evaluation_info_array (25)
    ├─ training_level_info_array
    └─ home_info.command_info_array (12)
```

---

## 3. ⚠️ 抓到的 `command_info` 里**没有演目字段**

单条字段只有 9 个：
`command_type / command_id / is_enable / training_partner_array / tips_event_partner_array /
params_inc_dec_info_array / failure_rate / level / sub_command_partner_array`

**没有 `predict_gain_act_gauge_array`。**

⇒ 我 15:07 那条说「服务器随 command_info 下发 predict 数组」，
在 **load 响应**里**不成立**。该字段确实存在于 `ObscuredSingleModeFestaCommandInfo` 类型上，
但**不在这个接口的报文里**。**撤回「随 command_info 下发」的表述**，改为：字段存在，出处未定位。

（注意：本次 body_hex 尾部被截断，28340 B 未完整落盘，不能断言全文都没有。）

---

## 4. 交叉验证成功的一条 **[测]**

| 训练 | command_id | 协议 training_partner_array | 内存实读 |
|:--|--:|:--|:-:|
| 智力 | 106 | `[2,4,1096,1128]`（4 人） | 4 ✓ |
| 力量 | 5103 | `[1,6,1024]`（3 人）+ tips`[1]` | 3 ✓ |

⇒ **协议与内存读数一致**，两条通路都可当证据。

---

## 5. 内存里的"加密" **[测]**

`CodeStage.AntiCheat.ObscuredTypes`：

| 类型 | 布局 | 解码 |
|:--|:--|:--|
| `ObscuredInt` | 20 B：`[0] key` `[4] hidden` `[8] 常量1` `[12] 0` | `value = [4] ^ [0]` |
| `ObscuredBool` | value@+0x48 key@+0x50 | 真值 = XOR 结果非 0 |

本局同一批对象 key 恒为 `0x6C81C`（全局，非 per-instance）。

⇒ **这是唯一需要"解"的加密，且已经解开**。协议层没有额外一层。

---

## 6. 下一步（明确）

演目增量不在 `single_mode_festa/load`，只剩两个候选：

1. **训练执行接口的响应**（点训练后返回的那条）——最可能带 `predict_gain_act_gauge_array`
2. load 响应被截断的部分

**做法**：开 sniff → 点一次训练 → 抓执行那条的响应 → 在 body 里搜 `predict`。
