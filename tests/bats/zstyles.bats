#!/usr/bin/env bats
# .zstyles is sourced by z1 unless you claim the job yourself.

load helpers/common

setup() {
  z1_setup
  write_file "$TEST_HOME/.config/zsh/.zstyles" \
    'print x >>! $HOME/runs' \
    "zstyle ':demo:from' zstyles 'yes'"
}
teardown() { z1_teardown; }

@test "z1 sources .zstyles" {
  z1_zsh <<'EOS'
source $Z1
zstyle -t ':demo:from' zstyles && print "sourced: yes" || print "sourced: no"
print "runs: $(wc -l <$HOME/runs | tr -d ' ')"
EOS
  assert_success
  assert_line "sourced: yes"
  assert_line "runs: 1"
}

@test "re-sourcing z1 does not load .zstyles twice" {
  z1_zsh <<'EOS'
source $Z1
source $Z1
print "runs: $(wc -l <$HOME/runs | tr -d ' ')"
EOS
  assert_success
  assert_line "runs: 1"
}

@test "claiming the load beforehand skips it" {
  z1_zsh <<'EOS'
zstyle ':z1:zstyles' loaded 'yes'
source $Z1
[[ -f $HOME/runs ]] && print "sourced: yes" || print "sourced: no"
zstyle -t ':demo:from' zstyles && print "style: set" || print "style: unset"
EOS
  assert_success
  assert_line "sourced: no"
  assert_line "style: unset"
}

@test "loading .zstyles by hand afterwards still works" {
  z1_zsh <<'EOS'
zstyle ':z1:zstyles' loaded 'yes'
source $Z1
source $ZDOTDIR/.zstyles
zstyle -t ':demo:from' zstyles && print "style: set" || print "style: unset"
EOS
  assert_success
  assert_line "style: set"
}

@test "z1 marks .zstyles as loaded once it has sourced them" {
  z1_zsh <<'EOS'
source $Z1
zstyle -t ':z1:zstyles' loaded && print "marked: yes" || print "marked: no"
EOS
  assert_success
  assert_line "marked: yes"
}

@test "the skip zstyle skips the load" {
  z1_zsh <<'EOS'
zstyle ':z1:zstyles' skip 'yes'
source $Z1
[[ -f $HOME/runs ]] && print "sourced: yes" || print "sourced: no"
zstyle -t ':demo:from' zstyles && print "style: set" || print "style: unset"
EOS
  assert_success
  assert_line "sourced: no"
  assert_line "style: unset"
}

@test "skipping does not claim .zstyles were loaded" {
  z1_zsh <<'EOS'
zstyle ':z1:zstyles' skip 'yes'
source $Z1
zstyle -t ':z1:zstyles' loaded && print "marked: yes" || print "marked: no"
EOS
  assert_success
  assert_line "marked: no"
}

@test "a missing .zstyles file is not an error" {
  rm -f "$TEST_HOME/.config/zsh/.zstyles"

  z1_zsh <<'EOS'
source $Z1
print "rc: $?"
EOS
  assert_success
  assert_line "rc: 0"
}

@test "ZSTYLESFILE points at the file z1 loads" {
  z1_zsh 'source $Z1; print "file: $ZSTYLESFILE"'
  assert_success
  assert_line "file: $TEST_HOME/.config/zsh/.zstyles"
}

@test "a preset ZSTYLESFILE moves the file" {
  write_file "$TEST_HOME/elsewhere.zsh" "zstyle ':demo:from' elsewhere 'yes'"

  z1_zsh <<'EOS'
ZSTYLESFILE=$HOME/elsewhere.zsh
source $Z1
zstyle -t ':demo:from' elsewhere && print "sourced: yes" || print "sourced: no"
[[ -f $HOME/runs ]] && print "default: yes" || print "default: no"
EOS
  assert_success
  assert_line "sourced: yes"
  assert_line "default: no"
}

@test "a missing ZSTYLESFILE is not an error" {
  z1_zsh 'ZSTYLESFILE=$HOME/nope.zsh
    source $Z1
    print "rc: $?"'
  assert_success
  assert_line "rc: 0"
}
