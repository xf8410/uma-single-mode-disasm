# Coneshell 结构 + 协议实测观测（2026-11-06）

本轮只**采集与落盘**，不做本地计算。所有待验算式一律进第 7 节交给 CI。

> 证据标记：**[测]** 本轮工具实测 / **[码]** 读源码 / **[文]** 读文档 / **[无证]** 未验证

---

## 1. 取证环境 [测]

| 项 | 值 |
|:--|:--|
| 设备端 SO 版本 | `3.27.9`（`/health`，见 `sniff-session-storage` 交叉验证） |
| sniff 状态 | 启用，`count=35`，`last_id=35` |
| 抓到的载荷性质 | **Coneshell 解密后的明文 msgpack**，非密文 |
| lib 目录（arm64） | 24 个 .so，含 `libil2cpp.so` 230,085,832 B / `libmain.so` 25,428,480 B / `libnative.so` 2,627,800 B |

---

## 2. 协议头实测（两条独立请求，值一致）[测]

`/umamusume/payment/item_list`（id=1）与 `/umamusume/mission/index`（id=3）的请求头：

| Header | 值 |
|:--|:--|
| `APP-VER` | `2.32.5` |
| `RES-VER` | `10021210:Tcxkvfn+yCx3` |
| `Content-Type` | `application/x-msgpack` |
| `ViewerID` | `541816716` |
| `Device` | `2` |
| `Device-SubType` | `1` |
| `SID` | 见第 3 节（每次不同） |

请求体（`body_hex` 前段，msgpack map(15)）解出的公共字段：

| 字段 | 值 |
|:--|:--|
| `viewer_id` | `541816716` |
| `device` | `2` |
| `device_id` | `b40407f6ec599f0c3e108c77a7a74906` |
| `device_name` | `OPPO PKZ110` |
| `graphics_device_name` | `Mali-G720 MC7` |
| `ip_address` | `192.168.5.13` |
| `platform_os_version` | `Android OS 16 / API-36 (BP2A.250605.015/V.1132cc4_14b0ec6_149878d)` |
| `carrier` | `OPPO` |
| `keychain` | `00` |
| `locale` | `JPN` |
| `button_info` | `""` (empty str) |
| `dmm_viewer_id` / `dmm_onetime_token` / `steam_id` / `steam_session_auth_ticket` | 全部 nil |

---

## 3. SID 链原始观测（**未计算**）[测]

时间序：id=1 → id=2 → id=3 → id=4

| 位置 | 方向 | SID / sid 原值 | 长度 |
|:--|:--|:--|--:|
| id=1 请求头 | request | `1557252889976a8ad7daf873a1a41d73` | 32 |
| id=2 响应 `data_headers.sid` | response | `2a9628aa190e2df430505bcfdcdcb6aba4ffbf0ac1` | 42 |
| id=3 请求头 | request | `8c16d8f5792c55d3a72f5647f921546e` | 32 |
| id=4 响应 `data_headers.sid` | response | `2a9628aa190e2df430505bcfdcdcb6aba4ffbf0ac1` | 42 |

**待 CI 验证（不在此本地算）**：
- `md5(utf8("2a9628aa190e2df430505bcfdcdcb6aba4ffbf0ac1"))` 是否 == `8c16d8f5792c55d3a72f5647f921546e`
- `md5(utf8("2a9628aa190e2df430505bcfdcdcb6aba4ffbf0ac1"))` 是否 == `1557252889976a8ad7daf873a1a41d73`
- 若均不等 → 续链规则**不是**对 42 字符 sid 字符串直接 MD5，需重新建模（注意响应 sid 长度 42 ≠ 32，与文档 `SID = MD5(上一响应sid)` 的描述存在长度矛盾，必须复核）

> 备注：id=2 与 id=4 的响应 sid 完全相同，两条请求间隔 424 s。**同一 sid 复用**，说明 sid 不是一次性消耗，或该字段在这两条里未推进。

