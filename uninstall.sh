#!/usr/bin/env bash

case "${1:-}" in
-h | --help)
    printf '%s\n' '用法：bash /安装路径/uninstall.sh' '停止当前安装的代理服务，删除安装目录及对应的 shell/命令入口。'
    exit 0
    ;;
'') ;;
*) printf '未知参数：%s\n' "$1" >&2; exit 1 ;;
esac

CLASHCTL_SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
. "$CLASHCTL_SRC/scripts/preflight.sh" || exit 1

# 只删除由本安装器创建的目录，并从实际安装读取内核和服务类型。
if [ "$CLASHCTL_HOME" = / ] || [ "$CLASHCTL_HOME" = "$HOME" ] ||
    [ ! -f "$CLASHCTL_HOME/.clashctl-installed" ] ||
    [ ! -f "$CLASHCTL_HOME/scripts/cmd/clashctl.sh" ]; then
    _errorcat "拒绝删除：不是本安装器创建的安装目录：$CLASHCTL_HOME"
    exit 1
fi
. "$CLASHCTL_HOME/scripts/cmd/clashctl.sh" || exit 1

! _is_root && tunstatus >&/dev/null && {
    _errorcat "请先关闭 Tun 模式"
    exit 1
}
uninstall_service || exit 1

# 清理旧版 sub update --auto 遗留的自管 crontab
command -v crontab >&/dev/null && {
    crontab -l 2>/dev/null | grep -Fv "$CLASHCTL_CRON_TAG" | crontab -
}

revoke_rc || exit 1
command_link="$HOME/.local/bin/clashctl"
if [ -L "$command_link" ] && [ "$(readlink -- "$command_link")" = "$CLASHCTL_HOME/bin/clashctl" ]; then
    rm -f -- "$command_link" || exit 1
fi
/usr/bin/rm -rf -- "$CLASHCTL_HOME" || exit 1

_okcat '✨' "已卸载，相关配置已清除"
[ -n "$http_proxy" ] && _failcat '❗' "当前终端仍残留代理环境变量，重开终端即可清除"
exit 0
