#!/usr/bin/env bash
# Only short-lived sleep processes are started; no real proxy or sudo is used.
set -eo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/clashctl-lock.XXXXXX")
cleanup() {
    local pid_file
    for pid_file in "$test_dir"/*.pid; do
        [ -f "$pid_file" ] && kill "$(cat "$pid_file")" 2>/dev/null || true
    done
    rm -rf -- "$test_dir"
}
trap cleanup EXIT
. "$repo_dir/scripts/cmd/sub.sh"
. "$repo_dir/scripts/lib/service.sh"
CLASH_PROFILES_LOCK="$test_dir/profiles.lock"
_errorcat() { printf '%s\n' "$*" >&2; return 1; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

spawn_lock_child() {
    sleep 5 &
    printf '%s\n' "$!" >"$test_dir/lock-child.pid"
    return "${1:-0}"
}
_with_profiles_lock spawn_lock_child
kill -0 "$(cat "$test_dir/lock-child.pid")" || fail 'background lock test ended too early'
flock -n "$CLASH_PROFILES_LOCK" true || fail 'a background child retained the lock'
if _with_profiles_lock spawn_lock_child 37; then
    fail 'callback failure was lost'
else
    [ "$?" -eq 37 ] || fail 'callback failure status changed'
fi
flock -n "$CLASH_PROFILES_LOCK" true || fail 'failure path retained the lock'

# A fake core records inherited fd 9, then becomes a short sleep process.
cat >"$test_dir/fake-core" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$$" >"$CLASHCTL_TEST_PID"
if [ -e /proc/self/fd/9 ]; then printf 'inherited\n'; else printf 'closed\n'; fi >"$CLASHCTL_TEST_FD"
exec sleep 5
EOF
chmod +x "$test_dir/fake-core"
BIN_KERNEL="$test_dir/fake-core"
CLASH_RESOURCES_DIR=$test_dir
CLASH_CONFIG_RUNTIME="$test_dir/config.yaml"
service_manager=nohup
service_log_path="$test_dir/core.log"
_require_local_assets() { return 0; }
_is_root() { return 1; }
sudo() { "$@"; }
stty() { return 0; }
for start_function in service_start service_sudo_start; do
    export CLASHCTL_TEST_PID="$test_dir/$start_function.pid"
    export CLASHCTL_TEST_FD="$test_dir/$start_function.fd"
    (
        exec 9>>"$CLASH_PROFILES_LOCK"
        flock -x 9
        "$start_function"
        for attempt in $(seq 1 30); do
            [ -f "$CLASHCTL_TEST_FD" ] && break
            sleep 0.05
        done
        [ "$(cat "$CLASHCTL_TEST_FD")" = closed ] || fail "$start_function inherited fd 9"
    )
    flock -n "$CLASH_PROFILES_LOCK" true || fail "$start_function retained the lock"
done

printf 'Subscription lock smoke tests passed.\n'
