#!/usr/bin/env bats
# ZFUNCDIR: autoloaded function files, from the directory and its subdirs.

load helpers/common

setup() {
  z1_setup
  ZFUNCS="$TEST_HOME/.config/zsh/functions"
  write_file "$ZFUNCS/greet" 'print "greet: hi"'
  write_file "$ZFUNCS/nested/wave" 'print "wave: hi"'
}
teardown() { z1_teardown; }

@test "functions in ZFUNCDIR and its subdirs autoload" {
  z1_zsh <<'EOS'
source $Z1
greet
wave
EOS
  assert_success
  assert_line "greet: hi"
  assert_line "wave: hi"
}

@test "ZFUNCDIR and its subdirs go on fpath" {
  z1_zsh <<'EOS'
source $Z1
(( $fpath[(I)$ZDOTDIR/functions] )) && print "top: yes" || print "top: no"
(( $fpath[(I)$ZDOTDIR/functions/nested] )) && print "sub: yes" || print "sub: no"
EOS
  assert_success
  assert_line "top: yes"
  assert_line "sub: yes"
}

@test "functions nested more than one level deep autoload" {
  write_file "$ZFUNCS/deep/deeper/deepfn" 'print "deepfn: hi"'

  z1_zsh <<'EOS'
source $Z1
deepfn
(( $fpath[(I)$ZDOTDIR/functions/deep/deeper] )) && print "fpath: yes" || print "fpath: no"
EOS
  assert_success
  assert_line "deepfn: hi"
  assert_line "fpath: yes"
}

@test "a subdirectory holding only subdirectories is quiet" {
  write_file "$ZFUNCS/dirsonly/deeper/deepfn" 'print "deepfn: hi"'

  z1_zsh <<'EOS'
source $Z1
print "done"
EOS
  assert_success
  assert_line "done"
  # A bare `autoload` lists every pending autoload instead of loading anything.
  refute_output_matches 'builtin autoload'
}

@test "a symlinked ZFUNCDIR autoloads" {
  write_file "$TEST_HOME/elsewhere/linkfn" 'print "linkfn: hi"'
  rm -rf "$ZFUNCS"
  ln -s "$TEST_HOME/elsewhere" "$ZFUNCS"

  z1_zsh <<'EOS'
source $Z1
linkfn
EOS
  assert_success
  assert_line "linkfn: hi"
}

@test "a symlinked subdirectory autoloads, at any depth" {
  write_file "$TEST_HOME/elsewhere/linkfn" 'print "linkfn: hi"'
  write_file "$TEST_HOME/elsewhere/under/deepfn" 'print "deepfn: hi"'
  ln -s "$TEST_HOME/elsewhere" "$ZFUNCS/linked"

  z1_zsh <<'EOS'
source $Z1
linkfn
deepfn
EOS
  assert_success
  assert_line "linkfn: hi"
  assert_line "deepfn: hi"
}

@test "a symlinked function file autoloads" {
  write_file "$TEST_HOME/elsewhere/linkfn" 'print "linkfn: hi"'
  ln -s "$TEST_HOME/elsewhere/linkfn" "$ZFUNCS/linkfn"

  z1_zsh <<'EOS'
source $Z1
linkfn
EOS
  assert_success
  assert_line "linkfn: hi"
}

@test "completion files are left for compinit" {
  write_file "$ZFUNCS/_mycmd" '#compdef mycmd'

  z1_zsh <<'EOS'
source $Z1
(( $+functions[_mycmd] )) && print "autoloaded: yes" || print "autoloaded: no"
EOS
  assert_success
  assert_line "autoloaded: no"
}

@test "completion files in a subdirectory are left for compinit" {
  write_file "$ZFUNCS/nested/_subcmd" '#compdef subcmd'

  z1_zsh <<'EOS'
source $Z1
(( $+functions[_subcmd] )) && print "autoloaded: yes" || print "autoloaded: no"
EOS
  assert_success
  assert_line "autoloaded: no"
}

@test "a subdirectory holding only completion files is quiet" {
  write_file "$ZFUNCS/comps/_onlycmd" '#compdef onlycmd'

  z1_zsh <<'EOS'
source $Z1
print "done"
EOS
  assert_success
  assert_line "done"
  refute_output_matches 'builtin autoload'
}

@test "an empty ZFUNCDIR is not an error" {
  rm -rf "$ZFUNCS"
  mkdir -p "$ZFUNCS"

  z1_zsh <<'EOS'
source $Z1
print "rc: $?"
EOS
  assert_success
  assert_line "rc: 0"
}

@test "a dangling symlink is skipped" {
  ln -s "$TEST_HOME/gone" "$ZFUNCS/ghost"

  z1_zsh <<'EOS'
source $Z1
print "rc: $?"
(( $+functions[ghost] )) && print "autoloaded: yes" || print "autoloaded: no"
greet
EOS
  assert_success
  assert_line "rc: 0"
  assert_line "autoloaded: no"
  assert_line "greet: hi"
}

@test "a ZFUNCDIR set beforehand wins" {
  write_file "$TEST_HOME/myfuncs/customfn" 'print "customfn: hi"'

  z1_zsh <<'EOS'
export ZFUNCDIR=$HOME/myfuncs
source $Z1
customfn
(( $+functions[greet] )) && print "default: yes" || print "default: no"
EOS
  assert_success
  assert_line "customfn: hi"
  assert_line "default: no"
}

@test "the skip zstyle leaves functions alone" {
  z1_zsh <<'EOS'
zstyle ':z1:zfunctions' skip 'yes'
source $Z1
(( $+functions[greet] )) && print "autoloaded: yes" || print "autoloaded: no"
(( $fpath[(I)$ZDOTDIR/functions] )) && print "fpath: yes" || print "fpath: no"
EOS
  assert_success
  assert_line "autoloaded: no"
  assert_line "fpath: no"
}

@test "a missing ZFUNCDIR is not an error" {
  rm -rf "$ZFUNCS"

  z1_zsh <<'EOS'
source $Z1
print "rc: $?"
EOS
  assert_success
  assert_line "rc: 0"
}
