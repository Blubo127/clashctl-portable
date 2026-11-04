#!/usr/bin/env bash

. "$CLASHCTL_SRC/.env" || return 1
if [ -f "$CLASHCTL_SRC/.env.install" ]; then
    . "$CLASHCTL_SRC/.env.install" || return 1
    if [ -f "$CLASHCTL_SRC/.env.install.local" ]; then
        . "$CLASHCTL_SRC/.env.install.local" || return 1
    fi
elif [ -f "$CLASHCTL_SRC/.clashctl-installed" ]; then
    # 安装后的卸载入口不依赖原始源码目录或其私有配置。
    CLASHCTL_HOME=$CLASHCTL_SRC
else
    printf '%s\n' '缺少安装配置或安装标记，无法确定 clashctl 路径。' >&2
    return 1
fi

[ -n "$CLASHCTL_HOME" ] || { printf '%s\n' 'CLASHCTL_HOME 不能为空。' >&2; return 1; }
case "$CLASHCTL_HOME" in /*) ;; *) CLASHCTL_HOME="$CLASHCTL_SRC/$CLASHCTL_HOME" ;; esac
CLASHCTL_HOME=$(readlink -m -- "$CLASHCTL_HOME") || return 1
case "${ZIP_UI:-}" in '' | /*) ;; *) ZIP_UI="$CLASHCTL_SRC/$ZIP_UI" ;; esac

for lib_file in "$CLASHCTL_SRC"/scripts/lib/*.sh; do
    [ -f "$lib_file" ] || continue
    . "$lib_file" || return 1
done

ARCHIVE_BASE_DIR="${CLASHCTL_SRC}/archives"
ZIP_BASE_DIR="${ARCHIVE_BASE_DIR}"

CLASHCTL_CMD_DIR="${CLASHCTL_HOME}/scripts/cmd"

valid_required() {
    local required_cmds=("pgrep" "pkill" "curl" "tar" "gzip" "shuf" "sha256sum" "readlink")
    local missing=()
    for cmd in "${required_cmds[@]}"; do
        command -v "$cmd" >&/dev/null || missing+=("$cmd")
    done

    command -v ss >&/dev/null || command -v netstat >&/dev/null || missing+=("ss/netstat")
    command -v ip >&/dev/null || command -v hostname >&/dev/null || missing+=("ip/hostname")

    [ ${#missing[@]} -eq 0 ] || { _errorcat "请先安装以下命令：${missing[*]}"; return 1; }
}

valid_env() {
    valid_required || return 1

    # 拒绝源码自身、其父目录及其子目录，避免覆盖源码或把私有配置写进 Git。
    case "$CLASHCTL_HOME/" in
    "$CLASHCTL_SRC/"*) _errorcat '安装目录不能位于源码目录内。'; return 1 ;;
    esac
    case "$CLASHCTL_SRC/" in
    "$CLASHCTL_HOME/"*) _errorcat '安装目录不能包含源码目录。'; return 1 ;;
    esac

    if [ -e "$CLASHCTL_HOME" ] || [ -L "$CLASHCTL_HOME" ]; then
        _errorcat "安装路径已存在，请选择新的 CLASHCTL_HOME；需要重装时先备份配置并卸载：$CLASHCTL_HOME"
        return 1
    fi

    case "$CLASHCTL_KERNEL" in
    mihomo) ;;
    *) _errorcat "离线仓库仅提供 mihomo 内核，当前设置：$CLASHCTL_KERNEL"; return 1 ;;
    esac

    [ -f "$ZIP_UI" ] || {
        _errorcat "找不到 Web UI 压缩包：$ZIP_UI"
        return 1
    }
    case "$ZIP_UI" in
    *.zip)
        command -v unzip >/dev/null 2>&1 || { _errorcat '自定义 ZIP 格式的 Web UI 需要 unzip；仓库默认 tar.gz 不需要。'; return 1; }
        ;;
    esac

    local _d="$CLASHCTL_HOME"
    while [[ ! -d "$_d" ]]; do _d="$(dirname "$_d")"; done
    [[ -w "$_d" ]] || { _errorcat "${CLASHCTL_HOME}：当前路径不可用，请在 .env.install.local 中更换安装路径。"; return 1; }
}

parse_args() {
    for arg in "$@"; do
        case $arg in
        mihomo)
            CLASHCTL_KERNEL=mihomo
            ;;
        clash)
            CLASHCTL_KERNEL=clash
            ;;
        http://* | https://* | file://*)
            CLASHCTL_SUB_URL=$arg
            ;;
        *)
            _errorcat "未知参数：$arg（运行 bash install.sh --help 查看用法）"
            return 1
            ;;
        esac
    done
    BIN_KERNEL="${BIN_BASE_DIR}/$CLASHCTL_KERNEL"
    return 0
}

# Match the Go AMD64 levels used by the bundled mihomo builds.
_cpu_supports_level() {
    local tier=$1 flags=${2:-} flag
    [ "$tier" = v1 ] && return 0
    [ -n "$flags" ] || flags=$(sed -n '/^flags[[:space:]]*:/ { s/^flags[[:space:]]*:[[:space:]]*//; p; q; }' /proc/cpuinfo)
    for flag in cx16 lahf_lm popcnt ssse3 sse4_1 sse4_2; do
        [[ " $flags " = *" $flag "* ]] || return 1
    done
    [[ " $flags " = *" pni "* || " $flags " = *" sse3 "* ]] || return 1
    [ "$tier" = v2 ] && return 0
    [ "$tier" = v3 ] || return 1
    for flag in avx avx2 bmi1 bmi2 f16c fma movbe xsave; do
        [[ " $flags " = *" $flag "* ]] || return 1
    done
    [[ " $flags " = *" abm "* || " $flags " = *" lzcnt "* ]]
}