---

## 4. 响应结构实测 [测]

统一外壳：

```
{ "response_code": 1,
  "data_headers": { "viewer_id": 541816716,
                    "sid": "<42 chars>",
                    "server_time": <int>,
                    "result_code": 1 },
  "data": { ... } }
```

`/umamusume/payment/item_list`（id=2，32,988 B）`data` 内含：
`payment_item_list`（约 330 条，字段 `store_product_id` / `disp_order` / `price` / `formatted_price` / `charge_num` / `free_num` / `limit_num` / `limit_type` / `item_pack_id` / `recommended_flag` / `item_group` / `start_time` / `end_time` / `number_of_product_purchased`）、
`season_pack_info`、`factor_premium_pass_info`、`factor_order_pass_info`、
`factor_premium_pass_purchase_info_array`（空）、`factor_order_pass_purchase_info_array`（空）、
`last_checked_time`、`start_dash_exchange_array`(2)。

`/umamusume/mission/index`（id=4，响应被工具截断在 65,536 B）`data` 内含：
`room_match_race_result_num`、`training_report_receivable_reward_flag`,
`data.mission_list` 大量条目（`mission_id` / `exec_count` / `mission_status` / `mission_type` / `event_id`）。

> 工具限制：[测] `uma_protocol_metadata` 无参数、响应尾部静默截断（本轮 65,536 B 处截断且不报错）。要完整响应必须靠 SO 落盘。

`notifications` 字段（两条响应都有）：

```
{ "unread_information_exists": 1,
  "trophy_badge_flag": 1,
  "new_honor_data_array": [ 24 条 { honer_id, create_time } ],
  "training_report_receivable_reward_flag": 1 }
```

---

## 5. IL2CPP 类结构（本轮实测，现查现记）[测]

### `Gallop.HttpHelper`（字段仅 1 个）

字段：`_isInitializedCompress` (bool) @0 —— 运行时值 `true`

方法（52 个，摘与认证/加密相关）：

```
Login / _Login / onLoginSuccess
Signup / PreSignup / SignupSuccess / _onSignUpSuccess
Send / SendAfterLockUI / _Send / Retry / ActivateSendOption / DeactivateSendOption
UpdateSessionID / CommonProcessOnResponded / CommonSuccess / CommonError
SetupHeader / UpdateHeader / SetupRequestCommon / PreProcessForSendTask
Initialize / InitializeConeshell / ReleaseConeshell
CompressRequest / DecompressResponse
SetHeader / ClearHeader
AddHeaderSessionId / AddHeaderAppVersion / AddHeaderResVersion
AddHeaderContentType / AddHeaderViewerId / AddDevice / AddDeviceSubType
GetRequestCommonButtonInfo
```

### `Gallop.Cryptographer`（7 字段 / 21 方法）

字段：`FBENCRYPT_BLOCK_SIZE`、`ENCRYPT_RANDOM_MAX`、`CRYPT_LENGTH`、`RANDOM_MIN`、`RANDOM_MAX`（均 Int32，offset 0）、`_encodeBuf` (String)、`cRandom` (System.Random) @+8

方法：`Random` / `GenerateIvString` / `GenerateKeyString` / `Encode` / `Decode` / `ComputeHash` / `MakeMd5` / `.ctor` / `.cctor`

### `Gallop.Certification`（MonoSingleton，18 字段）

| 字段 | offset |
|:--|--:|
| `_udid` (String) | +32 |
| `_viewerId` (Int64) | +40 |
| `_sessionId` (String) | +48 |
| `dmmApiToken` (String) | 0 |
| `<DmmApiToken>k__BackingField` | +40 |
| `<dmmViewerId>` / `<dmmOnetimeToken>` / `<dmmOpenId>` / `<dmmAccessToken>` | +8 / +16 / +24 / +32 |

