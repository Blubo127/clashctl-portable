# clashctl-portable

在 Linux x86_64 上安装和管理 mihomo 代理。内核、订阅转换工具、Web 面板、`Country.mmdb` 和 `geosite.dat` 全部随仓库提供，**克隆后安装不需要从其他网站下载程序或数据库**。使用通用 amd64-v1 内核，不要求 AVX2。

## 安装与使用

建议使用普通用户和 Bash。在 Debian / Ubuntu 上，缺少基础工具时先执行：

```bash
sudo apt update
sudo apt install -y bash git curl ca-certificates tar gzip coreutils procps iproute2 util-linux less fzf
```

`fzf` 用于交互选择节点和订阅，可选；不需要额外安装 `net-tools`、`unzip` 或 `xz`。

```bash
git clone https://github.com/Blubo127/clashctl-portable.git
cd clashctl-portable
bash install.sh
source ~/.bashrc
clashctl sub add --use '你的订阅URL'
clashctl on
```

默认安装到 `~/clashctl`，与源码目录分开。安装器不会覆盖已有安装。普通用户使用 `nohup` 运行，机器重启后执行 `clashctl on` 即可重新启动。

添加订阅、连接节点及获取订阅自带的远程规则仍需联网。`Country.mmdb`、`geosite.dat` 和面板使用本地文件，不自动更新；若订阅使用 `IP-ASN` 规则，还需自行提供 `~/clashctl/resources/ASN.mmdb`。

## 常用命令

```bash
clashctl on                         # 启动代理，设置当前终端的代理变量
clashctl off                        # 停止代理，清除当前终端的代理变量
clashctl status                     # 查看运行状态
clashctl sub add --use '订阅URL'     # 添加并启用订阅
clashctl sub ls                     # 查看订阅
clashctl sub update                 # 更新订阅
clashctl node use -d                # 测速并选择节点
clashctl ui                         # 查看 Web 面板地址
clashctl secret                     # 查看面板密钥
clashctl log                        # 查看日志
clashctl help                       # 查看其他命令
```

新终端会自动加载命令；已经打开的 Bash 先执行 `source ~/.bashrc`。独立入口 `~/clashctl/bin/clashctl` 可供脚本调用，但不能修改父终端的代理变量。

## 自定义安装与卸载

安装前可复制 `.env.install.local.example` 为 `.env.install.local`，修改 `CLASHCTL_HOME` 或填写 `CLASHCTL_SUB_URL`。个人配置文件已被 Git 忽略。源码和安装目录不能相同或互相包含；root/TUN 模式请使用不含空格、引号的路径。

卸载会删除安装目录及其中的个人配置，请先备份需要保留的内容：

```bash
bash "$HOME/clashctl/uninstall.sh"   # 自定义安装时改成实际路径
```

## 维护

仓库不包含个人订阅；本机的 `private/` 备份被 Git 忽略。程序包位于 `vendor/linux-amd64-v1/`，数据库位于 `resources/`，面板位于 `archives/dist.tar.gz`；安装前会校验 `PACKAGES.sha256`。

版本更新、检查命令见 [维护说明](docs/MAINTENANCE.md)，测试范围见 [验证记录](docs/VALIDATION.md)，依赖来源及许可证见 [来源说明](docs/ORIGIN.md)。

Mihomo 官方资料：[项目](https://github.com/MetaCubeX/mihomo) · [配置文档](https://wiki.metacubex.one/startup/)