select_local_packages() {
    local arch tier package_dir
    arch=$(uname -m)
    if [ "$(uname -s)" != Linux ] || [ "$arch" != x86_64 ]; then
        _errorcat "随仓库提供的安装包仅支持 Linux x86_64，当前系统：$(uname -s) $arch；不会联网下载其他架构。"
        return 1
    fi
    [ "$CLASHCTL_KERNEL" = mihomo ] || {
        _errorcat '此离线仓库仅提供 mihomo 内核，请设置 CLASHCTL_KERNEL=mihomo。'
        return 1
    }

    for tier in v3 v2 v1; do
        _cpu_supports_level "$tier" || continue
        package_dir="$CLASHCTL_SRC/vendor/linux-amd64-$tier"
        local kernels=("$package_dir"/mihomo-linux-amd64-*.gz)
        [ "${#kernels[@]}" -eq 1 ] || continue
        [ -f "${kernels[0]}" ] || continue
        [ -f "$package_dir/yq_linux_amd64.tar.gz" ] || continue
        [ -f "$package_dir/subconverter_linux64.tar.gz" ] || continue
        ZIP_BASE_DIR=$package_dir
        ZIP_KERNEL=${kernels[0]}
        ZIP_YQ="$package_dir/yq_linux_amd64.tar.gz"
        ZIP_SUBCONVERTER="$package_dir/subconverter_linux64.tar.gz"
        CLASHCTL_PACKAGE_TIER=$tier
        _okcat "使用仓库内置依赖：Linux x86_64 $tier"
        return 0
    done
    _errorcat '没有找到与本机 CPU 兼容的完整安装包。请确保 vendor/linux-amd64-v1、v2 或 v3 包含对应 mihomo、yq 和 subconverter 压缩包；本安装器不会下载依赖。'
    return 1
}

verify_local_packages() {
    local manifest="$CLASHCTL_SRC/PACKAGES.sha256" package relative
    [ -f "$manifest" ] || { _errorcat '缺少 PACKAGES.sha256，请重新获取完整仓库。'; return 1; }
    local required=(
        "$ZIP_KERNEL" "$ZIP_YQ" "$ZIP_SUBCONVERTER" "$ZIP_UI"
        "$CLASHCTL_SRC/resources/Country.mmdb" "$CLASHCTL_SRC/resources/geosite.dat"
    )
    for package in "${required[@]}"; do
        case "$package" in
        "$CLASHCTL_SRC/"*) relative=${package#"$CLASHCTL_SRC/"} ;;
        *) _errorcat "离线依赖必须位于仓库内并列入 PACKAGES.sha256：$package"; return 1 ;;
        esac
        [ -f "$package" ] || { _errorcat "缺少离线资源：$relative"; return 1; }
        CLASHCTL_REQUIRED_PATH=$relative awk '
            substr($0, 67) == ENVIRON["CLASHCTL_REQUIRED_PATH"] &&
            substr($0, 1, 64) ~ /^[[:xdigit:]]+$/ &&
            substr($0, 65, 2) ~ /^ [ *]$/ { found = 1 }
            END { exit !found }
        ' "$manifest" || { _errorcat "校验清单缺少资源：$relative"; return 1; }
    done
    (cd -- "$CLASHCTL_SRC" && sha256sum --check --strict --quiet PACKAGES.sha256) || {
        _errorcat '离线资源 SHA-256 校验失败，未执行解压。请重新获取完整仓库。'
        return 1
    }
    _okcat '内核、依赖、面板及地理数据 SHA-256 校验通过'
}

