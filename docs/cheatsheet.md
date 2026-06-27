# 工具速查表

> 日常命令速查，按使用频率排序

---

## 🎯 已安装工具一览

| 工具 | 命令 | 版本 | 用途 |
|---|---|---|---|
| zoxide | `z` | 0.9.9 | 智能 cd |
| starship | `starship` | 1.25.1 | 提示符美化 |
| eza | `ls/ll/la/lt` | 0.23.4 | 带图标的 ls |
| fzf | `Ctrl+R/T` | 0.71.0 | 模糊搜索 |
| ripgrep | `rg` / `grep` | 13.0.0 | 极速 grep |
| fd | `fd` / `find` | 8.3.1 | 友好的 find |
| bat | `bat` / `cat` | 0.19.0 | 带高亮的 cat |
| htop | `htop` | 3.0.5 | 进程监控 |
| tree | `tree` | 2.0.2 | 目录树 |
| tldr | `tldr` / `howto` | 0.6.4 | 命令速查 |
| nvm | `nvm` | 0.40.5 | Node 版本管理 |
| node | `node` | 24.14.1 LTS | JavaScript 运行时 |
| npm | `npm` | 11.11.0 | 包管理 |

---

## 🎮 核心快捷键（必背）

| 快捷键 | 功能 |
|---|---|
| **`Ctrl+R`** | 模糊搜索历史命令（神器） |
| **`Ctrl+T`** | 文件路径模糊查找 |
| **`Alt+C`** | 子目录模糊跳转 |
| `Ctrl+A` / `Ctrl+E` | 光标到行首 / 行尾 |
| `Ctrl+W` | 删除光标前一个单词 |
| `Ctrl+U` | 删除到行首 |
| `Ctrl+K` | 删除到行尾 |
| `Ctrl+L` | 清屏 |
| `Tab` / `Tab Tab` | 自动补全 / 显示所有选项 |

---

## 📂 文件 / 目录操作

```bash
# 列目录（eza 别名）
ls                # 带图标
ll                # 详细列表 + git 状态
la                # 显示隐藏文件
lt                # 树形视图（2 层）
ltl               # 树形视图（3 层）

# 查找文件（fd）
fd config         # 模糊查找名字含 config 的文件
fd -e py          # 只找 .py 文件
fd -e md README   # 找名为 README 的 .md 文件
fd -H hidden      # 包含隐藏文件
fd . -t f -S +10m # 找大于 10MB 的文件

# 搜索内容（ripgrep）
rg "TODO"         # 在当前目录搜 "TODO"
rg -i "error"     # 忽略大小写
rg -t py "import" # 只在 Python 文件中搜
rg -l "foo"       # 只输出文件名
rg "foo" -A 3 -B 1  # 显示匹配后 3 行，前 1 行

# 查看文件（bat）
cat file.py       # 带语法高亮
bat file.py       # 显式调用 bat
cat -r json file  # 强制 json 高亮
```

---

## 🚶 跳转

```bash
# zoxide 智能 cd
z proj            # 跳到任意层级中含 "proj" 的常用目录
z myapp src       # 跳到 myapp 项目下的 src
zi                # 交互式选择（用 fzf）

# 常用快捷
..                # 上一级
...               # 上两级
....              # 上三级
mkcd newdir       # 创建并进入目录
```

---

## 🐙 Git（最常用）

```bash
gs                # git status
gd                # git diff
gds               # git diff --staged
gl                # 最近 20 条提交（一行）
gll               # 最近 10 条 + 改动文件
gp                # git pull
gP                # git push
gco main          # 切到 main 分支
gco -b feature    # 新建并切到 feature 分支
gca               # 修改上次提交
```

---

## 📦 包管理（apt）

```bash
ai ripgrep        # sudo apt install ripgrep
au                # sudo apt update && sudo apt upgrade -y
aq ripgrep        # apt search ripgrep
as ripgrep        # apt show ripgrep
ar ripgrep        # sudo apt remove ripgrep
```

---

## ⚙️ systemd 服务

```bash
sc docker         # systemctl docker
scs docker        # 状态
scr docker        # 重启
sce docker        # enable + start
scd docker        # disable + stop
jctl docker       # 查看日志
logs docker       # 最近 100 行日志（自定义函数）
```

---

## 🌐 网络

```bash
myip              # 查看外部 IP
port 8080         # 谁在监听 8080
who-listen 8080   # 同上（详细）
curl ifconfig.me  # 外部 IP
curl -I https://baidu.com  # 测试 HTTP 状态
```

---

## 🗜️ 压缩 / 解压

```bash
extract file.tar.gz    # 智能解压（自动识别类型）
extract file.zip
extract file.7z

# 手动
tar czf out.tar.gz dir/
tar xzf in.tar.gz
zip -r out.zip dir/
unzip in.zip -d dest/
7z x in.7z
```

---

## 🐍 Python

```bash
venv              # 激活虚拟环境（自动找 .venv 或 venv）
python -m venv .venv  # 创建虚拟环境
pip install -r requirements.txt
```

---

## 🟢 Node.js

```bash
nvm ls            # 已安装版本
nvm install --lts # 安装最新 LTS
nvm use 24        # 切换到 24
nvm alias default 24  # 设默认版本

npm install -g pm2 typescript   # 全局安装
npm config get registry         # 查看镜像
```

---

## 🪟 Windows 互访

```bash
winhome           # 进入 Windows 用户目录
open .            # 用 Windows 资源管理器打开当前目录
code .            # 用 VS Code 打开当前目录（Remote-WSL）
explorer .        # 同 open
```

---

## 🩺 体检 / 监控

```bash
htop              # 实时进程监控
df -h             # 磁盘占用
free -h           # 内存占用
du -sh *          # 当前目录下各文件/目录大小
du -sh ./* | sort -h | tail  # 最大的 10 个
```

---

## 📚 求助

```bash
tldr tar          # 速查 tar 用法
howto git         # 同上
man ls            # 完整手册（按 q 退出）
rg --help         # 简短帮助
```

---

## 🎯 我的常用工作流

### 进入项目工作
```bash
z myproj          # 智能跳转到项目目录
ll                # 查看文件
code .            # VS Code Remote-WSL 打开
```

### 查找代码
```bash
rg "function foo"  # 搜函数定义
rg "TODO" -t py    # 找 Python 中的 TODO
fd -e log          # 找所有 log 文件
```

### Git 流程
```bash
gs                # 看状态
gco -b feat/x     # 新分支
# ...编辑代码...
gd                # 看改动
gaa               # add all（如配置过）
gc -m "msg"       # commit
gP                # push
```

### 系统问题排查
```bash
htop              # 看进程
logs nginx        # 看服务日志
journalctl -xe    # 看系统日志
df -h             # 看磁盘
port 8080         # 看端口占用
```

---

⏮️ [← 04 优化方案](04-optimization.md) | [返回主页](../README.md) | 下一篇：[故障排查 →](troubleshooting.md)
