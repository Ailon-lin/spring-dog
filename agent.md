# 六六（Spring-Dog）· AI 接入说明（agent.md）

> **读者是 AI Agent。** 用户把本页地址交给你，意思是：「帮我把六六接到你身上」。
> 按下面的顺序执行。每一步都有「验证」，验证不通过就停在这一步，不要往下走。
>
> **用户通常已经做完三件事**（人读版第 2 步）：给六六配好网、复制好设备配置、插好 USB 线。
> 设备配置（`mcpServers` JSON）多半就附在用户发你的第一条消息里。附了就直接用，不要再让用户重复做。
>
> English summary: You are an AI agent. The user wants you to connect their robot dog Liuliu (六六, Spring-Dog)
> to you (two-way). Follow the steps in order. Verify each step. Stop at every **STOP** and ask the user.

- 人读版：https://ailon-lin.github.io/spring-dog/
- 本文件：https://ailon-lin.github.io/spring-dog/agent.md
- 文档版本：2026-11-17

---

## 0. 规则（先读，全程遵守）

1. **不要编造。** 命令输出与本文不一致时，相信输出，并告诉用户哪里不一致。
2. **遇到 STOP 必须停下问用户。** 用户没回答前，不执行后面的步骤。
3. **设备凭据是密钥。** 用户粘给你的 `mcpServers` JSON 里有 `Bearer` token。
   - 只写进本文指定的本地文件（权限 `0600`）。
   - 不要在回复里原样复述 token，显示时只留前 4 位。
   - 不要提交进 git，不要发到任何第三方服务。
4. **烧录默认只出计划。** 不带 `--yes` 的 `flash` / `customize` 只返回计划。把计划给用户看，用户同意后再带 `--yes --plan-id <id>` 执行。
5. **不要擦除 NVS。** 不要运行 `erase_flash`，除非用户明确要恢复出厂。擦除后用户要重新配网。
6. **同一时刻只烧一台。** 烧录前用 `lsof /dev/cu.usb* /dev/ttyACM* /dev/ttyUSB* 2>/dev/null` 确认串口没被占用。

---

## 1. 先弄清三件事

问用户或自己检查：

| 项 | 怎么查 | 要求 |
|---|---|---|
| 操作系统 | `uname -s` | macOS 或 Linux。**Windows 暂不支持**，遇到就告诉用户 |
| 你是哪种 Agent | 你自己知道 | Hermes / Claude Code / Codex / OpenClaw / 其他 MCP 客户端 |
| 这台电脑能否常开 | 问用户 | 六六问问题时要靠这台电脑作答，电脑睡眠时上行不可用 |

**硬前提**：六六与这台电脑必须在**同一个局域网**。六六只支持 **2.4 GHz** Wi-Fi。
路由器开了「AP 隔离 / 访客网络隔离」时，六六连不到电脑。

---

## 2. 一键安装工具

```bash
curl -fsSL https://ailon-lin.github.io/spring-dog/install.sh | bash
```

它装三样东西到 `~/.rig-puppy/`，并在 `~/.rig-puppy/bin/` 放入口：

| 入口 | 作用 |
|---|---|
| `spring-dog` | USB 烧录 CLI（Node ≥ 18） |
| `rig-hub` | 电脑侧常驻中转：接住六六的提问，转给你作答，再把答案推回六六 |
| `rig-dog` | MCP 适配器（stdio）：让你调用六六的动作、说话、表情 |

同时把技能装进 `~/.agents/skills/spring-dog-cli`，并链到 `~/.claude/skills/`。

**验证**：

```bash
~/.rig-puppy/bin/spring-dog doctor
~/.rig-puppy/bin/rig-hub --version
```

`doctor` 报缺 esptool 时运行 `python3 -m pip install --user esptool`，然后重跑 `doctor`。

---

## 3. 烧录固件（六六已烧过最新版时跳过）

1. 用户已插好 USB 线时直接往下做；没插就让用户用**数据线**把六六直插电脑（只供电的线不行，尽量不经 USB Hub）。
   烧录不擦 NVS，用户先前配好的 Wi-Fi 会保留，不用重新配网。
2. 初始化并自检：

   ```bash
   ~/.rig-puppy/bin/spring-dog init \
     --catalog https://github.com/Ailon-lin/spring-dog/releases/latest/download/spring-dog-catalog.json \
     --board puppy --baud 460800
   ~/.rig-puppy/bin/spring-dog doctor
   ~/.rig-puppy/bin/spring-dog list
   ```

3. 出计划（不碰设备）：

   ```bash
   ~/.rig-puppy/bin/spring-dog flash --version latest --mode full
   ```

4. **STOP**：把计划里的版本、模式、`plan_id` 给用户看，问「确认烧录吗？」
5. 用户同意后执行：

   ```bash
   ~/.rig-puppy/bin/spring-dog flash --version latest --mode full --yes --plan-id <plan_id>
   ```

