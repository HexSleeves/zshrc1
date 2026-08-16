#!/usr/bin/env bats
# zsh-patina syntax highlighting.

load helpers/common

setup() {
  z1_setup
  # Stands in for the real zsh-patina, so the suite never starts its daemon.
  stub_command zsh-patina 'print "typeset -g PATINA_ARGS=\"$*\""
    print "function zsh-patina() { : }"
    print -n x >>$HOME/patina-runs'
}
teardown() { z1_teardown; }

@test "z1 activates zsh-patina when it is installed" {
  z1_zsh 'source $Z1; print "args: $PATINA_ARGS"'
  assert_success
  assert_line "args: activate"
}

@test "activating defines the zsh-patina function" {
  z1_zsh 'source $Z1; print "fn: $+functions[zsh-patina]"'
  assert_success
  assert_line "fn: 1"
}

# Activating twice would stack patina's zle hooks.
@test "re-sourcing z1 does not activate zsh-patina twice" {
  z1_zsh 'source $Z1
    source $Z1
    print "runs: ${#$(<$HOME/patina-runs)}"'
  assert_success
  assert_line "runs: 1"
}

@test "an already activated zsh-patina is left alone" {
  z1_zsh 'function zsh-patina() { : }
    source $Z1
    print "args: ${PATINA_ARGS-unset}"'
  assert_success
  assert_line "args: unset"
}

@test "the skip zstyle leaves zsh-patina alone" {
  z1_zsh 'zstyle ":z1:patina" skip yes
    source $Z1
    print "args: ${PATINA_ARGS-unset}"'
  assert_success
  assert_line "args: unset"
}

@test "the skip pattern covering every z1 skip covers patina too" {
  z1_zsh 'zstyle ":z1:*" skip yes
    source $Z1
    print "args: ${PATINA_ARGS-unset}"'
  assert_success
  assert_line "args: unset"
}
