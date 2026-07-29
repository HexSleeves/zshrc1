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

# A dumpfile built from one fpath is missing whatever a new entry provides, and
# the age check alone would hide that for 20 hours. The sentinel proves a warm
# serve: text appended to the dumpfile only prints if that file is what ran.
# The .zwc has to go with it, or zsh serves the compiled copy instead.
@test "an unchanged fpath serves the dumpfile warm" {
  z1_zsh 'zstyle ":z1:compinit" cache yes
    source $Z1; ZSH_COMPDUMP=$HOME/dump; compinit'
  assert_success

  printf 'print "cache hit"\n' >>"$TEST_HOME/dump"
  rm -f "$TEST_HOME/dump.zwc"

  z1_zsh 'zstyle ":z1:compinit" cache yes
    source $Z1; ZSH_COMPDUMP=$HOME/dump; compinit'
  assert_success
  assert_line "cache hit"
}

@test "a changed fpath rebuilds the dumpfile" {
  z1_zsh 'zstyle ":z1:compinit" cache yes
    source $Z1; ZSH_COMPDUMP=$HOME/dump; compinit'
  assert_success

  printf 'print "cache hit"\n' >>"$TEST_HOME/dump"
  rm -f "$TEST_HOME/dump.zwc"
  mkdir -p "$TEST_HOME/zextra"

  z1_zsh 'zstyle ":z1:compinit" cache yes
    source $Z1; ZSH_COMPDUMP=$HOME/dump
    fpath=($HOME/zextra $fpath)
    compinit'
  assert_success
  refute_line "cache hit"
}

@test "a completion added to fpath shows up despite a fresh cache" {
  write_file "$TEST_HOME/zextra/_mytool" '#compdef mytool' '_message x'

  z1_zsh 'zstyle ":z1:compinit" cache yes
    source $Z1; ZSH_COMPDUMP=$HOME/dump; compinit
    (( $+_comps[mytool] )) && print "completion: yes" || print "completion: no"'
  assert_success
  assert_line "completion: no"

  z1_zsh 'zstyle ":z1:compinit" cache yes
    source $Z1; ZSH_COMPDUMP=$HOME/dump
    fpath=($HOME/zextra $fpath)
    compinit
    (( $+_comps[mytool] )) && print "completion: yes" || print "completion: no"'
  assert_success
  assert_line "completion: yes"
}

# Without -i, compinit stops to ask about insecure directories, which a shell
# with no terminal cannot answer. z1 ignores them and says so afterwards.
@test "insecure completion directories do not block startup" {
  mkdir -p "$TEST_HOME/insecure"
  chmod 777 "$TEST_HOME/insecure"

  z1_zsh 'source $Z1
    fpath=($HOME/insecure $fpath)
    ZSH_COMPDUMP=$HOME/dump
    compinit
    [[ -f $ZSH_COMPDUMP ]] && print "dumpfile: written" || print "dumpfile: missing"'
  assert_success
  assert_line "dumpfile: written"
  refute_line "compinit: initialization aborted"
}

@test "insecure completion directories are reported" {
  mkdir -p "$TEST_HOME/insecure"
  chmod 777 "$TEST_HOME/insecure"

  z1_zsh 'source $Z1
    fpath=($HOME/insecure $fpath)
    z1-compaudit-warn'
  assert_success
  assert_output_contains "z1: ignoring insecure completion directories:"
  assert_output_contains "/insecure"
  assert_output_contains "compaudit | xargs chmod g-w,o-w"
}

@test "nothing is reported when every completion directory is secure" {
  z1_zsh 'source $Z1
    fpath=($ZDOTDIR/completions)
    z1-compaudit-warn
    print "done: $?"'
  assert_success
  assert_line "done: 0"
  refute_line "z1: ignoring insecure completion directories:"
}

# compinit -i drops insecure directories from fpath. Stamping after that call
# records something the next startup never matches, so the cache rebuilds every
# time. Ubuntu ships a group-writable /usr/share/zsh, so this is the default
# state on a stock box, not a corner case.
@test "an insecure directory in fpath does not defeat the cache" {
  mkdir -p "$TEST_HOME/insecure"
  chmod 777 "$TEST_HOME/insecure"

  z1_zsh 'zstyle ":z1:compinit" cache yes
    source $Z1
    fpath=($HOME/insecure $fpath)
    ZSH_COMPDUMP=$HOME/dump
    compinit
    print "fpath after: $#fpath"'
  assert_success

  printf 'print "cache hit"\n' >>"$TEST_HOME/dump"
  rm -f "$TEST_HOME/dump.zwc"

  z1_zsh 'zstyle ":z1:compinit" cache yes
    source $Z1
    fpath=($HOME/insecure $fpath)
    ZSH_COMPDUMP=$HOME/dump
    compinit'
  assert_success
  assert_line "cache hit"
}
