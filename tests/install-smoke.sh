#!/usr/bin/env bash
# Exercise installer setup without network, service control, or real shell edits.
set -eo pipefail

clashctl_repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
clashctl_test_dir=$(mktemp -d)
trap 'rm -rf -- "$clashctl_test_dir"' EXIT
fixture="$clashctl_test_dir/source with spaces"
runtime="$clashctl_test_dir/install 'quoted' path"
mkdir -p "$fixture/scripts" "$fixture/resources" "$fixture/archives" "$fixture/vendor/linux-amd64-v1"
cp "$clashctl_repo/.env" "$clashctl_repo/.env.install" "$clashctl_repo/install.sh" "$clashctl_repo/uninstall.sh" "$fixture/"
cp -a "$clashctl_repo/scripts/." "$fixture/scripts/"
cp "$clashctl_repo/resources/mixin.yaml" "$clashctl_repo/resources/profiles.yaml" "$fixture/resources/"
printf 'CLASHCTL_HOME=%q\nCLASHCTL_KERNEL=mihomo\n' "$runtime" >"$fixture/.env.install.local"

# Small local packages exercise real archive extraction without running a kernel.
package_stage="$clashctl_test_dir/package-stage"
mkdir -p "$package_stage/subconverter" "$package_stage/dist"
printf '#!/usr/bin/env bash\nexit 0\n' >"$package_stage/yq_linux_amd64"
chmod 755 "$package_stage/yq_linux_amd64"
cp "$package_stage/yq_linux_amd64" "$package_stage/subconverter/subconverter"
printf 'port: 25500\n' >"$package_stage/subconverter/pref.example.yml"
printf 'offline dashboard\n' >"$package_stage/dist/index.html"
gzip -c "$package_stage/yq_linux_amd64" >"$fixture/vendor/linux-amd64-v1/mihomo-linux-amd64-v1-test.gz"
tar -czf "$fixture/vendor/linux-amd64-v1/yq_linux_amd64.tar.gz" -C "$package_stage" yq_linux_amd64
tar -czf "$fixture/vendor/linux-amd64-v1/subconverter_linux64.tar.gz" -C "$package_stage" subconverter
tar -czf "$fixture/archives/dist.tar.gz" -C "$package_stage" dist
printf 'geo fixture\n' >"$fixture/resources/Country.mmdb"
printf 'geosite fixture\n' >"$fixture/resources/geosite.dat"
(
    cd "$fixture"
    sha256sum vendor/linux-amd64-v1/* archives/dist.tar.gz resources/Country.mmdb resources/geosite.dat >PACKAGES.sha256
)

# --help must return before loading local configuration or checking dependencies.
printf '\nreturn 73\n' >>"$fixture/.env.install.local"
bash "$fixture/install.sh" --help >/dev/null
sed -i '$d' "$fixture/.env.install.local"

cd /
CLASHCTL_SRC=$fixture
. "$fixture/scripts/preflight.sh"
[[ "$CLASHCTL_HOME" = "$runtime" && "$CLASHCTL_KERNEL" = mihomo ]]
[[ "$ZIP_UI" = "$fixture/archives/dist.tar.gz" ]]
parse_args mihomo
[[ "$BIN_KERNEL" = "$runtime/bin/mihomo" ]]
if parse_args --unknown >/dev/null 2>&1; then exit 1; fi

for forbidden in "$fixture" "$fixture/runtime" "$clashctl_test_dir"; do
    CLASHCTL_HOME=$forbidden
    if valid_env >/dev/null 2>&1; then
        printf 'Installer accepted forbidden path: %s\n' "$forbidden" >&2
        exit 1
    fi
done
CLASHCTL_HOME=$runtime
valid_env
touch "$runtime"
if valid_env >/dev/null 2>&1; then exit 1; fi
rm -- "$runtime"

# No dependency installation may invoke a network client.
curl() { printf 'Unexpected network call\n' >&2; return 99; }
uname() { case "$1" in -s) printf 'Linux\n' ;; -m) printf 'x86_64\n' ;; *) command uname "$@" ;; esac; }
select_local_packages
[[ "$CLASHCTL_PACKAGE_TIER" = v1 ]]
verify_local_packages
printf 'tampered\n' >>"$fixture/resources/geosite.dat"
if prepare_zip >/dev/null 2>&1; then exit 1; fi
[[ ! -e "$runtime" ]]
printf 'geosite fixture\n' >"$fixture/resources/geosite.dat"
cp "$fixture/PACKAGES.sha256" "$clashctl_test_dir/checksums"
sed -i '/resources\/Country.mmdb/d' "$fixture/PACKAGES.sha256"
if verify_local_packages >/dev/null 2>&1; then exit 1; fi
cp "$clashctl_test_dir/checksums" "$fixture/PACKAGES.sha256"

v2_flags='cx16 lahf_lm popcnt pni ssse3 sse4_1 sse4_2'
v3_flags="$v2_flags avx avx2 bmi1 bmi2 f16c fma movbe xsave abm"
_cpu_supports_level v1 'baseline'
_cpu_supports_level v2 "$v2_flags"
_cpu_supports_level v3 "$v3_flags"
if _cpu_supports_level v2 'sse4_2 popcnt'; then exit 1; fi
if _cpu_supports_level v3 "$v2_flags avx2 fma"; then exit 1; fi
saved_cpu_function=$(declare -f _cpu_supports_level)
_cpu_supports_level() { [ "$1" = v1 ]; }
mv "$fixture/vendor/linux-amd64-v1" "$fixture/vendor/linux-amd64-v3"
if select_local_packages >/dev/null 2>&1; then exit 1; fi
mv "$fixture/vendor/linux-amd64-v3" "$fixture/vendor/linux-amd64-v1"
eval "$saved_cpu_function"
uname() { case "$1" in -s) printf 'Linux\n' ;; -m) printf 'aarch64\n' ;; *) command uname "$@" ;; esac; }
if select_local_packages >/dev/null 2>&1; then exit 1; fi
uname() { case "$1" in -s) printf 'Linux\n' ;; -m) printf 'x86_64\n' ;; *) command uname "$@" ;; esac; }
prepare_zip
[[ -x "$runtime/bin/mihomo" && -x "$runtime/bin/yq" && -f "$runtime/resources/dist/index.html" ]]

# Only this temporary rc is written. HOME is never changed.
test_rc="$clashctl_test_dir/bashrc"
printf 'export UNRELATED_CLASHCTL_HOME=keep\n' >"$test_rc"
detect_rc() {
    SHELL_RC_BASH=$test_rc
    SHELL_RC_ZSH=
    SHELL_RC_FISH=
}
saved_link_function=$(declare -f install_command_link)
install_command_link() { return 0; }
INIT_TYPE=nohup
install_clashctl
[[ -f "$runtime/.clashctl-installed" && -x "$runtime/bin/clashctl" ]]
[[ -f "$runtime/scripts/preflight.sh" && ! -e "$runtime/.env.install.local" ]]
bash --noprofile --norc -c '. "$1"; [[ "$CLASHCTL_HOME" = "$2" ]]; declare -F clashctl >/dev/null' _ "$test_rc" "$runtime"
bash "$runtime/uninstall.sh" --help >/dev/null
bash -c 'CLASHCTL_SRC=$1; . "$CLASHCTL_SRC/scripts/preflight.sh" || exit; [[ "$CLASHCTL_HOME" = "$1" && "$CLASHCTL_KERNEL" = mihomo && "$INIT_TYPE" = nohup ]]' _ "$runtime"

# Verify executable links only inside the fixture and preserve unrelated files.
eval "$saved_link_function"
test_link="$clashctl_test_dir/commands/clashctl"
install_command_link "$test_link"
[[ "$(readlink -- "$test_link")" = "$runtime/bin/clashctl" ]]
install_command_link "$test_link"
rm -- "$test_link"
printf 'unrelated command\n' >"$test_link"
install_command_link "$test_link"
[[ "$(cat "$test_link")" = 'unrelated command' ]]

revoke_rc
[[ "$(cat "$test_rc")" = 'export UNRELATED_CLASHCTL_HOME=keep' ]]
rm -- "$test_rc"
apply_rc
[[ -f "$test_rc" ]]
revoke_rc
[[ ! -s "$test_rc" ]]

# Corrupt archives must fail even when their bytes have a valid checksum.
printf 'not an archive\n' >"$clashctl_test_dir/corrupt.gz"
if valid_zip "$clashctl_test_dir/corrupt.gz" >/dev/null 2>&1; then exit 1; fi

if declare -F download_zip _fetch_latest_tag >/dev/null; then exit 1; fi

printf 'Installer smoke checks passed.\n'
