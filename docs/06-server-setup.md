# 06 - 共享 GPU 服务器工作环境

> **目标**:在**共用 root**的 GPU 服务器上,让自己的工具链(zoxide/eza/fzf/yazi/bat/rg/conda/...)**只在需要时启用**,**不污染他人**,**新机一键装好**。
>
> **核心机制**:工具永久装,配置走子 shell。

---

## 🎯 这一章解决什么问题

公司 / 实验室的 GPU 服务器**所有人共用 root 账户**。你想用自己的 CLI 工具链,但是:

- 别人不熟悉 `zoxide`、`eza`、`yazi`,改 `~/.bashrc` 会让他们困惑
- 别人不希望 `ls` 突然变样、`find` 行为异常
- 你又不想每次重新登录都重装一遍工具

**这套方案的核心约束**:

| 你想要的 | 怎么实现 |
|---|---|
| 自己用得舒服 | 敲 `myenv` → 进子 shell → 全套别名/工具就绪 |
| 不影响别人 | 不改 `~/.bashrc`、`/etc/profile`、`/etc/bash.bashrc` |
| 新机一键搞定 | 跑一次 `setup-myenv.sh`,工具链永久装好 |
| 退出即还原 | `exit` 退出子 shell,配置层 100% 还原 |
| 收尾一键清场 | `myenv-clean` 清理你跑的容器 |

---

## 🧠 设计原理(为什么这么设计)

```
ssh root@server                         ← 进入「公共 root 环境」(别人看到的)
                                          ~/.bashrc 没动 / /etc/profile 没动
$ ls                                     ← 系统默认 ls
$ myenv                                  ← 触发开关
[myenv] 已加载 guoda 环境                ← 进入子 shell
(myenv) $ ls                             ← 现在是 eza(带图标)
(myenv) $ z proj                         ← zoxide
(myenv) $ y                              ← yazi 文件管理器
(myenv) $ Ctrl+R                         ← fzf
(myenv) $ exit                           ← 退出子 shell
$ ls                                     ← 又变回系统默认
```

**为什么这套设计能 100% 不影响别人:**

| 资源 | 状态 |
|---|---|
| `~/.bashrc`、`~/.profile` | **一行都不动** |
| `/etc/profile`、`/etc/bash.bashrc` | **不动** |
| 工具二进制(zoxide/eza/fzf/bat/rg/fd/starship/yazi) | 装在 `/usr/local/bin` 或 `~/.local/bin`,**只是磁盘上多几个文件** |
| 别人 ssh 进 root | 看不到你的子 shell(它在你的 SSH 会话进程树里) |
| 别人敲 `ls` / `find` / `grep` | 系统默认行为(因为没 source 你的配置) |

工具链**永久存在但默认不激活**,只有 `myenv` 才把它"打开"。这是最干净的隔离方式。

---

## 🚀 一、首次安装(`setup-myenv.sh`)

**位置**:[`scripts/setup-myenv.sh`](../scripts/setup-myenv.sh)

### 一次性安装流程

```bash
# 1. 在服务器上克隆项目(或 scp 上来)
git clone <你的仓库地址> ~/projects/personal/env-setup
cd ~/projects/personal/env-setup

# 2. 一键安装(默认全自动)
bash scripts/setup-myenv.sh

# 3. 装完即可使用
myenv
```

10-15 分钟后,**这台服务器上**就有了:

