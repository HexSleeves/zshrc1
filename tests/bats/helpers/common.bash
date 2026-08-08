# Shared harness for the z1 bats tests.
#
# No assertion libraries. The helpers below are plain bash and dump the
# captured output when they fail, which is all bats-assert was buying us.
#
# bats runs in bash and z1 is zsh, so every test hands a body to a real zsh and
# inspects what comes back. z1_zsh does that in an isolated HOME with its own
# XDG dirs, with $Z1 pointing at z1.zsh. Pass the body as an argument, or on
# stdin when it is long enough that quoting would hurt. Bodies source $Z1
# themselves rather than having the harness do it, because half of what we test
# is a zstyle set *before* z1 loads.
#
# Session bodies should print facts, not verdicts. `[[ $x == y ]] && echo ok`
# tells you nothing about what x was when it fails, so print x and assert on
# it here.

z1_setup() {
  PRJDIR="$BATS_TEST_DIRNAME"
  while [[ ! -f "$PRJDIR/z1.zsh" && "$PRJDIR" != / ]]; do
    PRJDIR="$(dirname "$PRJDIR")"
  done
  [[ -f "$PRJDIR/z1.zsh" ]] || {
    echo "cannot find z1.zsh above $BATS_TEST_DIRNAME" >&2
    return 1
  }

  TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/z1-test.XXXXXX")" || return 1
  # $TMPDIR often ends in a slash, and may be a symlink. Normalize, or $PWD and
  # $HOME never compare equal and nothing shortens paths to ~.
  TEST_HOME="$(cd "$TEST_HOME" && pwd -P)" || return 1
  mkdir -p "$TEST_HOME/bin" \
           "$TEST_HOME/.config/zsh" \
           "$TEST_HOME/.cache" \
           "$TEST_HOME/.local/share"
}

z1_teardown() {
  # Only ever delete a directory named the way z1_setup names them.
  case "$TEST_HOME" in
    */z1-test.??????) rm -rf "$TEST_HOME" ;;
  esac
}

# Run a zsh session over the given body, or over stdin when given no arguments.
# $Z1 is z1.zsh and $HOME is disposable.
z1_zsh() {
  local body
  if (( $# )); then
    body="$*"
  else
    body="$(cat)"
  fi
  run env -i \
    PATH="${Z1_TEST_PATH:-$PATH}" \
    HOME="$TEST_HOME" \
    ZDOTDIR="$TEST_HOME/.config/zsh" \
    XDG_CONFIG_HOME="$TEST_HOME/.config" \
    XDG_CACHE_HOME="$TEST_HOME/.cache" \
    XDG_DATA_HOME="$TEST_HOME/.local/share" \
    TERM=xterm-256color \
    Z1="$PRJDIR/z1.zsh" \
    zsh -f -c "$body"
}

# Drive a real zle session under a pseudo-terminal. The body is a key script
# for the zletest.zsh helpers; the output is the numbered probe log. Set
# $Z1_ZLE_RC to a file to have the session load it after z1.
z1_zle() {
  local body
  if (( $# )); then
    body="$*"
  else
    body="$(cat)"
  fi
  printf '%s\n' "$body" >"$TEST_HOME/scenario.zsh"
  run env -i \
    PATH="${Z1_TEST_PATH:-$PATH}" \
    HOME="$TEST_HOME" \
    ZDOTDIR="$TEST_HOME/.config/zsh" \
    XDG_CONFIG_HOME="$TEST_HOME/.config" \
    XDG_CACHE_HOME="$TEST_HOME/.cache" \
    XDG_DATA_HOME="$TEST_HOME/.local/share" \
    TERM=xterm-256color \
    Z1="$PRJDIR/z1.zsh" \
    Z1_ZLE_RC="${Z1_ZLE_RC:-}" \
    zsh "$PRJDIR/tests/bats/helpers/zletest.zsh" "$TEST_HOME/scenario.zsh"
}

# Write an executable stub into $HOME/bin. That directory is in z1's default
# prepath, so a stub shadows the real command even when one is installed.
stub_command() {
  local name="$1"; shift
  printf '#!/usr/bin/env zsh\n%s\n' "$*" >"$TEST_HOME/bin/$name"
  chmod +x "$TEST_HOME/bin/$name"
}

# Write a file, one line per argument, creating its directory first.
write_file() {
  local path="$1"; shift
  mkdir -p "${path%/*}"
  printf '%s\n' "$@" >"$path"
}

_dump_output() {
  printf -- '--- status: %s\n--- output ---\n%s\n--------------\n' \
    "$status" "$output" >&2
}

assert_success() {
  [[ "$status" -eq 0 ]] && return 0
  echo "expected success, got status $status" >&2
  _dump_output
  return 1
}

assert_failure() {
  [[ "$status" -ne 0 ]] && return 0
  echo "expected failure, got status 0" >&2
  _dump_output
  return 1
}

# Exact match against a whole line of output.
assert_line() {
  local want="$1" line
  while IFS= read -r line; do
    [[ "$line" == "$want" ]] && return 0
  done <<<"$output"
  echo "expected line: $want" >&2
  _dump_output
  return 1
}

refute_line() {
  local want="$1" line
  while IFS= read -r line; do
    if [[ "$line" == "$want" ]]; then
      echo "unexpected line: $want" >&2
      _dump_output
      return 1
    fi
  done <<<"$output"
  return 0
}

assert_output_contains() {
  [[ "$output" == *"$1"* ]] && return 0
  echo "expected output to contain: $1" >&2
  _dump_output
  return 1
}

refute_output_matches() {
  [[ ! "$output" =~ $1 ]] && return 0
  echo "expected output not to match: $1" >&2
  _dump_output
  return 1
}
