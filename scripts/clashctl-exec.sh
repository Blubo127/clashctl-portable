#!/usr/bin/env bash

# Installed as <CLASHCTL_HOME>/bin/clashctl; resolve links from ~/.local/bin.
if [ -z "${CLASHCTL_HOME:-}" ]; then
    clashctl_entry=$(readlink -f -- "${BASH_SOURCE[0]}") || {
        printf 'clashctl: 无法确定命令安装路径\n' >&2
        exit 1
    }
    CLASHCTL_HOME=$(cd -- "$(dirname -- "$clashctl_entry")/.." && pwd -P) || exit 1
fi
export CLASHCTL_HOME

if [ ! -r "$CLASHCTL_HOME/.env" ] || [ ! -r "$CLASHCTL_HOME/scripts/cmd/clashctl.sh" ]; then
    printf 'clashctl: 安装目录不完整：%s，请重新运行安装脚本。\n' "$CLASHCTL_HOME" >&2
    exit 1
fi

# Keep the upstream shell functions' exit/error behavior; do not enable -e/-u.
# Source the shell integration to make on/off affect the calling shell's proxy env.
. "$CLASHCTL_HOME/scripts/cmd/clashctl.sh" || exit
clashctl "$@"
