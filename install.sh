#!/usr/bin/env bash

for arg in "$@"; do
    case "$arg" in
    -h | --help)
        cat <<'EOF'
用法：bash install.sh [mihomo] [订阅 URL]

默认安装到 ~/clashctl，支持从任意工作目录调用本脚本。
使用仓库内置的 Linux amd64-v1 安装包，校验 SHA-256 后解压，不下载依赖。
可选设置写入源码目录的 .env.install.local，例如：
  CLASHCTL_HOME="$HOME/clashctl"
  CLASHCTL_SUB_URL="https://example.com/your-private-subscription"

安装后执行 source ~/.bashrc，即可使用 clashctl。
未提供订阅时，可稍后执行 clashctl sub add --use '<订阅 URL>'。
提供远程订阅 URL 时，添加订阅仍需要连接对应订阅服务器。
独立入口：~/.local/bin/clashctl（不会覆盖已有的其他命令）。
EOF
        exit 0
        ;;
    esac
done

CLASHCTL_SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
. "$CLASHCTL_SRC/scripts/preflight.sh" || exit 1

parse_args "$@" || exit 1
valid_env || exit 1

_okcat "安装内核：$CLASHCTL_KERNEL"
_okcat '📦' "安装路径：$CLASHCTL_HOME"

prepare_zip || exit 1

install_service || exit 1
install_clashctl || exit 1

# 在首次启动前写入密钥，避免调用会重启服务的 clashsecret。
if [ -z "$("$BIN_YQ" '.secret // ""' "$CLASH_CONFIG_MIXIN")" ]; then
    SECRET=$(_get_random_val) "$BIN_YQ" -i '.secret = strenv(SECRET)' "$CLASH_CONFIG_MIXIN" || exit 1
fi
_merge_config || exit 1
_detect_proxy_port
_detect_ext_addr
clashsecret

_valid_config "$CLASH_CONFIG_BASE" && {
    CLASHCTL_SUB_URL="file://$CLASH_CONFIG_BASE"
}
if [ -n "$CLASHCTL_SUB_URL" ]; then
    clashsub add --use "$CLASHCTL_SUB_URL" || exit 1
else
    _okcat "尚未添加订阅。加载命令后执行：clashctl sub add --use '<订阅 URL>'"
fi
if ! service_is_active >/dev/null 2>&1; then
    service_start || exit 1
    sleep 0.2
fi
service_is_active >/dev/null 2>&1 || {
    _errorcat '代理内核启动失败，请运行 clashctl log 查看日志。'
    exit 1
}
_okcat "Web 面板：http://${EXT_IP:-127.0.0.1}:${EXT_PORT}/ui（也可运行 clashctl ui 查看地址）"
_okcat '🎉' "请执行 source ~/.bashrc 为当前 SHELL 加载 clashctl 命令"
