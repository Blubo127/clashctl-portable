#!/usr/bin/env bash
# Validate bundled data with the real core's -t mode; never start a service.
set -eo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/clashctl-local-assets.XXXXXX")
trap 'rm -rf -- "$test_dir"' EXIT
CLASHCTL_SRC=$repo_dir
. "$repo_dir/scripts/preflight.sh"
select_local_packages
CLASHCTL_HOME="$test_dir/runtime with spaces"
CLASHCTL_KERNEL=mihomo
. "$repo_dir/scripts/lib/common.sh"
mkdir -p -- "$BIN_BASE_DIR" "$CLASH_RESOURCES_DIR" "$test_dir/subscriptions"
gzip -dc -- "$ZIP_KERNEL" >"$BIN_KERNEL"
chmod 755 -- "$BIN_KERNEL"
tar -xzf "$ZIP_YQ" -C "$BIN_BASE_DIR" ./yq_linux_amd64 2>/dev/null || tar -xzf "$ZIP_YQ" -C "$BIN_BASE_DIR" yq_linux_amd64
mv -- "$BIN_BASE_DIR/yq_linux_amd64" "$BIN_YQ"
cp -- "$repo_dir/resources/Country.mmdb" "$repo_dir/resources/geosite.dat" "$CLASH_RESOURCES_DIR/"
tar -xzf "$repo_dir/archives/dist.tar.gz" -C "$CLASH_RESOURCES_DIR"
cp -- "$repo_dir/resources/mixin.yaml" "$CLASH_CONFIG_MIXIN"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

source_config="$test_dir/subscriptions/native.yaml"
cat >"$source_config" <<'EOF'
geodata-mode: true
geo-auto-update: true
external-ui: other-panel
external-ui-name: other-panel
external-ui-url: http://127.0.0.1:9/remote-panel.zip
geox-url:
  mmdb: http://127.0.0.1:9/remote.mmdb
  geoip: http://127.0.0.1:9/remote.dat
  geosite: http://127.0.0.1:9/remote-site.dat
  asn: http://127.0.0.1:9/remote-asn.mmdb
rules:
  - GEOIP,CN,DIRECT
  - GEOSITE,cn,DIRECT
  - MATCH,DIRECT
EOF
cp -- "$source_config" "$test_dir/original.yaml"
_valid_config "$source_config" || fail 'native GEOIP/GEOSITE validation did not use bundled data'
cmp -s -- "$source_config" "$test_dir/original.yaml" || fail 'validation modified the original subscription'
cp -- "$source_config" "$CLASH_CONFIG_BASE"
touch "$CLASH_CONFIG_RUNTIME"
_merge_config || fail 'runtime merge failed'
"$BIN_YQ" -e '
  .geodata-mode == false and .geo-auto-update == false and
  .external-ui == "dist" and .external-ui-name == "" and .external-ui-url == "" and
  .geox-url.mmdb == "" and .geox-url.geoip == "" and
  .geox-url.geosite == "" and .geox-url.asn == ""
' "$CLASH_CONFIG_RUNTIME" >/dev/null || fail 'runtime did not enforce local asset settings'
cp -- "$CLASH_CONFIG_RUNTIME" "$test_dir/runtime-before.yaml"
cp -- "$CLASH_CONFIG_MIXIN" "$test_dir/mixin-before.yaml"
printf 'broken: [\n' >"$CLASH_CONFIG_MIXIN"
if _merge_config >"$test_dir/out" 2>"$test_dir/err"; then fail 'invalid YAML mixin was accepted'; fi
cmp -s -- "$CLASH_CONFIG_RUNTIME" "$test_dir/runtime-before.yaml" || fail 'failed merge did not restore runtime'
cp -- "$test_dir/mixin-before.yaml" "$CLASH_CONFIG_MIXIN"

# Preserve subscription-owned providers while changing only asset settings.
cat >"$test_dir/providers.yaml" <<'EOF'
rule-providers:
  custom:
    type: http
    url: https://example.com/rules.yaml
proxy-providers:
  custom:
    type: http
    url: https://example.com/nodes.yaml
EOF
"$BIN_YQ" -o=json '[.rule-providers, .proxy-providers]' "$test_dir/providers.yaml" >"$test_dir/providers-before"
_apply_local_asset_policy "$test_dir/providers.yaml"
"$BIN_YQ" -o=json '[.rule-providers, .proxy-providers]' "$test_dir/providers.yaml" >"$test_dir/providers-after"
cmp -s -- "$test_dir/providers-before" "$test_dir/providers-after" || fail 'asset settings changed subscription providers'

# Missing assets must fail before running a core or attempting sudo/start.
for asset in Country.mmdb geosite.dat dist/index.html; do
    mv -- "$CLASH_RESOURCES_DIR/$asset" "$test_dir/held-asset"
    if _valid_config "$source_config" >"$test_dir/out" 2>"$test_dir/err"; then fail "accepted missing $asset"; fi
    grep -q '本地资源缺失或不可读' "$test_dir/err" || fail "missing diagnostic for $asset"
    if service_start >"$test_dir/out" 2>"$test_dir/err"; then fail "started without $asset"; fi
    if service_sudo_start >"$test_dir/out" 2>"$test_dir/err"; then fail "sudo-started without $asset"; fi
    mv -- "$test_dir/held-asset" "$CLASH_RESOURCES_DIR/$asset"
done

# ASN is optional; absence must fail locally instead of selecting an online URL.
printf 'rules:\n  - IP-ASN,13335,DIRECT\n  - MATCH,DIRECT\n' >"$test_dir/asn.yaml"
if _valid_config "$test_dir/asn.yaml" >"$test_dir/out" 2>"$test_dir/err"; then fail 'unexpectedly accepted missing ASN data'; fi
grep -q '此配置需要 ASN.mmdb' "$test_dir/err" || fail 'missing local ASN guidance'
grep -q 'unsupported protocol scheme' "$test_dir/err" || fail 'missing ASN data tried an online fallback'
if compgen -G "$CLASH_RESOURCES_DIR/.validate.*" >/dev/null; then fail 'validation left temporary config files'; fi

# Displaying the local UI must not call a downloader.
. "$repo_dir/scripts/cmd/ui.sh"
curl() { fail 'UI called curl'; }
wget() { fail 'UI called wget'; }
_detect_ext_addr() { EXT_IP=127.0.0.1; EXT_PORT=9090; }
service_is_active() { return 0; }
service_start() { fail 'UI attempted a service start'; }
clashui >"$test_dir/ui.out"
grep -q 'http://127.0.0.1:9090/ui' "$test_dir/ui.out" || fail 'UI omitted the local address'

printf 'Local asset smoke tests passed.\n'