方法：`OnInitialize` / `OnFinalize` / `get_Udid` / `set_Udid` / `get_ViewerId` / `set_ViewerId` /
`get_SessionId` / `set_SessionId` / `GenerateUdid` / `GetKeyChainViewerId` / `SetKeyChainViewerId` /
`DeleteKeyChainViewerId` / DMM 系列 getter-setter / `initDmmPlatformData`

> 会话注入目标候选：`Certification._viewerId` (+40) / `_sessionId` (+48) / `_udid` (+32)

### `Gallop.GameDefine`（298 字段，258 个 const + 静态量）

服务器相关字段（本轮只取字段名，值需运行期读静态区）：

| 字段 | 类型 | offset |
|:--|:--|--:|
| `API_PROTOCOL` | String | 0 |
| `APPLICATION_SERVER_URL` | String | 0 |
| `applicationServerUrl` | String | +224 |
| `RESOURCE_PROTOCOL` | String | 0 |
| `RESOURCE_SERVER_URL` | String | 0 |
| `_receivedResourceServerForInTitle` | ObscuredString | +232 |
| `_receivedResourceServerForInGame` | ObscuredString | +240 |
| `_receivedResourceServerForManifest` | ObscuredString | +248 |
| `MasterDbName` | String | +208 |
| `MasterDBPath` | String | +216 |
| `PLATFORM` | String | 0 |

> `RESOURCE_SERVER_URL` / `_receivedResourceServer*` 是**真正的资源域名**候选，不是 `prd-info-*`。取值待办（第 7 节）。

### `Gallop.ServerDefine`（214 字段）

全是游戏数值配置（体力上限、回复时间、房间赛参数、开放日期等），**不含任何密钥**。已排除。

### 其他已排除的搜索 [测]

| 搜索词 | 命中 |
|:--|--:|
| `Coneshell` / `ConeShell` / `serverPublicKey` / `VersionKey` / `Vfs` / `Cipher` / `PublicKey` / `X25519` / `KeyExchange` / `FBEncrypt` / `Tempest` / `ServerConfig` | 0 |
| `Crypto` | 1（`Gallop.Cryptographer`） |
| `Cert` | 2（`Gallop.Certification`、`SetSourceRTPass`） |
| `HttpHelper` | 1 |
| `Session` | 6（含 `<StartSession>d__21`） |
| `Signup` | 2（`<PreSignup>d__23`、`<StartSignupSequence>d__36`） |

内存字符串扫描 `coneshell` / `ConeShell` / `Coneshell` / `Initializ eConeshell`：**0 命中**（183~198 个 map、268 MB 扫描）。→ 密钥不是以可读字符串存在。

### 已取到的函数地址（供 CI 反汇编）[测]

| 符号 | 地址 | 代码段 |
|:--|:--|:--|
| `HttpHelper.InitializeConeshell` | `0x7067838608` | `0x68800000-0x72c92bf000` |
| `HttpHelper.Initialize` | `0x7067848c08` | 同上 |
| `HttpHelper.SetupHeader` | `0x70678488dc` | 同上 |
| `HttpHelper.SetupRequestCommon` | `0x7062c86de8` | 同上 |
| `HttpHelper.CompressRequest` | `0x7067848dc8` | 同上 |
| `Cryptographer.Encode` | `0x70677f1338` | 同上 |

> `InitializeConeshell` / `SetupHeader` / `SetupRequestCommon` / `CompressRequest` / `Initialize` 的 2 KB hex dump 本轮已取，未落盘 → 见第 7 节待办。

---

## 6. Coneshell 源码事实（读镜像仓库 `xf8410/cygames-coneshell-kt`）[码]

### 6.1 `fromCommonHeader` —— 密钥打包格式

`ConeshellV4.kt`：

```kotlin
fun fromCommonHeader(commonHeader: ByteArray, deviceUuid: ByteArray,
                     sessionId: ByteArray, authInfo: ByteArray? = null): ConeshellV4 {
    require(commonHeader.size >= 52)
    val publicKey = commonHeader.copyOfRange(0, 32).reversedArray()   // 32B，倒序
    val salt      = commonHeader.copyOfRange(32, 52)                  // 20B = versionKey
    return ConeshellV4(X25519PublicKeyParameters(publicKey, 0), salt, deviceUuid, sessionId, authInfo)
}
```

