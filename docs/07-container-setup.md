# 07 - 容器内效率工具（第三条产品线）

> **目标**:已经在测试容器里时,**自包含**安装 CLI,不依赖宿主机挂载 `~/.local`。
>
> **脚本**:[`scripts/setup-container.sh`](../scripts/setup-container.sh)

---

## 🎯 这一章解决什么问题

文档 06 的推荐做法是:工具装在**宿主机**,用 `drun-corex` 挂进容器。那条线适合「host 已有 myenv、容器经常重建」。

你现在的场景是另一条线:

- 已经在容器里(例如工作目录 `/data/ws`)
- 宿主机没有 myenv,或不能重建容器去补挂载
- 只要效率工具,不要 conda / Node / GPU / HF / vLLM
- 不能污染容器默认 bash(脚本、CI 仍假设系统 `ls`/`grep`)

**核心约束**:

| 你想要的 | 怎么实现 |
|---|---|
| 容器里就能用 | 跑一次 `setup-container.sh` |
| 不改默认 bash | 配置只在 `~/.guoda/`,`myenv` 才加载 |
| 不升级系统包 | **不做** `apt upgrade`,不换 apt 源 |
| root 镜像 | 直接 `apt`,不强制 `sudo` |
| HOME 随容器消失 | `--prefix /data/ws/.local` 把二进制放到持久盘 |

不要用:

| 脚本 | 原因 |
|---|---|
| `restore.sh` | WSL 专用(`wsl.conf` / nvm / linger) |
| `install_tools.sh` | 改 `~/.bashrc`,强制 sudo,还有 loginctl |
| `setup-myenv.sh` | 会装 conda / GPU / HF / 工作目录骨架,过重 |

---

## 🧰 装什么 / 不装什么

**apt**(另加下载依赖 `ca-certificates wget bash-completion`):

`htop` `tree` `ripgrep` `fd-find` `bat` `jq` `unzip` `git` `curl` `tldr`

**二进制**(默认 `$HOME/.local`,可用 `--prefix` 改):

`zoxide` `starship` `fzf` `eza` `yazi` `ble.sh` `uv` `rich`(rich-cli,给 yazi 预览用)

**兼容链接**:`fd` → `fdfind`,`bat` → `batcat`

**不装**:Miniconda、Node、nvitop、huggingface、vLLM 模板、`myenv-clean`

---

## 🚀 用法

```bash
cd /data/ws/guoda/env-setup   # 或你 clone 的路径

# 默认:二进制 → ~/.local ,配置 → ~/.guoda/
bash scripts/setup-container.sh

# 持久化(推荐:容器 HOME 不在 volume 上时)
bash scripts/setup-container.sh --prefix /data/ws/.local

myenv     # 进入效率工具环境
exit      # 回到容器默认 bash
```

### 选项

```text
--prefix DIR     安装前缀(默认 $HOME/.local)
--skip-apt       跳过 apt(镜像里已有 rg/fd 等)
--skip-yazi      跳过 Yazi
--skip-blesh     跳过 ble.sh
--skip-uv        跳过 uv
```

幂等:已装的工具会跳过。GitHub 不通时走 `lib.sh` 的代理回退。

---

## 🧠 装完之后

```
$ ls                         ← 系统默认 ls
$ myenv
[myenv] 容器效率工具已加载
(myenv) $ ls                 ← eza
(myenv) $ z proj             ← zoxide
(myenv) $ y                  ← yazi(退出时 cd)
(myenv) $ uv --version
(myenv) $ Ctrl+R             ← fzf
(myenv) $ exit
$ ls                         ← 又是系统 ls
```

| 路径 | 作用 |
|---|---|
| `$PREFIX/bin` | zoxide / starship / eza / yazi / uv |
| `$PREFIX/opt/fzf` | fzf |
| `$PREFIX/share/blesh` | ble.sh |
| `~/.guoda/yazi/` | yazi 配置 + `rich-preview` 插件 |
| `~/.guoda/bashrc.sh` | 容器版子 shell 配置 |
| `~/.guoda/env.sh` | PATH / HISTFILE / PREFIX;容器里补 `USER`、locale |
| `~/.guoda/blerc` | 输入提示设置(ble.sh) |
| `~/.guoda/prefix` | 给 `uninstall.sh` 看的前缀记录 |
| `/usr/local/bin/myenv` | 启动器(写不了则落到 `$PREFIX/bin/myenv`) |