- ✅ apt 装好的基础工具(htop/tree/ripgrep/fd/bat/jq/unzip/7zip/poppler-utils/ffmpegthumbnailer)
- ✅ 二进制装好的现代工具(zoxide/starship/fzf/eza/**yazi**)
- ✅ Miniconda(在 `~/miniconda3/`)
- ✅ GPU 监控工具(nvitop/gpustat)
- ✅ HuggingFace 工具(hf_transfer/huggingface-cli)
- ✅ `myenv` 和 `myenv-clean` 命令(在 `/usr/local/bin/`)
- ✅ `~/.guoda/` 配置目录
- ✅ `~/projects/inference/`、`~/projects/eval/`、`~/data/`、`~/models/`、`~/logs/` 工作目录

### 安装选项

```bash
# 不要 Node(默认就不装)
bash scripts/setup-myenv.sh

# 需要 Node.js(写脚本/前端工具)
bash scripts/setup-myenv.sh --install-node

# 跳过 Yazi(不想要文件管理器)
bash scripts/setup-myenv.sh --skip-yazi

# 公司有内部 Docker 源,跳过镜像配置
bash scripts/setup-myenv.sh --skip-docker-mirror

# 已有 conda,跳过
bash scripts/setup-myenv.sh --skip-conda
```

### 关键文件清单(装完后)

```
/usr/local/bin/
├── myenv                       ⭐ 进入子 shell 的命令
└── myenv-clean                 ⭐ 一键清理容器

~/.guoda/                       ⭐ 你的"私有配置领地"
├── bashrc.sh                   ← 子 shell 加载的配置
├── env.sh                      ← 环境变量(HF_HOME 等)
├── starship.toml               ← 提示符配置(带 [myenv] 标识)
└── yazi/                       ← yazi 配置目录

~/.local/bin/                   ← 用户级二进制(zoxide/eza/yazi/...)
~/miniconda3/                   ← Python 环境
~/projects/                     ← 代码
│   ├── inference/run-vllm.sh
│   └── eval/run-eval.sh
~/data/                         ← 数据 + 结果
~/models/                       ← HF 模型缓存(HF_HOME 指向这里)
~/logs/                         ← 服务日志
```

---

## 🎮 二、日常工作流

### 标准工作流

```bash
ssh root@server                 # 1. 登录(公共 root 环境)
$ myenv                         # 2. 进入自己的环境
[myenv] 已加载 guoda 环境       #    提示符会显示 [myenv]
(myenv) $ proj-infer            # 3. 跳到推理项目
(myenv) $ ./run-vllm.sh qwen2-7b
(myenv) $ curl http://localhost:18001/v1/models
(myenv) $ proj-eval
(myenv) $ ./run-eval.sh mmlu http://localhost:18001/v1
(myenv) $ exit                  # 4. 退出子 shell(配置还原)
$                               # 5. 回到公共 root 环境
```

### 子 shell 里有什么

| 类别 | 命令 | 例子 |
|---|---|---|
| 文件浏览 | `ls` `ll` `la` `lt` `ltl` | eza(带图标、git 状态) |
| 文件管理 | `y` | **Yazi 文件管理器**(退出时 cd 到当前目录) |
| 跳转 | `z <关键词>` `zi` | zoxide 智能 cd |
| 搜索 | `Ctrl+R` `Ctrl+T` `Alt+C` | fzf 模糊搜索 |
| 内容查看 | `cat` `bat` | batcat(语法高亮) |
| 文件查找 | `find` `fd` | fd(友好版) |
| 内容搜索 | `grep` `rg` | ripgrep(极速) |
| Docker | `dps` `dpsi` `dl` `dx` `drm` `dc` | 容器管理简写 |
| GPU | `gpu` `nvi` `smi` `watch-gpu` | gpustat/nvitop |
| HuggingFace | `hf` `hf-dl` `hf-ls` `hf-du` | 模型管理 |
| 项目跳转 | `proj` `proj-infer` `proj-eval` `models` `results` | 工作目录快捷 |
| 帮助 | `howto` `tldr` | 命令速查 |

### Yazi 文件管理器(亮点)

```bash
(myenv) $ y                # 启动 yazi
# 在 yazi 里:
#   h/j/k/l     左/下/上/右
#   enter       打开
#   d           删除
#   y / p       复制 / 粘贴
#   r           重命名
#   /           搜索
#   z           zoxide 跳转(需要插件)
#   q           退出
```

**关键特性**:退出 yazi 时,当前 shell 会**自动 cd 到你最后浏览的目录**——这是通过 `~/.guoda/bashrc.sh` 里的 `y()` 函数实现的。所以 yazi 既是文件管理器,也是「视觉化的 cd 工具」。

### 退出子 shell

```bash
(myenv) $ exit        # 退出子 shell
$                     # 回到公共 root 环境
```

退出后:
- 所有别名失效(`ls` 又是系统 ls)
- 所有环境变量失效(`HF_HOME` 不再设置)
- 所有函数失效(`y`、`extract`、`mkcd` 等都没了)
- **但你跑的 Docker 容器、conda 环境、下载的模型都还在**(它们写在磁盘上)

---

## 💾 三、磁盘布局(100GB 配额怎么分)

| 项目 | 预算 | 位置 |
|---|---|---|
| 系统 + apt 包 | 5 GB | `/usr/` `/var/`(不归你管) |
| 工具链 | 3 GB | `~/.local/bin/` + `~/miniconda3/` |
| **模型缓存** | **50 GB** | `~/models/`(`HF_HOME` 指向这里) |
| **Docker 数据** | **20 GB** | 默认 `/var/lib/docker`(可改) |
| 数据集 + 评测结果 | 15 GB | `~/data/` |
| 代码 + 日志 | 5 GB | `~/projects/` `~/logs/` |
| 备用 | 2 GB | buffer |

### 关键:`HF_HOME` 不在默认位置

默认 HuggingFace 把模型缓存在 `~/.cache/huggingface`,几个大模型就爆盘。**这套方案把缓存改到 `~/models/`**(在 `~/.guoda/env.sh` 里设置),只在 myenv 子 shell 里生效。

```bash
(myenv) $ echo $HF_HOME
/root/models                    # 或 /home/<user>/models

(myenv) $ hf-du                 # 看每个模型的占用
14G     /root/models/hub/models--Qwen--Qwen2.5-72B-Instruct
4.2G    /root/models/hub/models--meta-llama--Llama-3.1-8B-Instruct
...
```

### Docker 数据根(可选)

如果 `/var/lib/docker` 在系统盘而你配额有限,改 `/etc/docker/daemon.json`(这一步是系统级,需要团队同意):

```json
{
    "data-root": "/root/docker/data",
    "registry-mirrors": ["https://docker.mirrors.ustc.edu.cn"]
}
```

`setup-myenv.sh` **默认配置 USTC 镜像源但不改 data-root**——后者需要根据你的实际磁盘情况手动改。

---

## 🐳 四、Docker 使用规范

### 容器命名(强制)

所有自己起的容器加 **`guoda-`** 前缀,这是这套方案的**铁律**——`myenv-clean` 就靠这个前缀识别哪些是你的。

```bash
# ✅ 推荐
docker run --name guoda-vllm-qwen2-7b ...

# ❌ 避免
docker run --name vllm ...        # 别人也可能起这个名字
docker run ...                    # 不命名,后期难管理
```

### 看自己跑的容器

```bash
(myenv) $ mydocker               # 只看 guoda-* 容器
(myenv) $ dps                    # 简化版 docker ps
(myenv) $ dpsi                   # 含已停止的
```

### 一键清理(`myenv-clean`)

```bash
(myenv) $ myenv-clean            # 交互式清理
🧹 myenv-clean 开始清理(prefix=guoda)
📦 停掉以下容器:
  - guoda-vllm-qwen2-7b
  - guoda-eval-runner
   继续吗? [y/N] y
✓ 容器已清理
✓ 没有 dangling 镜像
...
```

`myenv-clean` **只动 `guoda-` 前缀**的容器,别人的容器一字不改。

### 端口段

约定一个段给自己(18000-18999 是这套方案的默认),所有推理服务用这段。`~/.guoda/env.sh` 里设置了 `MY_PORT_BASE=18000`,`run-vllm.sh` 会读取。

---

## 🐳 五、在 Docker 容器内使用 myenv(关键场景)

你日常测试的 vLLM / SGLang daily/敏捷/发布镜像,**默认容器内是裸 bash**——没 zoxide、没 eza、没 yazi、没 fzf。本节解决这个痛点。

### 原理

容器是 Ubuntu 22.04 + Python 3.10(和你 host 同款 glibc),所以**直接把 host 的工具和配置挂载进容器**就行,**零额外维护**。

挂载 3 个目录即可:

| 挂载 | 作用 |
|---|---|
| `~/.guoda` | 配置文件(子 shell 加载) |
| `~/.local` | 工具二进制(zoxide/eza/yazi/starship) + 工具状态(zoxide db 等) |
| `~/.fzf` | fzf 安装目录 |

挂载用**读写**(不加 `:ro`)——因为 zoxide 要写 db,starship 要写 cache,共享无害。

### 三条新命令

`~/.guoda/bashrc.sh` 已封装好:

| 命令 | 作用 |
|---|---|
| **`drun-corex <name>`** | 启动 corex_test 模板容器(Ubuntu 22.04 + Python 3.10),自动挂载工具链 |
| **`drun-tencent <name>`** | 启动 tencentLLM 模板容器(带 `/stores` 挂载) |
| **`dexec <name>`** | 进容器(自动加载 myenv 配置,等于 docker exec 的智能版) |
| `drun <name> <image> [workdir] [args...]` | 通用版,自定义镜像和挂载 |

### 完整工作流

```bash
# host 上
(myenv) $ drun-corex corex_test_0309
✓ 容器 corex_test_0309 已启动
  镜像:    10.150.9.98:80/sw_test/corex_base:ubuntu22.04-py3.10
  工作目录: /data/ws
  进入:    dexec corex_test_0309
  停止:    docker rm -f corex_test_0309

# 进容器(替代 docker exec -it)
(myenv) $ dexec corex_test_0309
[myenv] 已加载 guoda 环境                 ← 容器内也是 myenv!
corex_test_0309 in /data/ws ❯ ls          ← eza 带图标
corex_test_0309 in /data/ws ❯ z cuda_daily_test   ← zoxide 跳转
corex_test_0309 ❯ y                       ← yazi 文件管理器
corex_test_0309 ❯ Ctrl+R                  ← fzf 历史搜索
corex_test_0309 ❯ exit                    ← 退出容器,回到 host myenv
(myenv) $                                 ← host 还在 myenv
```

### 如果想用别的镜像

```bash
# 换 Python 版本
drun-corex test_py311 10.150.9.98:80/sw_test/corex_base:ubuntu22.04-py3.11

# 用通用 drun,自定义 workdir 和额外挂载
drun mytest vllm/vllm-openai:latest /workspace --volume /etc/passwd:/etc/passwd:ro

# 启动后还是用 dexec 进
dexec mytest
```

### 已有容器怎么补挂载?

如果容器已经启动了(没挂载 myenv),两个办法:

**办法 A:容器内独立装一份**(不推荐,容器重建会丢)

```bash
docker exec -it <container> bash
# 容器内:
curl -sSL https://starship.rs/install.sh | sh
# ...太麻烦,不如重建
```

**办法 B:停掉重建**(推荐)

```bash
docker rm -f <container>
drun-corex <new-name>     # 用新命令重建,自带挂载
```

### 注意事项

1. **共享 zoxide db**:host 和容器共用 `~/.local/share/zoxide/db.zo`,所以你在容器内 `cd /data/ws/foo` 后,host 上 `z foo` 也能跳。如果不喜欢这种共享,在容器内 `export _ZO_DATA_DIR=/tmp/zoxide-db` 隔离。

2. **conda 不挂载**:容器内有自己的 Python(`/usr/bin/python3.10`),host 的 `~/miniconda3` **不挂载**——因为 conda 依赖大量系统库,跨容器可能崩。如果容器内需要 conda,在容器内独立装。

3. **不同 user**:如果容器内默认 user 不是 root(比如 `USER app`),挂载到 `/root/` 就读不到。这种情况改挂载到 `/home/<user>/` 或容器内对应路径。corex_base 镜像默认是 root,所以暂时不用考虑。

4. **glibc 兼容性**:如果未来某个 daily 包基于老 base(比如 CentOS 7 / Ubuntu 18.04),host 编译的 eza/yazi 可能跑不动。验证方法:

   ```bash
   docker exec -it <container> ldd /root/.local/bin/eza
   # 如果显示 "not a dynamic executable" 或者所有 lib 都能找到,就能跑
   # 如果显示 "version `GLIBC_2.32' not found",就需要装 musl 版本
   ```

---

## 🚀 六、vLLM 推理服务模板

详见 [`scripts/vllm-run.template.sh`](../scripts/vllm-run.template.sh)(`setup-myenv.sh` 会自动复制到 `~/projects/inference/run-vllm.sh`)。

### 用法

```bash
(myenv) $ proj-infer                     # cd ~/projects/inference
(myenv) $ ls models/                     # 看已有模型配置
(myenv) $ cp models/_template.sh models/qwen2-7b.sh
(myenv) $ vim models/qwen2-7b.sh         # 改 MODEL_PATH / TP_SIZE / PORT
(myenv) $ ./run-vllm.sh qwen2-7b
```

### 模型配置示例(`models/qwen2-7b.sh`)

```bash
MODEL_PATH="/root/models/hub/models--Qwen--Qwen2.5-7B-Instruct/snapshots/xxx"
SERVED_NAME="qwen2.5-7b"
TP_SIZE=1           # 单卡
MAX_LEN=32768
PORT=18001
```

---

## 📊 七、评测流程模板

详见 [`scripts/eval-run.template.sh`](../scripts/eval-run.template.sh)。

### 用法

```bash
(myenv) $ proj-eval                      # cd ~/projects/eval
(myenv) $ ./run-eval.sh mmlu http://localhost:18001/v1
```

评测结果会按日期归档到 `~/data/results/<时间戳>/`,同时写一个 `meta.json` 记录用的哪个 endpoint、哪个模型、什么时间。

---

## 🐍 八、Python 环境(conda)

`setup-myenv.sh` 装好 Miniconda 后,在 myenv 子 shell 里:

```bash
(myenv) $ conda-ls                      # 看已有环境
(myenv) $ conda create -n infer python=3.11 -y
(myenv) $ conda activate infer
(infer) (myenv) $ pip install vllm
```

### 推荐的三个环境

| 环境 | 用途 | Python |
|---|---|---|
| `infer` | 推理服务(vLLM / SGLang) | 3.11 |
| `eval` | 评测(lm-eval / evalplus) | 3.10 |
| `tools` | 日常工具(jupyter / pandas) | 3.11 |

---

## 🤗 九、HuggingFace 模型管理

```bash
# 下载(支持断点续传,大模型会自动用 hf_transfer 加速)
(myenv) $ hf-dl Qwen/Qwen2.5-7B-Instruct

# 国内服务器启用镜像(取消 ~/.guoda/env.sh 里的注释)
# export HF_ENDPOINT=https://hf-mirror.com
(myenv) $ hf-dl meta-llama/Llama-3.1-70B-Instruct

# 看缓存占用
(myenv) $ hf-du
(myenv) $ du -sh $HF_HOME

# 交互式清理(选模型删)
(myenv) $ hf-ls                         # 扫描缓存
(myenv) $ huggingface-cli delete-cache
```

---

## 📈 十、GPU 监控

```bash
(myenv) $ gpu                           # gpustat(紧凑一次性快照)
(myenv) $ nvi                           # nvitop(交互式,类似 htop)
(myenv) $ watch-gpu                     # 每 2 秒刷新 gpustat
(myenv) $ gpu-procs                     # 看每个 GPU 上跑的进程
```

---

## 🛡️ 十一、不影响别人的几条铁律

1. **永远不改 `~/.bashrc`、`/etc/profile`、`/etc/bash.bashrc`**——所有自己的东西放 `~/.guoda/`
2. **Docker 容器加 `guoda-` 前缀**——方便 `myenv-clean` 识别,也方便团队看到「这是 guoda 跑的」
3. **端口用 18000-18999 段**——避免和系统服务撞
4. **不在 `/tmp` 放大文件**——`/tmp` 是共享的,放模型会被人删
5. **Docker 不用 `latest` 标签**(尽量用具体版本)——避免镜像被覆盖后别人的脚本失效
6. **后台任务用 `nohup` 或 Docker `--restart`**——不要依赖 ssh 会话
7. **logs 写 `~/logs/`**——不污染 `/var/log/`
8. **退服务器前先 `myenv-clean`**——把容器收尾,GPU 释放出来给别人用

---

## ✅ 十二、新机检查清单

`setup-myenv.sh` 跑完后,依次验证:

```bash
# 0. 公共环境(未敲 myenv)应该是系统默认
ssh root@server
$ ls                                 # 系统默认 ls,没图标
$ which grep                         # /usr/bin/grep

# 1. 敲 myenv,进入子 shell
$ myenv
[myenv] 已加载 guoda 环境

# 2. 验证工具链
(myenv) $ which ls                   # 应该是 eza 别名
(myenv) $ z --version
(myenv) $ starship --version
(myenv) $ yazi --version
(myenv) $ conda --version

# 3. 验证 GPU
(myenv) $ gpu                        # gpustat 应该显示所有 GPU

# 4. 验证 HuggingFace
(myenv) $ echo $HF_HOME              # 应该是 /root/models
(myenv) $ hf --version

# 5. 验证 Docker
(myenv) $ docker info | grep -A 2 "Registry Mirrors"

# 6. 验证工作目录
(myenv) $ ls ~/projects/inference/   # run-vllm.sh
(myenv) $ ls ~/models                # 空目录(还没下模型)

# 7. 退出
(myenv) $ exit
$ which ls                           # 又变回 /bin/ls
```

任何一项 ✗ 见 [`troubleshooting.md`](troubleshooting.md)。

---

## 🔄 十三、典型场景示例

### 场景 A:测一个新模型

```bash
ssh root@server
$ myenv

# 1. 拉模型
(myenv) $ hf-dl Qwen/Qwen2.5-72B-Instruct

# 2. 写配置
(myenv) $ proj-infer
(myenv) $ cp models/qwen2-7b.sh models/qwen2-72b.sh
(myenv) $ vim models/qwen2-72b.sh     # TP_SIZE=4, MAX_LEN, PORT=18002

# 3. 起服务
(myenv) $ ./run-vllm.sh qwen2-72b

# 4. 跑评测
(myenv) $ proj-eval
(myenv) $ ./run-eval.sh mmlu http://localhost:18002/v1

# 5. 看结果
(myenv) $ results
(myenv) $ ls
(myenv) $ jq '.results' $(ls -t | head -1)/mmlu.json

# 6. 收尾
(myenv) $ myenv-clean
(myenv) $ exit
```

### 场景 B:SSH 断开后服务还在跑

`run-vllm.sh` 默认用 `--restart=unless-stopped`,所以:

```bash
# 起服务后,即使 SSH 断开,Docker 容器还在跑
(myenv) $ ./run-vllm.sh qwen2-7b

# 假装 SSH 断开
$ exit                                # 或直接关掉终端

# 重新登录,服务还在
ssh root@server
$ docker ps                           # 公共环境也能看到容器(因为 Docker 是系统级的)
$ myenv
(myenv) $ curl http://localhost:18001/v1/models    # 服务还在响应

# 用完手动收尾
(myenv) $ myenv-clean
```

### 场景 C:同时跑多个实验

```bash
(myenv) $ proj-infer
(myenv) $ ./run-vllm.sh qwen2-7b      # PORT=18001
(myenv) $ cp models/qwen2-7b.sh models/qwen2-72b.sh
(myenv) $ vim models/qwen2-72b.sh     # PORT=18002, TP_SIZE=4
(myenv) $ ./run-vllm.sh qwen2-72b     # 另一个端口

(myenv) $ mydocker                    # 看自己跑的所有容器
```

---

## 📝 十四、维护建议

- **新增评测任务**:在 `~/projects/eval/tasks/` 加一个 `.sh` 配置
- **新增推理模板**:在 `~/projects/inference/models/` 加一个 `.sh` 配置
- **每次实验完**:`myenv-clean` → 把结果归档 → 在笔记里记一笔
- **每月**:`docker system df`、`hf-du` 清理
- **改了 `~/.guoda/` 配置**:把改动同步回这个项目,提交 git
- **新机器**:`git clone` 项目 → `bash scripts/setup-myenv.sh` → 10 分钟搞定

---

## 🔗 与 WSL 个人环境的关系

| 维度 | WSL(01-05 章) | 共享服务器(本章) |
|---|---|---|
| 还原脚本 | `scripts/restore.sh` | `scripts/setup-myenv.sh` |
| 配置位置 | 直接改 `~/.bashrc` | `~/.guoda/`(完全隔离) |
| 触发方式 | 永久生效 | 敲 `myenv` 进子 shell |
| 退出方式 | 不退出 | `exit` 子 shell |
| 共享工具链(zoxide/eza/yazi/...) | ✅ | ✅ |
| 共享别名规范 | ✅ | ✅(主体) |

**好处**:两套环境共享同一份 git 仓库,但**配置哲学完全不同**——
- WSL 是「**我的电脑我做主**」
- 服务器是「**借来的机器要客气**」

---

⏮️ [← 05 一键还原](05-restore.md) | [返回主页](../README.md) | [速查表 →](cheatsheet.md)
