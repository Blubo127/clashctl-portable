# 来源与许可证

管理脚本基于 [nelvko/clash-for-linux-install](https://github.com/nelvko/clash-for-linux-install) 提交 `b2d4cbd6e4bed4ee59e1a4495f931f6e5d5498bc`，保留其 [MIT 许可证](../LICENSE)。本仓库增加离线安装、独立命令入口、本地数据库策略及部署检查。

| 随包资源 | 来源与版本 |
| --- | --- |
| `vendor/linux-amd64-v1/mihomo-linux-amd64-v1-v1.19.27.gz` | [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo)，v1.19.27，通用 amd64-v1。 |
| `vendor/linux-amd64-v1/yq_linux_amd64.tar.gz` | [mikefarah/yq](https://github.com/mikefarah/yq)，v4.53.3。 |
| `vendor/linux-amd64-v1/subconverter_linux64.tar.gz` | [subconverter 社区版](https://github.com/asdlokj1qpi233/subconverter)，v0.9.9，含本地模板和规则。 |
| `resources/Country.mmdb`、`resources/geosite.dat` | 从上述脚本基线仓库原样保留的数据库。 |
| `archives/dist.tar.gz` | 基线仓库内的 [zashboard](https://github.com/Zephyruso/zashboard) 面板，仅由 ZIP 重新打包为 tar.gz，内容不变。 |

所有程序包和数据直接随仓库提交，安装时不查询或下载更新。完整性清单见 [PACKAGES.sha256](../PACKAGES.sha256)。第三方组件各自适用其项目许可证，根目录 MIT 许可证针对管理脚本。
