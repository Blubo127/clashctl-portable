#!/usr/bin/env bash

clashupgrade() {
    case "${1:-}" in
    -h | --help)
        upgrade_help
        return 0
        ;;
    esac
    _failcat '此版本使用仓库自带的本地内核包，不在线升级。请更新仓库中的内核包，备份配置后重新部署。'
}

upgrade_help() {
    cat <<'EOF'
Usage:
  clashctl upgrade --help

此版本使用随仓库提供的本地内核包，禁用在线升级接口。
更新方式：更新仓库中的内核包，备份配置后重新部署。
EOF
}