**验证**：stdout 的 JSON 里 `ok=true` 且 `result.flash_verified=true`。

已知现象（不是失败）：
- `boot_verified=false` 或 `app_desc: null` 常见。报告里写「写入已校验，启动未验证」即可。
- 报 `No serial data received`：让用户按住 BOOT 再按 RESET，或拔插 USB，然后重试。
- 读回 flash 报 `Invalid head of packet`：加 `--baud 115200` 重试。

换唤醒词或表情（可选）：

```bash
~/.rig-puppy/bin/spring-dog customize --list
~/.rig-puppy/bin/spring-dog customize --wake-word "你好六六" --wake-pinyin "ni hao liu liu"
# 同样先出计划，用户确认后再 --yes --plan-id <id>
```

---

## 4. 配网与绑定（用户在手机上做）

**先看用户的第一条消息里有没有附 `mcpServers` JSON。** 有：直接跳到下面「拿到后」那一段，不要 STOP。
没有，或者 JSON 不完整（缺 `Authorization` / `X-Device-Id`）：

**STOP**：请用户完成下面两件事，完成后告诉你：

1. 六六连不上 Wi-Fi 时会自动进入配网模式，**可见信号是六六坐下**。用户用厂家小程序给六六配 2.4 GHz Wi-Fi。
2. 在小程序里点右上角齿轮 →「设备设置 → MCP 控制设备」→「复制配置」，把整段 `mcpServers` JSON 发给你。它长这样：

   ```json
   {"mcpServers": {"RIG-Puppy-XX": {"type": "streamableHttp",
     "url": "https://<厂家云桥地址>/mcp",
     "headers": {"Authorization": "Bearer <token>", "X-Device-Id": "<设备 MAC>"}}}}
   ```

拿到后把它存成 `~/.rig-puppy/vendor.json`，权限 `0600`：

```bash
umask 077 && cat > ~/.rig-puppy/vendor.json   # 粘贴后按 Ctrl-D；或由你直接写文件
```

从中取出四个值，后面要用：设备名（`mcpServers` 下的键）、`url`、token、`X-Device-Id`。

---

## 5. 起 rig-hub（电脑侧中转）

```bash
~/.rig-puppy/bin/rig-hub bootstrap --device <设备名>
~/.rig-puppy/bin/rig-hub serve        # 先前台跑，验证通过后再常驻
```

`bootstrap` 会生成 `~/.rig-hub/config.json`（含 rig-hub 自己的 `token`）并打印接入配置。
可选：加 `--vault <笔记目录>`，让 rig-hub 在没有大脑时用这些笔记作答。

**验证**（另开一个终端）：

```bash
curl -s localhost:8765/api/health -H "Authorization: Bearer <rig-hub token>"
```

此时 `brain:false` 是正常的，第 6 步做完会变 `true`。第 6 步做完后 `async` 必须是 `true`。

常驻：
- macOS：写一个 `~/Library/LaunchAgents/com.rig-puppy.hub.plist`，`ProgramArguments` 为 `~/.rig-puppy/bin/rig-hub serve`，`KeepAlive=true`，然后 `launchctl load` 它。
- Linux：写一个 `systemd --user` 服务，`ExecStart=%h/.rig-puppy/bin/rig-hub serve`，`Restart=always`。

---

## 6. 接到你身上（双向）

按你是哪种 Agent 选一条。

### 6A. 你是 Hermes（完整双向，一条命令）

```bash
~/.rig-puppy/bin/rig-hub connect --vendor-config @~/.rig-puppy/vendor.json --dry-run
```

**STOP**：把 dry-run 列出的改动给用户看。它会改 `~/.hermes/.env` 和 `config.yaml`，并**重启 Hermes 网关**（20–90 秒）。用户同意后去掉 `--dry-run` 再跑一次。它是幂等的，可以重跑。

它做四件事：开 Hermes 的 OpenAI 兼容端点、让 rig-hub 指向它、注册 `rig-dog` MCP、重启网关。

### 6B. 你是 Claude Code / Codex / OpenClaw / 其他 MCP 客户端

**下行（你 → 六六）**：

1. 写凭据文件 `~/.rig-puppy/dog.env`（权限 `0600`）：

   ```bash
   RIG_DOG_URL=<vendor.json 里的 url>
   RIG_DOG_TOKEN=<token>
   RIG_DOG_DEVICE=<X-Device-Id>
   ```

