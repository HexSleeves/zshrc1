#!/usr/bin/env bats
# Color aliases are built on top of whatever the user already set.

load helpers/common

setup() { z1_setup; }
teardown() { z1_teardown; }

@test "color aliases compose onto an existing alias" {
  stub_command dircolors 'print "export LS_COLORS=di=34:"'
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
  stub_command dircolors 'print "export LS_COLORS=di=34:"'
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
  stub_command dircolors 'print "export LS_COLORS=di=34:"'
  z1_zsh <<'EOS'
alias ls='eza --color=always'
source $Z1
print "ls: $aliases[ls]"
EOS
  assert_success
  assert_line "ls: eza --color=always"
}

@test "grep gets a plain color alias" {
  z1_zsh 'source $Z1; print "grep: $aliases[grep]"'
  assert_success
  assert_line "grep: grep --color=auto"
}

# GNU ls colorizes with --color, BSD ls with -G. dircolors ships with GNU
# coreutils, so its presence stands in for "this is GNU" without a probe. Both
# branches are forced here, so the assertions hold on whichever platform runs
# the tests.
@test "ls gets --color=auto where dircolors exists" {
  stub_command dircolors 'print "export LS_COLORS=di=34:"'
  z1_zsh 'source $Z1; print "ls: $aliases[ls]"'
  assert_success
  assert_line "ls: ls --color=auto"
}

@test "ls gets -G where dircolors does not exist" {
  # A PATH holding only what z1 needs to start, so dircolors cannot be found
  # even on a distro that ships it.
  local cmd
  for cmd in zsh mkdir; do
    ln -s "$(command -v $cmd)" "$TEST_HOME/bin/$cmd"
  done
  Z1_TEST_PATH="$TEST_HOME/bin" z1_zsh 'source $Z1
    (( $+commands[dircolors] )) && print "dircolors: yes" || print "dircolors: no"
    print "ls: $aliases[ls]"'
  assert_success
  assert_line "dircolors: no"
  assert_line "ls: ls -G"
}

# -G is meaningless to a replacement, but --color=auto is not, so the BSD
# branch picks by the command the alias actually runs.
@test "an ls replacement gets --color=auto where dircolors does not exist" {
  local cmd
  for cmd in zsh mkdir; do
    ln -s "$(command -v $cmd)" "$TEST_HOME/bin/$cmd"
  done
  Z1_TEST_PATH="$TEST_HOME/bin" z1_zsh 'alias ls=eza; source $Z1; print "ls: $aliases[ls]"'
  assert_success
  assert_line "ls: eza --color=auto"
}

@test "an ls alias that still runs ls gets -G" {
  local cmd
  for cmd in zsh mkdir; do
    ln -s "$(command -v $cmd)" "$TEST_HOME/bin/$cmd"
  done
  Z1_TEST_PATH="$TEST_HOME/bin" z1_zsh 'alias ls="ls -l"; source $Z1; print "ls: $aliases[ls]"'
  assert_success
  assert_line "ls: ls -l -G"
}

@test "an existing color choice survives the BSD branch too" {
  local cmd
  for cmd in zsh mkdir; do
    ln -s "$(command -v $cmd)" "$TEST_HOME/bin/$cmd"
  done
  Z1_TEST_PATH="$TEST_HOME/bin" z1_zsh 'alias ls="ls --color=always"; source $Z1; print "ls: $aliases[ls]"'
  assert_success
  assert_line "ls: ls --color=always"
}

@test "an ls replacement still gets the flag appended" {
  stub_command dircolors 'print "export LS_COLORS=di=34:"'
  z1_zsh 'alias ls=eza; source $Z1; print "ls: $aliases[ls]"'
  assert_success
  assert_line "ls: eza --color=auto"
}

@test "LS_COLORS gets a default when nothing else set one" {
  z1_zsh <<'EOS'
source $Z1
[[ -n "$LS_COLORS" ]] && print "ls_colors: set" || print "ls_colors: empty"
EOS
  assert_success
  assert_line "ls_colors: set"
}
