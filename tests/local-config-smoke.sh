#!/usr/bin/env bash
# Test local-file import and subscription recognition without starting a core.
set -eo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/clashctl-local-config.XXXXXX")
trap 'rm -rf -- "$test_dir"' EXIT
CLASH_RESOURCES_DIR="$test_dir/resources"
CLASHCTL_SUB_UA=clashctl-local-config-test
CLASHCTL_SUB_RETRY=0
mkdir -p -- "$CLASH_RESOURCES_DIR" "$test_dir/source path"
. "$repo_dir/scripts/lib/convert.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

# Literal local paths take precedence, including a real '%' in the filename.
for filename in 'plain.yaml' '中文 配置.yaml' 'literal#fragment?query%.yaml' 'literal%20name.yaml'; do
    source_path="$test_dir/source path/$filename"
    printf 'proxies: []\n# %s\n' "$filename" >"$source_path"
    FETCH_USERINFO=stale
    FETCH_FILENAME=stale
    _download_raw_config "$test_dir/imported.yaml" "file://$source_path" || fail "literal import: $filename"
    cmp -s -- "$source_path" "$test_dir/imported.yaml" || fail "content mismatch: $filename"
    [ -z "$FETCH_USERINFO$FETCH_FILENAME" ] || fail 'local import retained remote response metadata'
done

# Preserve ordinary file URL encoding when there is no matching literal path.
encode_path() {
    local input=$1 i byte hex
    local LC_ALL=C
    for ((i = 0; i < ${#input}; i++)); do
        byte=${input:i:1}
        case "$byte" in
        [a-zA-Z0-9.~_/-]) printf '%s' "$byte" ;;
        *) printf -v hex '%02X' "'$byte"; printf '%%%s' "$hex" ;;
        esac
    done
}
source_path="$test_dir/source path/编码 #?%.yaml"
printf 'proxies: []\n# percent-encoded URL\n' >"$source_path"
encoded_url="file://$(encode_path "$source_path")"
_download_raw_config "$test_dir/encoded.yaml" "$encoded_url" || fail 'percent-encoded file URL import'
cmp -s -- "$source_path" "$test_dir/encoded.yaml" || fail 'percent-encoded import changed file contents'

if _download_raw_config "$test_dir/missing.yaml" "file://$test_dir/not-found.yaml" >"$test_dir/out" 2>"$test_dir/err"; then
    fail 'a missing local file succeeded'
fi
if compgen -G "$CLASH_RESOURCES_DIR/.header.*" >/dev/null; then
    fail 'temporary response headers were not cleaned up'
fi

# Use the bundled YAML parser to distinguish native subscriptions from strings.
mkdir -p -- "$test_dir/bin"
tar -xzf "$repo_dir/vendor/linux-amd64-v1/yq_linux_amd64.tar.gz" -C "$test_dir/bin"
BIN_YQ="$test_dir/bin/yq_linux_amd64"
_errorcat() { printf '%s\n' "$*" >&2; return 1; }
for contents in 'proxies: [{name: test, type: direct}]' 'proxy-providers: {test: {type: file, path: nodes.yaml}}'; do
    printf '%s\n' "$contents" >"$test_dir/native.yaml"
    _is_native_yaml_config "$test_dir/native.yaml" || fail 'a native subscription was not recognized'
    _valid_sub_nodes "$test_dir/native.yaml" || fail 'a native subscription was rejected'
done
for contents in 'dHJvamFuOi8vdGVzdA==' 'proxies: []' 'proxy-providers: {}' 'proxies: scalar' 'proxies: ['; do
    printf '%s\n' "$contents" >"$test_dir/invalid.yaml"
    if _is_native_yaml_config "$test_dir/invalid.yaml"; then fail "invalid native detection: $contents"; fi
    if _valid_sub_nodes "$test_dir/invalid.yaml" >"$test_dir/out" 2>"$test_dir/err"; then
        fail "invalid node validation: $contents"
    fi
done
if _valid_sub_nodes "$test_dir/absent.yaml" >"$test_dir/out" 2>"$test_dir/err"; then
    fail 'a YAML read failure was accepted as valid nodes'
fi

printf 'Local config smoke tests passed.\n'