**结论 [码]**：`serverPublicKey`(32B, 内存中以**倒序**存放) + `versionKey`(20B) 拼成一个 52 字节块。

### 6.2 构造约束 [码]

```kotlin
require(versionKey.size == 20)
require(deviceUuid.size == 16)
require(sessionId.size == 16)        // ← 注意：V4 要求 sessionId 为 16B 二进制
require(authInfo == null || authInfo.size == 50)
```

### 6.3 V4 请求布局 [码]

```kotlin
Buffer()
  .writeIntLe(REQUEST_HEADER_SIZE + data.size - 4)   // REQUEST_HEADER_SIZE = 0x58
  .write(clientPublicKey)                            // 32B → 偏移 4..35
  .write(encryptedAuthInfo)                          // 36B → 偏移 36..71
  .write(encryptedPayload.tag)                       // 16B GCM tag
  .write(encryptedPayload.data)
```

- `authInfo != null`（已登录）分支：`authenticationData[0]=1`，`authInfo[0..0x22)` → `[2..0x24)`，`authInfo[0x22..0x32)` → nonce
- `authInfo == null` 分支：`authenticationData[0]=0`，`deviceUuid` 填 nonce/scramble，`[0x12..0x24)` 随机
- `gcmKey  = md5(scramble(sharedSecret[0..16], scrambleKey, sharedSecret), sharedSecret, scrambleKey, versionKey)`
- `gcmNonce = md5(clientPublicKey, sessionId, deviceUuid)`
- `associatedData = versionKey(0x14) + sessionId(0x10) + deviceUuid(0x10)` = 0x34 B
- `encryptedAuthInfo = aesCtrCrypt(authenticationData, sharedSecret, clientPublicKey[0..16])`

### 6.4 V4 响应布局 [码]

```kotlin
writeIntLe(decompressedSize)   // 4B，0 表示未压缩
write(nonce)                   // 16B
write(encrypted.tag)           // 16B
write(encrypted.data)
```

- `gcmKey = md5(requestData.sharedSecret, sessionId, requestData.nonce)`
- `associatedData = sessionId(0x10) + requestData.nonce(0x10)` = 0x20 B

### 6.5 其他版本差异 [码]

| 版本 | 算法 |
|:--|:--|
| V2 | AES-256-CTR，key=`deriveDeviceSecret(sharedSecret)`，iv=`md5(clientPub, deviceUdid)`，checksum=md5 双层 |
| V3 | V2 + `versionKey` 混入 key 派生 |
| V4 | AES-GCM + scramble + versionKey + authInfo（当前客户端） |

### 6.6 C# 解包器镜像 `xf8410/cygames-coneshell-unpacker` 的关键点 [码]

- 走 P/Invoke 调原生 `coneshell.dll`：`NLAMANJEALE.InitializeContext(byte[32], deviceUdid)`
- 示例 `Data/2260_Request.txt` 是**公主连结**（`api-priconne-redive.cygames.jp`），非赛马娘 → **不能直接套用其密钥**
- `PlayerData.UpdateHead` 里 `sessionId = NAPGOPBJNMP.MakeMd5(sessionId)` —— 与路线图 `SID = MD5(上一响应 sid)` 同源
- `PARAM` 头算法：`SHA1(udid + uri.AbsolutePath + json(viewer_id, dmm_viewer_id, dmm_onetime_token) [+ viewer_id])` —— **待确认赛马娘是否同样需要 PARAM 头**（本轮实测请求头里**没有** `PARAM`、`SHORT-UDID`、`DEVICE-ID` 这些 pcr 特有头）

---

## 7. 撤回与更正

### 7.1 撤回：`resource_file_dl` 不是从 CDN 下载 [码]