prepare_zip() {
    select_local_packages || return 1
    verify_local_packages || return 1
    BIN_KERNEL="${BIN_BASE_DIR}/$CLASHCTL_KERNEL"
    unzip_zip
}
valid_zip() {
    (($#)) || return 1
    local zip fail_zips=()
    for zip in "$@"; do
        case "$zip" in
        *.zip) unzip -tqq "$zip" || fail_zips+=("$zip") ;;
        *) gzip -tq "$zip" || fail_zips+=("$zip") ;;
        esac
    done

    [ ${#fail_zips[@]} -eq 0 ] || { _errorcat "文件验证失败：${fail_zips[*]} 请重新获取完整仓库中的离线安装包"; return 1; }
}
unzip_zip() {
    valid_zip "$ZIP_KERNEL" "$ZIP_YQ" "$ZIP_SUBCONVERTER" "$ZIP_UI" || return 1
    /usr/bin/install -d "$BIN_BASE_DIR" "$CLASH_RESOURCES_DIR" || return 1
    gzip -dc "$ZIP_KERNEL" >"$BIN_KERNEL" || return 1
    chmod 755 "$BIN_KERNEL" || return 1
    tar -xf "$ZIP_YQ" -C "${BIN_BASE_DIR}" || return 1
    /bin/mv -f "${BIN_BASE_DIR}"/yq_* "${BIN_BASE_DIR}/yq" || return 1
    tar -xf "$ZIP_SUBCONVERTER" -C "$BIN_BASE_DIR" || return 1
    /bin/cp "$BIN_SUBCONVERTER_DIR/pref.example.yml" "$BIN_SUBCONVERTER_CONFIG" || return 1
    case "$ZIP_UI" in
    *.zip) unzip -oqq "$ZIP_UI" -d "$CLASH_RESOURCES_DIR" ;;
    *) tar -xf "$ZIP_UI" -C "$CLASH_RESOURCES_DIR" ;;
    esac
}

_set_envs() {
    _set_env INIT_TYPE "$INIT_TYPE" || return 1
    _set_env CLASHCTL_KERNEL "$CLASHCTL_KERNEL"
}

