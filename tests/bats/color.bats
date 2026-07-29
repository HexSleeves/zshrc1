#!/usr/bin/env bats
# Color aliases are built on top of whatever the user already set.

load helpers/common

setup() { z1_setup; }
teardown() { z1_teardown; }

@test "color aliases compose onto an existing alias" {
  z1_zsh <<'EOS'
alias ls='eza'
alias grep='rg'
source $Z1
print "ls: $aliases[ls]"
print "grep: $aliases[grep]"
EOS
  assert_success
  assert_line "ls: eza --color=auto"
  assert_line "grep: rg --color=auto"
}

@test "sourcing z1 twice does not append --color twice" {
  z1_zsh <<'EOS'
alias ls='eza'
source $Z1
source $Z1
print "ls: $aliases[ls]"
EOS
  assert_success
  assert_line "ls: eza --color=auto"
}

@test "an existing color choice is left alone" {
  z1_zsh <<'EOS'
alias ls='eza --color=always'
source $Z1
print "ls: $aliases[ls]"
EOS
  assert_success
  assert_line "ls: eza --color=always"
}

@test "plain commands get a plain color alias" {
  z1_zsh <<'EOS'
source $Z1
print "ls: $aliases[ls]"
print "grep: $aliases[grep]"
EOS
  assert_success
  assert_line "ls: ls --color=auto"
  assert_line "grep: grep --color=auto"
}

@test "diff is only aliased when it supports --color" {
  z1_zsh <<'EOS'
source $Z1
if command diff --color /dev/null{,} &>/dev/null; then
  print "supported: yes"
  print "alias: $aliases[diff]"
else
  print "supported: no"
  (( $+aliases[diff] )) && print "alias: set" || print "alias: unset"
fi
EOS
  assert_success
  if [[ "$output" == *"supported: yes"* ]]; then
    assert_line "alias: diff --color"
  else
    assert_line "alias: unset"
  fi
}

@test "LS_COLORS gets a default when nothing else set one" {
  z1_zsh <<'EOS'
source $Z1
[[ -n "$LS_COLORS" ]] && print "ls_colors: set" || print "ls_colors: empty"
EOS
  assert_success
  assert_line "ls_colors: set"
}
