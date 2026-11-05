# 维护与检查

## 更新随包资源

本仓库固定提供 Linux x86_64 / amd64-v1 的 mihomo、yq 和 subconverter，以及本地数据库和面板。没有在线内核升级命令。

替换 `vendor/linux-amd64-v1/` 中的程序包、`resources/Country.mmdb`、`resources/geosite.dat` 或 `archives/dist.tar.gz` 后，更新 [来源与版本](ORIGIN.md)，并在仓库根目录重新生成校验清单：

```bash
sha256sum archives/dist.tar.gz resources/Country.mmdb resources/geosite.dat \
  vendor/linux-amd64-v1/*.gz > PACKAGES.sha256
```

程序包保持原有目录结构；mihomo 必须是通用 amd64-v1 构建，面板解压后应包含 `dist/index.html`。提交完整文件，不使用 Git LFS 下载指针。已有安装不会随 `git pull` 自动更新：先备份安装目录，再卸载并重新安装。

## 提交前检查

```bash
sha256sum --check PACKAGES.sha256
for test in tests/*-smoke.sh; do bash "$test" || exit 1; done
git diff --check
git status --short --ignored
```

测试只使用临时目录，不修改现有代理。首次修改安装或服务流程时，应额外在隔离环境验证安装、添加订阅、启停和卸载；具体范围见 [验证记录](VALIDATION.md)。

订阅地址、节点凭据和面板密钥应留在仓库以外的安装目录。`.env.install.local` 和本机 `private/` 备份已被忽略，不要强制提交，也不要用运行配置覆盖 `resources/` 中的公共模板。
