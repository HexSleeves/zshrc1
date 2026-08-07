#!/usr/bin/env bats
# prepath: the elements kept at the front of $path.

load helpers/common

setup() { z1_setup; }
teardown() { z1_teardown; }

@test "prepath gets defaults when nothing set it" {
  mkdir -p "$TEST_HOME/bin" "$TEST_HOME/.local/bin"

  z1_zsh <<'EOS'
source $Z1
print "prepath: $prepath"
EOS
  assert_success
  assert_output_contains "/bin"
  refute_line "prepath: "
}

@test "a preset prepath survives sourcing z1" {
  z1_zsh <<'EOS'
prepath=(/custom/bin)
source $Z1
print "prepath: $prepath"
print "path1: $path[1]"
EOS
  assert_success
  assert_line "prepath: /custom/bin"
  assert_line "path1: /custom/bin"
}

@test "re-sourcing z1 does not clobber prepath" {
  z1_zsh <<'EOS'
prepath=(/custom/bin)
source $Z1
source $Z1
print "prepath: $prepath"
EOS
  assert_success
  assert_line "prepath: /custom/bin"
}

@test "the prepath zstyle wins and expands tildes" {
  z1_zsh <<'EOS'
zstyle ':z1:path' prepath '~/zzz/bin' '/opt/mine/bin'
source $Z1
print "first: $prepath[1]"
print "second: $prepath[2]"
print "path1: $path[1]"
EOS
  assert_success
  assert_line "first: $TEST_HOME/zzz/bin"
  assert_line "second: /opt/mine/bin"
  assert_line "path1: $TEST_HOME/zzz/bin"
}

@test "repath puts prepath back at the front" {
  z1_zsh <<'EOS'
prepath=(/custom/bin)
source $Z1
path=(/somewhere/else $path)
print "before: $path[1]"
repath
print "after: $path[1]"
EOS
  assert_success
  assert_line "before: /somewhere/else"
  assert_line "after: /custom/bin"
}

@test "path arrays hold no duplicates" {
  z1_zsh <<'EOS'
source $Z1
integer before=$#path
path=($path $path)
print "grew: $(( $#path - before ))"
EOS
  assert_success
  assert_line "grew: 0"
}

# The three location vars. XDG by default, $ZDOTDIR when opted out, and a value
# you set yourself always wins.
@test "the location vars follow the XDG dirs by default" {
  z1_zsh 'source $Z1
    print "config: $ZSH_CONFIG_DIR"
    print "data: $ZSH_DATA_DIR"
    print "cache: $ZSH_CACHE_DIR"'
  assert_success
  assert_line "config: $TEST_HOME/.config/zsh"
  assert_line "data: $TEST_HOME/.local/share/zsh"
  assert_line "cache: $TEST_HOME/.cache/zsh"
}

@test "opting out of the XDG dirs puts everything under ZDOTDIR" {
  z1_zsh 'zstyle ":z1:xdg-basedirs" enable no
    source $Z1
    print "config: $ZSH_CONFIG_DIR"
    print "data: $ZSH_DATA_DIR"
    print "cache: $ZSH_CACHE_DIR"'
  assert_success
  assert_line "config: $TEST_HOME/.config/zsh"
  assert_line "data: $TEST_HOME/.config/zsh"
  assert_line "cache: $TEST_HOME/.config/zsh"
}

@test "opting out without a ZDOTDIR lands in HOME" {
  z1_zsh 'ZDOTDIR=
    zstyle ":z1:xdg-basedirs" enable no
    source $Z1
    print "config: $ZSH_CONFIG_DIR"
    print "data: $ZSH_DATA_DIR"
    print "cache: $ZSH_CACHE_DIR"'
  assert_success
  assert_line "config: $TEST_HOME"
  assert_line "data: $TEST_HOME"
  assert_line "cache: $TEST_HOME"
}

@test "a preset location var wins over the XDG default" {
  z1_zsh 'ZSH_CACHE_DIR=$HOME/mycache
    source $Z1
    print "config: $ZSH_CONFIG_DIR"
    print "cache: $ZSH_CACHE_DIR"'
  assert_success
  assert_line "config: $TEST_HOME/.config/zsh"
  assert_line "cache: $TEST_HOME/mycache"
}

@test "a preset location var wins when opted out too" {
  z1_zsh 'ZSH_DATA_DIR=$HOME/mydata
    zstyle ":z1:xdg-basedirs" enable no
    source $Z1
    print "data: $ZSH_DATA_DIR"
    print "cache: $ZSH_CACHE_DIR"'
  assert_success
  assert_line "data: $TEST_HOME/mydata"
  assert_line "cache: $TEST_HOME/.config/zsh"
}

@test "an explicit yes keeps the XDG dirs" {
  z1_zsh 'zstyle ":z1:xdg-basedirs" enable yes
    source $Z1
    print "data: $ZSH_DATA_DIR"'
  assert_success
  assert_line "data: $TEST_HOME/.local/share/zsh"
}

# .zstyles loads before the location vars are set, so this style works from
# there rather than having to go in .zshrc.
@test "the xdg-basedirs style works from .zstyles" {
  write_file "$TEST_HOME/.config/zsh/.zstyles" \
    "zstyle ':z1:xdg-basedirs' enable 'no'"

  z1_zsh 'source $Z1
    print "config: $ZSH_CONFIG_DIR"
    print "data: $ZSH_DATA_DIR"'
  assert_success
  assert_line "config: $TEST_HOME/.config/zsh"
  assert_line "data: $TEST_HOME/.config/zsh"
}
