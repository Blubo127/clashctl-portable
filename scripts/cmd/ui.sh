#!/usr/bin/env bash

clashui() {
    _require_local_assets || return 1
    _detect_ext_addr
    service_is_active >&/dev/null || service_start >/dev/null
    service_is_active >&/dev/null || _errorcat "无法启动服务，请检查日志" || return

    local local_ip=$EXT_IP
    local local_address="http://${local_ip}:${EXT_PORT}/ui"
    printf "\n"
    printf "╔═══════════════════════════════════════════════╗\n"
    printf "║                %s                  ║\n" "$(_okcat 'Web 控制台')"
    printf "║═══════════════════════════════════════════════║\n"
    printf "║                                               ║\n"
    printf "║     🔓 注意放行端口：%-5s                    ║\n" "$EXT_PORT"
    printf "║     🏠 内网：%-31s  ║\n" "$local_address"
    printf "║                                               ║\n"
    printf "╚═══════════════════════════════════════════════╝\n"
    printf "\n"
}
