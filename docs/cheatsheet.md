# 工具速查表

> 日常命令速查，按使用频率排序

---

## 📖 图例

| 标记 | 含义 | 说明 |
|---|---|---|
| 🟦 **命令** | 真实的二进制程序 | 装好后直接调用，如 `htop`、`rg` |
| 🟨 **别名** | `~/.bashrc` 中的 `alias` | 短命令的简写，如 `ls` → `eza` |
| 🟩 **函数** | `~/.bashrc` 中的 `function` | 带逻辑的封装，如 `extract`、`mkcd` |
| 🟪 **快捷键** | shell / 工具内置按键 | 如 `Ctrl+R`（fzf 提供） |

> 💡 别名和函数都定义在 `~/.bashrc` 中，重装可参考 [`scripts/bashrc.snippet.sh`](../scripts/bashrc.snippet.sh)

---

## 🎯 已安装工具一览

| 工具 | 命令 | 类型 | 版本 | 用途 |
|---|---|---|---|---|
| zoxide | `z` / `zi` | 🟩 函数 | 0.9.9 | 智能 cd |
| starship | `starship` | 🟦 命令 | 1.25.1 | 提示符美化 |
| eza | `ls` / `ll` / `la` / `lt` / `ltl` | 🟨 别名 | 0.23.4 | 带图标的 ls |
| fzf | `Ctrl+R/T`、`Alt+C` | 🟪 快捷键 | 0.71.0 | 模糊搜索 |
| ripgrep | `rg`（`grep` 🟨 → `rg`） | 🟦 + 🟨 | 13.0.0 | 极速 grep |
| fd | `fd`（`find` 🟨 → `fd`） | 🟦 + 🟨 | 8.3.1 | 友好的 find |
| bat | `bat`（`cat` 🟨 → `bat`） | 🟦 + 🟨 | 0.19.0 | 带高亮的 cat |
| htop | `htop` | 🟦 命令 | 3.0.5 | 进程监控 |
| tree | `tree` | 🟦 命令 | 2.0.2 | 目录树 |
| tldr | `tldr`（`howto` 🟨 → `tldr`） | 🟦 + 🟨 | 0.6.4 | 命令速查 |
| nvm | `nvm` | 🟩 函数 | 0.40.5 | Node 版本管理 |
| node | `node` | 🟦 命令 | 24.14.1 LTS | JavaScript 运行时 |
| npm | `npm` | 🟦 命令 | 11.11.0 | 包管理 |

---

## 🎮 核心快捷键（必背）

| 快捷键                  | 功能                     |
| ----------------------- | ------------------------ |
| **`Ctrl+R`**    | 模糊搜索历史命令（神器） |
| **`Ctrl+T`**    | 文件路径模糊查找         |
| **`Alt+C`**     | 子目录模糊跳转           |
| `Ctrl+A` / `Ctrl+E` | 光标到行首 / 行尾        |
| `Ctrl+W`              | 删除光标前一个单词       |
| `Ctrl+U`              | 删除到行首               |
| `Ctrl+K`              | 删除到行尾               |
| `Ctrl+L`              | 清屏                     |
| `Tab` / `Tab Tab`   | 自动补全 / 显示所有选项  |

---

## 📂 文件 / 目录操作

> 本节：🟨 别名 5 个（`ls/ll/la/lt/ltl`、`cat`、`find`、`grep`）、🟦 命令若干

```bash
# 列目录（全是 🟨 别名 → eza）
ls                # 🟨 带图标
ll                # 🟨 详细列表 + git 状态
la                # 🟨 显示隐藏文件
lt                # 🟨 树形视图（2 层）
ltl               # 🟨 树形视图（3 层）

# 查找文件
fd config         # 🟦 模糊查找名字含 config 的文件（也可用 🟨 find）
fd -e py          # 🟦 只找 .py 文件
fd -e md README   # 🟦 找名为 README 的 .md 文件
fd -H hidden      # 🟦 包含隐藏文件
fd . -t f -S +10m # 🟦 找大于 10MB 的文件

# 搜索内容
rg "TODO"         # 🟦 在当前目录搜 "TODO"（也可用 🟨 grep）
rg -i "error"     # 🟦 忽略大小写
rg -t py "import" # 🟦 只在 Python 文件中搜
rg -l "foo"       # 🟦 只输出文件名
rg "foo" -A 3 -B 1  # 🟦 显示匹配后 3 行，前 1 行

# 查看文件
cat file.py       # 🟨 → batcat，带语法高亮
bat file.py       # 🟦 显式调用 bat
cat -r json file  # 🟨 强制 json 高亮
```

---

## 🚶 跳转

> 本节：🟩 函数 3 个（`z`、`zi`、`mkcd`）、🟨 别名 3 个（`..`、`...`、`....`）

```bash
# zoxide 智能 cd（🟩 函数，zoxide 提供）
z proj            # 🟩 跳到任意层级中含 "proj" 的常用目录
z myapp src       # 🟩 跳到 myapp 项目下的 src
zi                # 🟩 交互式选择（用 fzf）

# 常用快捷（🟨 别名）
..                # 🟨 上一级
...               # 🟨 上两级
....              # 🟨 上三级
mkcd newdir       # 🟩 创建并进入目录
```

---

## 🐙 Git（最常用）

> 本节：全部 🟨 别名（`g` 是 git 别名，其余都是 `git xxx` 的简写）

