# clashctl-portable

一个仓库包含安装脚本、内核、配置工具、订阅转换工具、Web 面板和地理数据库。新机器克隆后，安装器只校验和解压仓库内的文件，不查询 GitHub Releases，也不下载程序、面板或数据库。

## 新机器使用

目标系统：Linux x86_64，使用 Bash。仓库携带通用 amd64-v1 内核，不要求 AVX2。建议以普通用户安装。

- https://github.com/MetaCubeX/mihomo
- https://wiki.metacubex.one/startup/

```bash
git clone <自己的仓库URL> clashctl-portable
cd clashctl-portable
bash install.sh
source ~/.bashrc
clashctl sub add --use '你的订阅URL'
clashctl on
```

```bash
# 可能需要安装

sudo apt update
sudo apt install -y iproute2 net-tools
sudo apt install fzf
```

默认安装到 `~/clashctl`，源码目录和安装目录必须分开。没有订阅也能完成安装；添加 URL 后会下载订阅配置并启用。`clashctl on` 为当前终端设置代理环境变量。

**克隆完成后，程序依赖全部来自这个仓库。** 添加订阅以及使用代理仍需要访问自己的订阅服务器和节点。订阅中声明的远程 `rule-providers` / `proxy-providers` 仍按照该订阅获取；本仓库不会预先知道这些个性化资源。

系统需有 Bash、curl、tar、gzip、coreutils、procps，以及 iproute2（或等效的网络查询工具）。通常服务器已有这些基础工具；安装器会提示缺少的命令。默认面板使用 tar.gz，不需要 unzip 或 xz。若 Debian/Ubuntu 缺少基础工具，可先安装：

```bash
sudo apt install -y bash git curl ca-certificates tar gzip coreutils procps iproute2 util-linux less
```

普通用户默认使用 `nohup`，重启机器后执行 `clashctl on`。root 安装会尝试注册系统服务；root/TUN 模式请使用不含空格、引号的安装路径。

## 仓库里包含什么

| 路径 | 内容 |
| --- | --- |
| `vendor/linux-amd64-v1/` | mihomo v1.19.27、yq v4.53.3、subconverter v0.9.9 的完整本地安装包；转换器包含本地模板和默认规则。 |
| `resources/Country.mmdb` | 随仓库携带的 IP 地理数据库，约 9.9 MiB。 |
| `resources/geosite.dat` | 随仓库携带的域名分类数据库，约 3.9 MiB。 |
| `archives/dist.tar.gz` | 完整 Web 面板。 |
| `resources/mixin.yaml` | 默认设置，使用本地数据库和面板，关闭数据库自动更新。 |
| `PACKAGES.sha256` | 上述安装包和数据文件的 SHA-256 清单，安装前自动校验。 |

这些文件直接存入 Git，不使用 Git LFS，也不依赖子模块或额外下载地址。请完整提交 `vendor/`、`resources/`、`archives/dist.tar.gz` 和 `PACKAGES.sha256`。安装包缺失、损坏或 CPU 不兼容时，安装器会停止，不会联网寻找替代包。

`Country.mmdb` 与 `geosite.dat` 安装到 `~/clashctl/resources/`。订阅验证和内核运行统一使用这个目录，并强制使用 MMDB 模式；`GEOIP` 和 `GEOSITE` 规则分别读取这两个文件。若配置需要额外的 ASN 数据库，本版会提示缺少本地文件，而不会自动下载。

## 常用命令

```bash
clashctl on                         # 开启当前终端代理
clashctl off                        # 关闭代理
clashctl status                     # 查看内核状态
clashctl sub add --use '订阅URL'     # 添加并启用订阅
clashctl sub ls                     # 查看订阅
clashctl sub update                 # 更新订阅
clashctl node use -d                # 测速并选择节点
clashctl ui                         # 查看本地 Web 面板地址
clashctl secret                     # 查看面板密钥
clashctl log                        # 查看日志
```

Bash 中先 `source ~/.bashrc`，`on/off` 才能修改当前终端的代理变量。独立入口是 `~/clashctl/bin/clashctl`，并在没有同名命令时链接到 `~/.local/bin/clashctl`。独立进程不能修改父 shell 的环境。显式设置的 `CLASHCTL_HOME` 优先于入口路径。

本版禁用 `clashctl upgrade` 的在线内核升级，避免访问外部下载源。内核、数据库和面板以仓库中携带的版本为准。维护仓库时替换相应本地文件，并同步更新 `PACKAGES.sha256`；新机器随仓库获得相同版本。

## 自定义安装与卸载

安装前可执行 `cp .env.install.local.example .env.install.local`，在这个被 Git 忽略的文件中设置：

```bash
CLASHCTL_HOME="$HOME/clashctl"
CLASHCTL_SUB_URL=''  # 留空表示安装后再添加，也可写自己的订阅URL
```

安装器不会覆盖已有安装目录。要重装，请先备份个人配置并卸载，或使用新的安装目录。卸载命令：

```bash
bash "$HOME/clashctl/uninstall.sh"
```

## 个人配置与本机备份

正常新机部署不需要当前机器的个人配置。订阅 URL、节点凭据和面板密钥不会作为公共默认配置提交；运行时文件保存在源码目录以外。

本地 `private/clashctl-snapshot.tar.gz` 是原机器完整快照，包含个人配置和旧入口，仅用于备份；`private/offline-archives/` 是原始安装包留档。整个 `private/` 被 Git 忽略，不随克隆出现。实际部署所需的程序已单独放入可提交的 `vendor/`，不依赖这份备份。

## 检查与推送

```bash
sha256sum --check PACKAGES.sha256
bash tests/cli-smoke.sh
bash tests/install-smoke.sh
bash tests/local-config-smoke.sh
bash tests/local-assets-smoke.sh
bash tests/lock-smoke.sh
```

验证详情见 [docs/VALIDATION.md](docs/VALIDATION.md)。来源与许可证见 [docs/ORIGIN.md](docs/ORIGIN.md)。

目录已初始化为 `main` 分支。创建自己的空 GitHub 仓库后：

```bash
git add .
git diff --cached --stat
git commit -m "Bundle self-contained clashctl setup"
git remote add origin <自己的仓库URL>
git push -u origin main
```

提交列表应包含程序安装包、Country.mmdb、geosite.dat 和面板；`private/` 与 `.env.install.local` 应保持被忽略。
