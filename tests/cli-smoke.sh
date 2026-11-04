#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/clashctl-cli.XXXXXX")
trap 'rm -rf -- "$test_dir"' EXIT
runtime_dir="$test_dir/installed clashctl"
mkdir -p -- "$runtime_dir/bin" "$runtime_dir/resources" "$test_dir/links"
cp -a -- "$repo_dir/scripts" "$runtime_dir/"
cp -- "$repo_dir/.env" "$runtime_dir/.env"
printf '\nCLASHCTL_KERNEL=clashctl_smoke_kernel\nINIT_TYPE=nohup\n' >>"$runtime_dir/.env"
install -m 755 -- "$repo_dir/scripts/clashctl-exec.sh" "$runtime_dir/bin/clashctl"
ln -s -- '../installed clashctl/bin/clashctl' "$test_dir/links/first"
ln -s -- first "$test_dir/links/clashctl"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

# Check a relocated installation, spaces, and a relative symlink chain.
for command_path in "$runtime_dir/bin/clashctl" "$test_dir/links/clashctl"; do
    for help_arg in '' -h --help help; do
        if [ -n "$help_arg" ]; then
            env -u CLASHCTL_HOME "$command_path" "$help_arg" >"$test_dir/out" 2>"$test_dir/err"
        else
            env -u CLASHCTL_HOME "$command_path" >"$test_dir/out" 2>"$test_dir/err"
        fi
        grep -q 'Usage:' "$test_dir/out" || fail 'help text was missing'
        [ ! -s "$test_dir/err" ] || fail 'help wrote an error (including shift without arguments)'
    done
done

# An explicit override must take precedence over the launcher's own location.
install -m 755 -- "$repo_dir/scripts/clashctl-exec.sh" "$test_dir/standalone"
CLASHCTL_HOME="$runtime_dir" "$test_dir/standalone" help >"$test_dir/out"
grep -q 'Usage:' "$test_dir/out" || fail 'CLASHCTL_HOME override failed'
if CLASHCTL_HOME="$test_dir/missing" "$test_dir/standalone" help >"$test_dir/out" 2>"$test_dir/err"; then
    fail 'an incomplete installation succeeded'
fi
grep -q '安装目录不完整' "$test_dir/err" || fail 'missing installation diagnostic was absent'

if env -u CLASHCTL_HOME "$runtime_dir/bin/clashctl" does-not-exist >"$test_dir/out" 2>"$test_dir/err"; then
    fail 'an unknown command succeeded'
fi
grep -q 'Unknown subcommand:' "$test_dir/err" || fail 'unknown command diagnostic was absent'

# No core is started: status checks only this isolated installation's binary path.
if env -u CLASHCTL_HOME "$runtime_dir/bin/clashctl" status >"$test_dir/out" 2>"$test_dir/err"; then
    fail 'status unexpectedly found an isolated core process'
fi
[ ! -s "$test_dir/out" ] || fail 'status found a process outside the test installation'
[ ! -s "$test_dir/err" ] || fail 'status wrote an unexpected error'

printf 'CLI smoke tests passed.\n'
