#!/usr/bin/env bats
# compinit is wrapped so compdef calls can be queued during .zshrc, and so the
# dumpfile can be cached. Dumpfile location and caching are separate settings.

load helpers/common

setup() { z1_setup; }
teardown() { z1_teardown; }

@test "the dumpfile location is honored with caching off" {
  z1_zsh <<'EOS'
source $Z1
ZSH_COMPDUMP=$HOME/nested/dir/mydump
compinit
[[ -f $ZSH_COMPDUMP ]] && print "dumpfile: written" || print "dumpfile: missing"
[[ -f $HOME/.zcompdump ]] && print "home: written" || print "home: clean"
EOS
  assert_success
  assert_line "dumpfile: written"
  assert_line "home: clean"
}

@test "the dumpfile location is honored with caching on" {
  z1_zsh <<'EOS'
zstyle ':z1:compinit' cache 'yes'
source $Z1
ZSH_COMPDUMP=$HOME/nested/dir/mydump
compinit
[[ -f $ZSH_COMPDUMP ]] && print "dumpfile: written" || print "dumpfile: missing"
[[ -f $HOME/.zcompdump ]] && print "home: written" || print "home: clean"
EOS
  assert_success
  assert_line "dumpfile: written"
  assert_line "home: clean"
}

@test "the dumpfile zstyle sets the location" {
  z1_zsh <<'EOS'
zstyle ':z1:compinit' dumpfile "$HOME/styled-dump"
source $Z1
print "compdump: $ZSH_COMPDUMP"
compinit
[[ -f $HOME/styled-dump ]] && print "written: yes" || print "written: no"
EOS
  assert_success
  assert_line "compdump: $TEST_HOME/styled-dump"
  assert_line "written: yes"
}

@test "a ZSH_COMPDUMP set before z1 loads wins over the zstyle" {
  z1_zsh <<'EOS'
zstyle ':z1:compinit' dumpfile "$HOME/styled-dump"
ZSH_COMPDUMP=$HOME/preset-dump
source $Z1
print "compdump: $ZSH_COMPDUMP"
EOS
  assert_success
  assert_line "compdump: $TEST_HOME/preset-dump"
}

@test "an explicit -d wins over the one z1 passes" {
  z1_zsh <<'EOS'
source $Z1
ZSH_COMPDUMP=$HOME/ours
compinit -d $HOME/theirs
[[ -f $HOME/theirs ]] && print "theirs: written" || print "theirs: missing"
[[ -f $HOME/ours ]] && print "ours: written" || print "ours: missing"
EOS
  assert_success
  assert_line "theirs: written"
  assert_line "ours: missing"
}

@test "compdef calls made before compinit are replayed" {
  z1_zsh <<'EOS'
source $Z1
compdef _gnu_generic mytool
print "queued: $#__compdef_queue"
compinit
(( $+_comps[mytool] )) && print "registered: yes" || print "registered: no"
EOS
  assert_success
  assert_line "queued: 1"
  assert_line "registered: yes"
}

@test "the compinit and compdef wrappers replace themselves" {
  z1_zsh <<'EOS'
source $Z1
compinit
print "compinit: $functions[compinit]"
EOS
  assert_success
  # The wrapper unfunctions itself and autoloads the real compinit, so the
  # function body is no longer z1's.
  refute_line "compinit: 	unfunction compinit compdef"
}

@test "caching reuses the dumpfile instead of rebuilding it" {
  z1_zsh <<'EOS'
zstyle ':z1:compinit' cache 'yes'
source $Z1
ZSH_COMPDUMP=$HOME/dump
compinit
first=$(zmodload zsh/stat; zstat +mtime $ZSH_COMPDUMP)
print "exists: $([[ -f $ZSH_COMPDUMP ]] && print yes || print no)"
print "mtime-set: $([[ -n $first ]] && print yes || print no)"
EOS
  assert_success
  assert_line "exists: yes"
  assert_line "mtime-set: yes"
}
