#!/usr/bin/env bats
# cached-eval: run a command that prints Zsh code, keep the output, source it.
#
# Warm serves are proven with a counter file the fake command appends to, so a
# cache hit is "the counter did not move", not "the output looked the same".

load helpers/common

setup() { z1_setup; }
teardown() { z1_teardown; }

@test "caches a command's output and serves it warm" {
  z1_zsh <<'EOS'
source $Z1
gen() { print x >>! $HOME/runs; print 'V=hit' }
cached-eval gen
cached-eval gen
print "runs: $(wc -l <$HOME/runs | tr -d ' ')"
print "V: $V"
EOS
  assert_success
  assert_line "runs: 1"
  assert_line "V: hit"
}

@test "different arguments get their own cache" {
  z1_zsh <<'EOS'
source $Z1
cached-eval print 'A=one'
cached-eval print 'B=two'
files=($XDG_CACHE_HOME/zsh/cached-eval/*(N))
print "files: $#files"
print "A: $A"
print "B: $B"
EOS
  assert_success
  assert_line "files: 2"
  assert_line "A: one"
  assert_line "B: two"
}

@test "same-named commands in different directories do not collide" {
  write_file "$TEST_HOME/a/tool" '#!/bin/zsh' 'print WHICH=a'
  write_file "$TEST_HOME/b/tool" '#!/bin/zsh' 'print WHICH=b'
  chmod +x "$TEST_HOME/a/tool" "$TEST_HOME/b/tool"

  z1_zsh <<'EOS'
source $Z1
cached-eval $HOME/a/tool; print "first: $WHICH"
cached-eval $HOME/b/tool; print "second: $WHICH"
files=($XDG_CACHE_HOME/zsh/cached-eval/*(N))
print "files: $#files"
EOS
  assert_success
  assert_line "first: a"
  assert_line "second: b"
  assert_line "files: 2"
}

@test "the cache file is named after the command" {
  z1_zsh 'source $Z1
    cached-eval print "X=1"
    files=($XDG_CACHE_HOME/zsh/cached-eval/*(N:t))
    print "file: $files[1]"'
  assert_success
  assert_output_contains "file: print-"
}

@test "a failing command is an error and caches nothing" {
  z1_zsh 'source $Z1
    cached-eval false
    print "rc: $?"
    files=($XDG_CACHE_HOME/zsh/cached-eval/*(N))
    print "files: $#files"'
  assert_success
  refute_line "rc: 0"
  assert_line "files: 0"
}

@test "a stale cache is rebuilt" {
  z1_zsh <<'EOS'
source $Z1
gen() { print x >>! $HOME/runs; print 'V=fresh' }
cached-eval gen
touch -t 202001010000 $XDG_CACHE_HOME/zsh/cached-eval/gen-*(N)
cached-eval gen
print "runs: $(wc -l <$HOME/runs | tr -d ' ')"
EOS
  assert_success
  assert_line "runs: 2"
}

@test "--clear forgets one command without running it" {
  z1_zsh <<'EOS'
source $Z1
gen() { print x >>! $HOME/runs; print 'V=1' }
cached-eval gen
cached-eval print 'KEEP=1'
cached-eval --clear gen
print "runs: $(wc -l <$HOME/runs | tr -d ' ')"
files=($XDG_CACHE_HOME/zsh/cached-eval/*(N:t))
print "left: $files"
EOS
  assert_success
  assert_line "runs: 1"
  assert_output_contains "left: print-"
}

@test "a bare --clear forgets everything" {
  z1_zsh <<'EOS'
source $Z1
cached-eval print 'A=1'
cached-eval print 'B=2'
cached-eval --clear
print "rc: $?"
files=($XDG_CACHE_HOME/zsh/cached-eval/*(N))
print "files: $#files"
EOS
  assert_success
  assert_line "rc: 0"
  assert_line "files: 0"
}

@test "clearing a cache that was never written is not an error" {
  z1_zsh 'source $Z1
    cached-eval --clear never ran this
    print "one: $?"
    cached-eval --clear
    print "all: $?"'
  assert_success
  assert_line "one: 0"
  assert_line "all: 0"
}

@test "a command is required" {
  z1_zsh 'source $Z1; cached-eval; print "rc: $?"'
  assert_success
  assert_line "rc: 1"
}
