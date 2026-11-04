# 来源与随包资源

管理脚本整理自 [nelvko/clash-for-linux-install](https://github.com/nelvko/clash-for-linux-install)，基线提交：

```text
b2d4cbd6e4bed4ee59e1a4495f931f6e5d5498bc
```

保留上游 MIT [许可证](../LICENSE)、命令实现和服务模板。当前版本以自包含的 Linux x86_64 仓库部署为目标：程序包、数据库和面板直接随 Git 提交，安装器只执行本地校验与解压。

## 随包内容

| 资源 | 来源与版本 |
| --- | --- |
| `vendor/linux-amd64-v1/mihomo-linux-amd64-v1-v1.19.27.gz` | [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo)，v1.19.27 通用 amd64-v1 构建。在当前打包阶段按用户授权获取一次，并固定存入仓库；部署脚本没有下载地址。 |
| `vendor/linux-amd64-v1/yq_linux_amd64.tar.gz` | [mikefarah/yq](https://github.com/mikefarah/yq)，v4.53.3，复用原安装包。 |
| `vendor/linux-amd64-v1/subconverter_linux64.tar.gz` | [asdlokj1qpi233/subconverter](https://github.com/asdlokj1qpi233/subconverter)，v0.9.9，复用原安装包，包含本地模板与规则。 |
| `resources/Country.mmdb`、`resources/geosite.dat` | 从基线仓库原样保留的本地地理数据。 |
| `archives/dist.tar.gz` | 原基线 `archives/dist.zip` 内的 [zashboard](https://github.com/Zephyruso/zashboard) 面板，仅在本地重新打包为 tar.gz，以免新机器额外安装 unzip。 |

安装包和数据的具体 SHA-256 值见根目录 `PACKAGES.sha256`。第三方组件适用各自项目的许可证；根目录 MIT 许可证保留自安装管理脚本上游。

## 此整理版的主要改动

- 独立命令入口、自定义安装参数、路径处理和可从安装目录使用的卸载脚本。
- 移除安装阶段的版本查询、二进制下载和公网 IP 查询。
- 校验本地依赖及资源完整性，缺失时直接报错。
- 在订阅验证与运行合并时强制使用本地 Country、geosite 和面板，关闭数据库自动更新及下载 URL。
- 禁用管理命令的在线内核升级；个人订阅的远程 provider 保持原有行为。
- 加入命令入口、安装、配置导入及地理数据检查。

原上游推广内容、Issue 模板和维护工作流未纳入。