```bash
gs                # 🟨 git status
gd                # 🟨 git diff
gds               # 🟨 git diff --staged（注意：未在 snippet 中，可手动加）
gl                # 🟨 最近 20 条提交（一行）
gll               # 🟨 最近 10 条 + 改动文件（同上）
gp                # 🟨 git pull
gP                # 🟨 git push
gco main          # 🟨 切到 main 分支
gco -b feature    # 🟨 新建并切到 feature 分支
gca               # 🟨 修改上次提交（同上）
```

---

## 📦 包管理（apt）

> 本节：全部 🟨 别名

```bash
ai ripgrep        # 🟨 sudo apt install ripgrep
au                # 🟨 sudo apt update && sudo apt upgrade -y
aq ripgrep        # 🟨 apt search ripgrep
as ripgrep        # 🟨 apt show ripgrep
ar ripgrep        # 🟨 sudo apt remove ripgrep
```

---

## ⚙️ systemd 服务

> 本节：🟨 别名 6 个（`sc/scs/scr/sce/scd/jctl`）、🟩 函数 1 个（`logs`）

```bash
sc docker         # 🟨 systemctl docker
scs docker        # 🟨 状态
scr docker        # 🟨 重启
sce docker        # 🟨 enable + start
scd docker        # 🟨 disable + stop
jctl docker       # 🟨 查看日志（journalctl -u）
logs docker       # 🟩 最近 100 行日志（自定义函数）
```

---

## 🌐 网络

> 本节：🟩 函数 2 个（`myip`、`who-listen`）、🟨 别名 1 个（`port`）、🟦 命令 1 个（`curl`）

```bash
myip              # 🟩 查看外部 IP（curl ifconfig.me）
port 8080         # 🟨 别名 → who-listen 函数
who-listen 8080   # 🟩 谁在监听 8080（自定义函数）
curl ifconfig.me  # 🟦 外部 IP
curl -I https://baidu.com  # 🟦 测试 HTTP 状态
```

---

## 🗜️ 压缩 / 解压

> 本节：🟩 函数 1 个（`extract`）、🟦 命令若干（`tar/zip/unzip/7z`）

```bash
extract file.tar.gz    # 🟩 智能解压（自动识别类型）
extract file.zip       # 🟩
extract file.7z        # 🟩

# 手动调用原始命令
tar czf out.tar.gz dir/    # 🟦
tar xzf in.tar.gz          # 🟦
zip -r out.zip dir/        # 🟦
unzip in.zip -d dest/      # 🟦
7z x in.7z                 # 🟦
```

---

## 🐍 Python

> 本节：🟨 别名 1 个（`venv`）、🟦 命令 2 个（`python`、`pip`）

```bash
venv              # 🟨 激活虚拟环境（自动找 .venv 或 venv）
python -m venv .venv  # 🟦 创建虚拟环境
pip install -r requirements.txt  # 🟦
```

---

## 🟢 Node.js

> 本节：🟩 函数 1 个（`nvm`）、🟦 命令 1 个（`npm`）

```bash
nvm ls            # 🟩 已安装版本
nvm install --lts # 🟩 安装最新 LTS
nvm use 24        # 🟩 切换到 24
nvm alias default 24  # 🟩 设默认版本

npm install -g pm2 typescript   # 🟦 全局安装
npm config get registry         # 🟦 查看镜像
```

---

## 🪟 Windows 互访

> 本节：全部 🟨 别名（指向 Windows 程序）

```bash
winhome           # 🟨 → cd /mnt/c/Users/14393
open .            # 🟨 → explorer.exe（Windows 资源管理器打开）
code .            # 🟨 → code.exe（VS Code Remote-WSL 打开）
explorer .        # 🟨 同 open
```

---

## 🩺 体检 / 监控

> 本节：🟦 命令 1 个（`htop`）、🟨 别名 3 个（`df`/`free`/`du` 都加了 `-h` 参数）

```bash
htop              # 🟦 实时进程监控
df -h             # 🟨 磁盘占用（即使省略 -h 也会自动加，因为 df 是别名）
free -h           # 🟨 内存占用（同上）
du -sh *          # 🟨 当前目录下各文件/目录大小
du -sh ./* | sort -h | tail  # 🟨 最大的 10 个
```

---

## 📚 求助

> 本节：🟦 命令 3 个（`tldr`、`man`、`rg`）、🟨 别名 1 个（`howto`）

```bash
tldr tar          # 🟦 速查 tar 用法
howto git         # 🟨 → tldr（同上）
man ls            # 🟦 完整手册（按 q 退出）
rg --help         # 🟦 简短帮助
```

---

## 🎯 我的常用工作流

### 进入项目工作

```bash
z myproj          # 🟩 智能跳转到项目目录
ll                # 🟨 查看文件
code .            # 🟨 VS Code Remote-WSL 打开
```

### 查找代码

```bash
rg "function foo"  # 🟦 搜函数定义
rg "TODO" -t py    # 🟦 找 Python 中的 TODO
fd -e log          # 🟦 找所有 log 文件
```

### Git 流程

```bash
gs                # 🟨 看状态
gco -b feat/x     # 🟨 新分支
# ...编辑代码...
gd                # 🟨 看改动
gaa               # ⚠️ 未配置：可在 .bashrc 加 alias gaa='git add --all'
gc -m "msg"       # ⚠️ 未配置：可在 .bashrc 加 alias gc='git commit'
gP                # 🟨 push
```

### 系统问题排查

```bash
htop              # 🟦 看进程
logs nginx        # 🟩 看服务日志（自定义函数）
journalctl -xe    # 🟦 看系统日志
df -h             # 🟨 看磁盘
port 8080         # 🟨 → 🟩 who-listen，看端口占用
```

---

⏮️ [← 04 优化方案](04-optimization.md) | [返回主页](../README.md) | 下一篇：[故障排查 →](troubleshooting.md)
