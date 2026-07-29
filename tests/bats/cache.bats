#!/usr/bin/env bats
# Every cache z1 has is opt-in behind one `cache` style, so a single pattern can
# turn them all on. Stubs live in $HOME/bin, which z1's prepath puts ahead of a
# real brew or dircolors.

load helpers/common

setup() {
  z1_setup
  stub_command brew 'print x >>$HOME/brew-runs; print "export Z1_BREW_RAN=yes"'
  stub_command dircolors 'print x >>$HOME/dircolors-runs; print "export LS_COLORS=di=34:"'
}
teardown() { z1_teardown; }

@test "caching is off by default" {
  z1_zsh 'source $Z1; source $Z1; print "runs: $(wc -l <$HOME/brew-runs | tr -d " ")"'
  assert_success
  assert_line "runs: 2"
}

@test "the homebrew cache style enables it" {
  z1_zsh 'zstyle ":z1:homebrew" cache yes
    source $Z1; source $Z1; source $Z1
    print "runs: $(wc -l <$HOME/brew-runs | tr -d " ")"
    print "env: $Z1_BREW_RAN"'
  assert_success
  assert_line "runs: 1"
  assert_line "env: yes"
}

@test "the color cache style enables it" {
  z1_zsh 'zstyle ":z1:color" cache yes
    source $Z1; source $Z1
    print "runs: $(wc -l <$HOME/dircolors-runs | tr -d " ")"'
  assert_success
  assert_line "runs: 1"
}

@test "one pattern turns on every cache" {
  z1_zsh 'zstyle ":z1:*" cache yes
    source $Z1; source $Z1
    print "brew: $(wc -l <$HOME/brew-runs | tr -d " ")"
    print "dircolors: $(wc -l <$HOME/dircolors-runs | tr -d " ")"'
  assert_success
  assert_line "brew: 1"
  assert_line "dircolors: 1"
}

@test "a specific style still beats the pattern" {
  z1_zsh 'zstyle ":z1:*" cache yes
    zstyle ":z1:homebrew" cache no
    source $Z1; source $Z1
    print "brew: $(wc -l <$HOME/brew-runs | tr -d " ")"
    print "dircolors: $(wc -l <$HOME/dircolors-runs | tr -d " ")"'
  assert_success
  assert_line "brew: 2"
  assert_line "dircolors: 1"
}

@test "the pattern reaches compinit too" {
  z1_zsh <<'EOS'
zstyle ':z1:*' cache yes
source $Z1
ZSH_COMPDUMP=$HOME/dump
compinit
[[ -f $ZSH_COMPDUMP ]] && print "dumpfile: written" || print "dumpfile: missing"
EOS
  assert_success
  assert_line "dumpfile: written"
}

@test "an uncached run still applies what the command printed" {
  z1_zsh 'source $Z1; print "env: $Z1_BREW_RAN"'
  assert_success
  assert_line "env: yes"
}