`hachimi_ura_plugin/src/lib.rs`：

```rust
} else if path == "/debug/resource_file_dl" {
    ...
    match find_resource_storage() {
        Ok((_, dat)) => {
            let target = Path::new(&dat).join(&hash[..2]).join(&hash);
            if !target.is_file() { ... "resource_not_found" }
            else { stream_private_file(&mut stream, &target.to_string_lossy(), &hash); }
```

`stream_private_file` → `std::fs::File::open(path)`，**纯本地读**。
全仓 `ureq::get|ureq::post` 仅 2 处（L23046 / L23083），都在 `update_so()`，与资源无关。

⇒ 旧结论「`resource_file_dl` 从 CDN 拉资源」**撤回**。

### 7.2 更正：`prd-info-umamusume.akamaized.net` 性质 [用户口述]

是**官网公告/新闻图片 CDN**（路径形如 `/announce/{id}/Header/{file}.png?c={ts}`），
不是游戏资源 CDN。它出现在内存里是因为游戏内公告模块加载公告图。**不是**资源下载域名。

### 7.3 更正：本会话中一处表述不精确 [码]

先前口头描述「Coneshell 请求包头前 32 字节是 client 公钥」不准确。
按 `ConeshellV4.encryptRequest`：**偏移 0..3 是 `writeIntLe` 长度**，`clientPublicKey` 位于**偏移 4..35**。
以源码为准。

---

## 8. 交给 CI 的待办（**本轮不做本地计算**）

| # | 任务 | 输入 |
|:-:|:--|:--|
| 1 | 验证 SID 续链：`md5("2a9628aa…bf0ac1")` vs `1557252889976a8ad7daf873a1a41d73` / `8c16d8f5792c55d3a72f5647f921546e` | 第 3 节 4 个原值 |
| 2 | 解释响应 sid 长 42 而请求 SID 长 32 的长度差（是否取子串/取 hex-of-bytes） | 同上 |
| 3 | 落盘并 capstone 反汇编 6 个函数（地址见第 5 节），扫立即数与 `adrp/add` 目标 | 本轮 2 KB hex dump 需重新抓取并写 `raw/` |
| 4 | 从 `InitializeConeshell` 的 `adrp+ldr` 链解析 `.rodata` 常量，找 52 B 块（32B 公钥倒序 + 20B versionKey） | 任务 3 输出 |
| 5 | 运行期读 `GameDefine.RESOURCE_SERVER_URL` / `RESOURCE_PROTOCOL` / `_receivedResourceServer*` 的实际字符串 | `/il2cpp/static`（注：`GameDefine` 静态区响应曾超 4 KiB 上限，需分字段读） |
| 6 | 核对 `Certification` 运行期值（`_udid` / `_viewerId` / `_sessionId`）与 sniff 头是否一致 | `/il2cpp/static?name=Certification` |
| 7 | 判定赛马娘是否使用 V2/V3 还是 V4（取决于是否观察到 4+32+36+16 布局的密文包） | 需冷启动抓 `UnityWebRequest` 层密文 |

---

## 9. 仍缺（明确未知，不猜测）

| 项 | 状态 |
|:--|:--|
| `serverPublicKey`(32B) 的实际值 | [无证] 未提取 |
| `versionKey`(20B) 的实际值 | [无证] 未提取 |
| `vfsCert`(472B) 的实际值 | [无证] 未提取 |
| 认证链路 4 端点的真实请求/响应包 | [无证] 本轮 sniff 里**没有** `get_verify_token` / `pre_signup` / `signup` / `start_session`（只抓到业务接口），说明认证走 `UnityWebRequest` 层、未被现有 hook 覆盖 |
| 真正的资源 CDN 域名 | [无证] 待第 8 节任务 5 |
| `Cryptographer.MakeMd5` 的真实变换 | [无证] 已知**不是**裸 MD5（路线图文档记录 5/5 不符） |
