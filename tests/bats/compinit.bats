#!/usr/bin/env bats
# compinit is wrapped so compdef calls can be queued during .zshrc, and so the
# dumpfile can be cached. Dumpfile location and caching are separate settings.

load helpers/common

setup() {
  z1_setup
  CONFD="$TEST_HOME/.config/zsh/conf.d"
}
teardown() { z1_teardown; }

# Completions are dead until compinit runs, and the queued compdef calls never
# replay. Rather than leave that to every user's .zshrc, run it on post_zshrc.
@test "post_zshrc runs compinit when the .zshrc did not" {
  z1_zsh <<'EOS'
source $Z1
compdef _gnu_generic mytool
print "early: $#_comps"
run_post_zshrc
(( $#_comps )) && print "after: loaded" || print "after: empty"
(( $+_comps[mytool] )) && print "queued: replayed" || print "queued: dropped"
EOS
  assert_success
  assert_line "early: 0"
  assert_line "after: loaded"
  assert_line "queued: replayed"
}

# Emptying _comps after the manual call makes a second run visible: only a
# rerun would refill it.
@test "post_zshrc leaves a compinit the .zshrc already ran alone" {
  z1_zsh <<'EOS'
source $Z1
compinit
_comps=()
run_post_zshrc
(( $#_comps )) && print "rerun: yes" || print "rerun: no"
EOS
  assert_success
  assert_line "rerun: no"
}

# conf.d gets to add to fpath, so compinit has to come after it.
@test "compinit picks up a completion conf.d added to fpath" {
  write_file "$CONFD/10-fpath.zsh" 'fpath=($HOME/zextra $fpath)'
  write_file "$TEST_HOME/zextra/_mytool" '#compdef mytool' '_message x'

  z1_zsh <<'EOS'
source $Z1
run_post_zshrc
(( $+_comps[mytool] )) && print "completion: yes" || print "completion: no"
EOS
  assert_success
  assert_line "completion: yes"
}

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

# Skipping hands completion back whole: no wrappers over compinit or compdef,
# and nothing queued on post_zshrc.
@test "the skip zstyle installs no wrappers and no hook" {
  z1_zsh <<'EOS'
zstyle ':z1:compinit' skip 'yes'
source $Z1
(( $+functions[compinit] )) && print "compinit: wrapped" || print "compinit: free"
(( $+functions[compdef] )) && print "compdef: wrapped" || print "compdef: free"
(( $post_zshrc_hook[(I)compinit] )) && print "hook: yes" || print "hook: no"
run_post_zshrc
(( $#_comps )) && print "comps: loaded" || print "comps: empty"
EOS
  assert_success
  assert_line "compinit: free"
  assert_line "compdef: free"
  assert_line "hook: no"
  assert_line "comps: empty"
}

@test "the real compinit still works when z1 skips it" {
  z1_zsh <<'EOS'
zstyle ':z1:compinit' skip 'yes'
source $Z1
autoload -Uz compinit && compinit -i -d $ZSH_COMPDUMP
(( $#_comps )) && print "comps: loaded" || print "comps: empty"
print "dumpfile: ${ZSH_COMPDUMP:t}"
EOS
  assert_success
  assert_line "comps: loaded"
  assert_output_contains "dumpfile: ZSH_COMPDUMP-"
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

# FPATH is exported, so a nested shell starts with the parent's fpath and z1
# appends to it. Directories that no longer exist and entries that arrive twice
# say nothing about what the dumpfile holds, so the stamp ignores both.
@test "a missing fpath directory does not defeat the cache" {
  z1_zsh 'zstyle ":z1:compinit" cache yes
    source $Z1; ZSH_COMPDUMP=$HOME/dump; compinit'
  assert_success

  printf 'print "cache hit"\n' >>"$TEST_HOME/dump"
  rm -f "$TEST_HOME/dump.zwc"

  z1_zsh 'zstyle ":z1:compinit" cache yes
    source $Z1; ZSH_COMPDUMP=$HOME/dump
    fpath=($HOME/gone $fpath)
    compinit'
  assert_success
  assert_line "cache hit"
}

@test "a duplicated fpath entry does not defeat the cache" {
  z1_zsh 'zstyle ":z1:compinit" cache yes
    source $Z1; ZSH_COMPDUMP=$HOME/dump; compinit'
  assert_success

  printf 'print "cache hit"\n' >>"$TEST_HOME/dump"
  rm -f "$TEST_HOME/dump.zwc"

  z1_zsh 'zstyle ":z1:compinit" cache yes
    source $Z1; ZSH_COMPDUMP=$HOME/dump
    fpath=($fpath $fpath)
    compinit'
  assert_success
  assert_line "cache hit"
}

# Order decides which directory wins when two ship the same completion, so a
# reordered fpath is a real change and has to rebuild.
@test "a reordered fpath rebuilds the dumpfile" {
  z1_zsh 'zstyle ":z1:compinit" cache yes
    source $Z1; ZSH_COMPDUMP=$HOME/dump; compinit'
  assert_success

  printf 'print "cache hit"\n' >>"$TEST_HOME/dump"
  rm -f "$TEST_HOME/dump.zwc"

  z1_zsh 'zstyle ":z1:compinit" cache yes
    source $Z1; ZSH_COMPDUMP=$HOME/dump
    fpath=(${(Oa)fpath})
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

# Compstyles. The completion cache lives beside the dumpfile and is versioned
# the same way, since both formats are tied to the zsh release.
@test "the completion cache is on and versioned" {
  z1_zsh 'source $Z1
    zstyle -s ":completion:*" use-cache use
    zstyle -s ":completion:*" cache-path cpath
    print "use: $use"
    print "path: ${cpath/$ZSH_CACHE_DIR/CACHE}"'
  assert_success
  assert_line "use: true"
  assert_line "path: CACHE/zcompcache-$(zsh -c 'print $ZSH_VERSION')"
}

@test "rm, kill, and diff skip what is already on the line" {
  z1_zsh 'source $Z1
    for c in rm kill diff cp; do
      zstyle -s ":completion:*:$c:*" ignore-line ig
      print "$c: [$ig]"
    done'
  assert_success
  assert_line "rm: [other]"
  assert_line "kill: [other]"
  assert_line "diff: [other]"
  assert_line "cp: []"
}

# Ignored is not gone: _ignored runs after _complete, so a hidden name comes
# back on the next try rather than being unreachable.
@test "underscore internals are deprioritized, not hidden outright" {
  z1_zsh 'source $Z1
    zstyle -s ":completion:*:functions" ignored-patterns fn
    zstyle -a ":completion:*" completer c
    print "functions: $fn"
    print "completer: $c"'
  assert_success
  assert_line "functions: -*|_*"
  assert_line "completer: _complete _ignored _match _approximate"
}