install_clashctl() {
    local target_dir=$CLASHCTL_HOME
    local resource

    /usr/bin/install -d \
        "$target_dir/bin" \
        "$target_dir/scripts" \
        "$target_dir/resources" || return 1

    touch "$CLASH_CONFIG_BASE" || return 1

    /usr/bin/install -m 644 "$CLASHCTL_SRC/.env" "$target_dir/.env" || return 1
    _set_envs || return 1
    /usr/bin/install -m 755 "$CLASHCTL_SRC/uninstall.sh" "$target_dir/uninstall.sh" || return 1
    /usr/bin/install -m 644 "$CLASHCTL_SRC/scripts/preflight.sh" "$target_dir/scripts/preflight.sh" || return 1
    /usr/bin/install -m 755 "$CLASHCTL_SRC/scripts/clashctl-exec.sh" "$target_dir/bin/clashctl" || return 1

    /bin/cp -a "$CLASHCTL_SRC/scripts/cmd" "$target_dir/scripts/" || return 1
    /bin/cp -a "$CLASHCTL_SRC/scripts/lib" "$target_dir/scripts/" || return 1
    /bin/cp -a "$CLASHCTL_SRC/scripts/init" "$target_dir/scripts/" || return 1

    for resource in "$CLASHCTL_SRC"/resources/*; do
        /bin/cp -r "$resource" "$target_dir/resources/" || return 1
    done
    touch "$target_dir/.clashctl-installed" || return 1
    install_command_link || return 1
    apply_rc
}

install_command_link() {
    local command_link="${1:-$HOME/.local/bin/clashctl}"
    mkdir -p -- "$(dirname -- "$command_link")" || return 1
    if [ -e "$command_link" ] || [ -L "$command_link" ]; then
        if [ -L "$command_link" ] && [ "$(readlink -- "$command_link")" = "$CLASHCTL_HOME/bin/clashctl" ]; then
            return 0
        fi
        _okcat "保留已有命令：$command_link；本次安装的独立入口为 $CLASHCTL_HOME/bin/clashctl"
        return 0
    fi
    ln -s -- "$CLASHCTL_HOME/bin/clashctl" "$command_link" || return 1
    _okcat "已创建命令：$command_link（请确保 ~/.local/bin 位于 PATH 中）"
}

detect_rc() {
    SHELL_RC_BASH=
    SHELL_RC_ZSH=
    SHELL_RC_FISH=
    command -v bash >&/dev/null && {
        SHELL_RC_BASH="${HOME}/.bashrc"
    }
    command -v zsh >&/dev/null && {
        SHELL_RC_ZSH="${HOME}/.zshrc"
    }
    command -v fish >&/dev/null && {
        SHELL_RC_FISH="${HOME}/.config/fish/conf.d/clashctl.fish"
    }
    return 0
}
apply_rc() {
    detect_rc

    local source_clashctl quoted_home
    printf -v quoted_home '%q' "$CLASHCTL_HOME"
    printf -v source_clashctl '# >>> clashctl %s >>>\nexport CLASHCTL_HOME=%s\n. "$CLASHCTL_HOME/scripts/cmd/clashctl.sh"\n# <<< clashctl %s <<<' "$quoted_home" "$quoted_home" "$quoted_home"

    local rc written=()
    for rc in "$SHELL_RC_BASH" "$SHELL_RC_ZSH"; do
        [ -n "$rc" ] || continue
        touch -- "$rc" || return 1

        [ -s "$rc" ] && [ "$(tail -c 1 -- "$rc" | wc -l)" -eq 0 ] && {
            printf '\n' >>"$rc"
        }

        printf '%s\n' "$source_clashctl" >>"$rc" || return 1

        written+=("$rc")
    done

    [ -n "$SHELL_RC_FISH" ] && {
        mkdir -p -- "$(dirname -- "$SHELL_RC_FISH")" || return 1
        local fish_quoted=${CLASHCTL_HOME//\\/\\\\}
        fish_quoted=${fish_quoted//\'/\\\'}
        {
            printf "# clashctl shell-rc (managed by install.sh, do not edit)\n"
            printf "set -gx CLASHCTL_HOME '%s'\n\n" "$fish_quoted"
            cat -- "$CLASHCTL_CMD_DIR/clashctl.fish"
        } >"$SHELL_RC_FISH" || return 1
        chmod 0644 -- "$SHELL_RC_FISH" || return 1
        written+=("$SHELL_RC_FISH")
    }

    [ ${#written[@]} -gt 0 ] && _okcat '📄' "已写入 shell 配置：${written[*]}"
    . "$CLASHCTL_CMD_DIR"/clashctl.sh
}
revoke_rc() {
    detect_rc

    local rc quoted_home temp_rc
    printf -v quoted_home '%q' "$CLASHCTL_HOME"
    for rc in "$SHELL_RC_BASH" "$SHELL_RC_ZSH"; do
        [ ! -f "$rc" ] && continue
        temp_rc=$(mktemp "${rc}.clashctl.XXXXXX") || return 1
        CLASHCTL_RC_START="# >>> clashctl $quoted_home >>>" \
            CLASHCTL_RC_END="# <<< clashctl $quoted_home <<<" \
            awk '
                $0 == ENVIRON["CLASHCTL_RC_START"] { managed = 1; next }
                $0 == ENVIRON["CLASHCTL_RC_END"] { managed = 0; next }
                !managed { print }
            ' "$rc" >"$temp_rc" || { rm -f -- "$temp_rc"; return 1; }
        cat "$temp_rc" >"$rc" || { rm -f -- "$temp_rc"; return 1; }
        rm -f -- "$temp_rc"
    done

    if [ -n "$SHELL_RC_FISH" ] && [ -f "$SHELL_RC_FISH" ]; then
        local fish_quoted=${CLASHCTL_HOME//\\/\\\\}
        fish_quoted=${fish_quoted//\'/\\\'}
        if grep -Fxq -- "set -gx CLASHCTL_HOME '$fish_quoted'" "$SHELL_RC_FISH"; then
            rm -f -- "$SHELL_RC_FISH" || return 1
        fi
    fi
    return 0
}
