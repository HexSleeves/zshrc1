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

@test "completion files are left for compinit" {
  write_file "$ZFUNCS/_mycmd" '#compdef mycmd'

  z1_zsh <<'EOS'
source $Z1
(( $+functions[_mycmd] )) && print "autoloaded: yes" || print "autoloaded: no"
EOS
  assert_success
  assert_line "autoloaded: no"
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