配置仍在 `~/.guoda/`。若 `$HOME` 不持久,重建容器后需要再跑一遍脚本(二进制若在 `/data/ws/.local` 会跳过下载,只重部配置)。

`docker exec` 进容器时常见两条 ble.sh 警告(`$USER is empty`、`locale en_US.UTF-8 seems broken`)。`~/.guoda/env.sh` 会在加载 ble.sh **之前**自动补 `USER`、并把缺失的 locale 退回 `C.UTF-8`,只在 myenv 子 shell 生效。

---

## 📂 Yazi 预览(rich-cli)

`y` 打开 yazi 后,右侧预览用 [`rich-cli`](https://github.com/Textualize/rich-cli) 渲染:

`.md` `.json` `.csv` `.rst` `.ipynb` `.py` `.sh` `.toml` `.yaml`

配置在 `~/.guoda/yazi/`(`YAZI_CONFIG_HOME`),插件 `rich-preview.yazi` 调 `rich --force-terminal`。没装 `rich` 时自动退回 yazi 内置 code 预览。

---

## ⌨️ 输入提示

敲命令时的提示由三个东西合起来提供:

| 提示 | 来源 | 怎么用 |
|---|---|---|
| 灰色补全建议 | **ble.sh** | 继续敲,按 `→` 或 `Ctrl+F` 接受 |
| 语法高亮(命令绿/错红) | **ble.sh** | 敲错命令名当场变红 |
| 菜单式 Tab 补全 | **ble.sh** | `Tab` 后用方向键选 |
| 历史模糊搜索 | **fzf** | `Ctrl+R`(另有 `Ctrl+T` 找文件、`Alt+C` 跳目录) |
| 子命令/参数补全 | **bash-completion** | `git ch<Tab>` |

### 回车键

ble.sh 默认在多行编辑时把 `Enter` 当换行,底部提示 `-- MULTILINE -- (RET: insert a newline, C-j: run)`,要按 `C-j` 才执行。**`C-j` 被 Cursor 占用**,所以 `blerc` 里改成:

| 按键 | 作用 |
|---|---|
| `Enter` | 直接执行(命令语法不完整时才自动换行) |
| `Alt+Enter` 或 `C-x C-m` | 手动插入换行 |
| `Ctrl+C` | 放弃当前这段 |

### 其他可调项

调整提示行为改 `~/.guoda/blerc`(模板:[`scripts/guoda-blerc.sh`](../scripts/guoda-blerc.sh)):

```bash
bleopt complete_auto_delay=120   # 建议延迟(毫秒),嫌跳字就调大
bleopt complete_auto_history=1   # 从历史生成建议
ble-face -s auto_complete 'fg=242'   # 建议的灰度
```

没有灰色建议时按这个顺序查:

```bash
myenv
echo "$BLE_VERSION"                 # 空 = ble.sh 没加载
cat ~/.guoda/prefix                 # 确认安装前缀
ls "$(cat ~/.guoda/prefix)/share/blesh/ble.sh"
```

> ble.sh 只在**交互式** shell 里生效,`myenv -c "cmd"` 这类一次性执行不会有提示。

---

## ✅ 验证

```bash
# 未敲 myenv:应是系统默认
ls
command -v grep    # 通常 /usr/bin/grep

myenv
command -v zoxide eza starship uv
ls                 # eza
yazi --version
ble.sh 提示灰色建议(若安装成功)
exit
command -v ls      # 别名消失
```

卸载(会读 `~/.guoda/prefix`,清自定义前缀里的已知二进制,不删整个 `/data/ws`):

```bash
bash scripts/uninstall.sh --dry-run
bash scripts/uninstall.sh
```

---

## 🔗 三条产品线

| 维度 | WSL(`restore.sh`) | 共享宿主机(`setup-myenv.sh`) | 容器(`setup-container.sh`) |
|---|---|---|---|
| 改 `~/.bashrc` | 是 | 否 | 否 |
| 激活 | 登录即生效 | `myenv` | `myenv` |
| apt upgrade / 换源 | 会 | 会 | **不会** |
| conda / GPU / HF | 否(有 Node) | 是 | **否** |
| 二进制位置 | `~/.local` | `~/.local` | `~/.local` 或 `--prefix` |

- WSL:我的电脑我做主
- 宿主机:借来的机器要客气
- 容器:镜像保持原样,工具按需打开

---

⏮️ [← 06 共享服务器](06-server-setup.md) | [返回主页](../README.md) | [速查表 →](cheatsheet.md)