2. 注册 MCP server。**不要直接挂厂家的 MCP 地址**，因为厂家云桥的工具目录里没有固件新增的工具（`self.hub.*` 等）。要挂 `rig-dog` 适配器。Claude Code 的写法：

   ```bash
   claude mcp add rig-dog -s user \
     -e RIG_DOG_ENV_FILE=$HOME/.rig-puppy/dog.env \
     -- $HOME/.rig-puppy/bin/rig-dog
   ```

   其他客户端：stdio 类型，命令 `~/.rig-puppy/bin/rig-dog`，环境变量 `RIG_DOG_ENV_FILE=~/.rig-puppy/dog.env`。

3. 重启或重载你的 MCP 连接。**验证**：你能看到 `dog_say`、`dog_call`、`dog_emote` 三个工具。

**上行（六六 → 你）**：

1. 把同样三项凭据写进 `~/.rig-hub/config.json` 的 `bridge_url`、`bridge_token`、`bridge_device`（用它们把答案推回六六）。
2. rig-hub 的大脑需要一个 **OpenAI 兼容端点**（`POST /v1/chat/completions`）。你有这样的端点时，填：

   ```json
   {"brain_enabled": true, "brain_url": "http://127.0.0.1:<端口>/v1",
    "brain_key": "<端点密钥>", "brain_model": "<模型名>", "brain_max_chars": 220}
   ```

3. 你没有这样的端点时，**如实告诉用户**：下行已通，上行只能用 rig-hub 的本地笔记检索作答（第 5 步的 `--vault`），不是你本人在回答。
4. 重启 rig-hub。**验证**：health 里 `async:true`；配了大脑时 `brain:true`。

---

## 7. 让六六找到这台电脑

1. 查本机局域网 IP：macOS 用 `ipconfig getifaddr en0`（不通再试 `en1`），Linux 用 `hostname -I`。**不能用 `127.0.0.1` 或 `localhost`**，因为六六从它自己的网卡来连。
2. 用 `dog_call` 工具调用：

   ```json
   {"tool": "self.hub.set_endpoint",
    "arguments": {"url": "http://<电脑局域网IP>:8765", "token": "<rig-hub token>"}}
   ```

**验证**：返回 `true`。电脑 IP 变了（换网、DHCP 重新分配）时要重跑这一步。

---

## 8. 角色介绍（必做，用户在手机上做）

```bash
~/.rig-puppy/bin/rig-hub role-prompt
```

**STOP**：把输出的整段交给用户，请用户粘进厂家小程序的「角色介绍」。缺了这一步，六六会用厂家 LLM 自己回答，不会来问你。

这段里有两条不能删：
- 「一次提问只调用一次 `self.hub.ask`」：删掉的话，六六会反复追问，把设备压到掉线。
- 「技术错误不要念出来」：删掉的话，六六会把链路报错念给用户听。

---

## 9. 验收（全过才算接好）

| # | 做什么 | 期望 |
|---|---|---|
| 1 | 用户对六六说「你好」 | 六六回话 |
| 2 | 用户问一件只有你知道的事 | 先听到确认语，**几秒后**听到答案 |
| 3 | 用户把同一句再问一遍 | 答案只播一次，不重复念 |
| 4 | 你调用 `dog_call` 让六六挥手 | 六六动起来 |
| 5 | 你调用 `dog_say` 说一句话 | 六六念出来 |
| 6 | 你调用 `dog_emote`，参数「害羞」 | 六六的屏幕换成害羞脸 |
| 7 | 查 health | `async:true`、`push_failures:0`；有大脑时 `brain:true` |

完成后给用户一份简短报告：哪些项通过、哪些没通过、没通过的原因。不要写成「全部完成」，除非 7 项都真的通过了。

---

## 10. 排障

| 症状 | 先查 |
|---|---|
| 六六问问题后没有下文 | rig-hub 在跑吗？`self.hub.set_endpoint` 的 IP 是不是当前 IP？同一局域网吗？有没有 AP 隔离？ |
| health 里 `async:false` | `bridge_token` / `bridge_device` 没填全 |
| `dog_*` 工具报缺少 `RIG_DOG_TOKEN` | MCP 进程没读到 `dog.env`，检查 `RIG_DOG_ENV_FILE` |
| 六六回答的是厂家的话，不是你的 | 第 8 步的角色介绍没粘，或被改过 |
| 六六反复追问同一个问题 | 角色介绍缺了「一次只调用一次」那条 |
| 六六一直不上线 | 只支持 2.4 GHz；让六六重新进入配网模式（坐下）重新配 |
| 烧录时串口被占用 | 关掉其他串口工具或另一个正在烧录的会话 |

---

## 11. 边界（对用户说清楚）

- 这是**桌面级原型**，没有自主移动与导航能力。
- 语音识别、语音合成与对话通道由厂家云提供，需要联网。
- 你（用户的 AI）负责「想」：记忆、工具、判断。六六是同一个智能体的一张脸。
- 上行是**异步**的：设备的工具回调只有 4 秒，完整作答通常要 10–20 秒，所以六六先应一声，答案稍后播报。
