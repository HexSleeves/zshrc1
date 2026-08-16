#!/usr/bin/env bats
# Fish-style directory history: prevd, nextd, and the widgets on Alt-arrows.

load helpers/common

setup() { z1_setup; }
teardown() { z1_teardown; }

# The dirstack only fills when cd pushes to it, so every body below cds first.

@test "prevd goes back to the previous directory" {
  z1_zsh 'source $Z1
    mkdir -p $HOME/a/b
    cd $HOME/a
    cd $HOME/a/b
    prevd
    print "pwd: ${PWD:t}"'
  assert_success
  assert_line "pwd: a"
}

@test "nextd goes forward again" {
  z1_zsh 'source $Z1
    mkdir -p $HOME/a/b
    cd $HOME/a
    cd $HOME/a/b
    prevd
    nextd
    print "pwd: ${PWD:t}"'
  assert_success
  assert_line "pwd: b"
}

@test "prevd takes a count" {
  z1_zsh 'source $Z1
    mkdir -p $HOME/a/b/c
    cd $HOME/a
    cd $HOME/a/b
    cd $HOME/a/b/c
    prevd 2
    print "pwd: ${PWD:t}"'
  assert_success
  assert_line "pwd: a"
}

@test "nextd takes a count" {
  z1_zsh 'source $Z1
    mkdir -p $HOME/a/b/c
    cd $HOME/a
    cd $HOME/a/b
    cd $HOME/a/b/c
    prevd 2
    nextd 2
    print "pwd: ${PWD:t}"'
  assert_success
  assert_line "pwd: c"
}

# The dirstack is a ring, so walking off the end comes back around rather than
# stopping. Three directories plus the one z1 started in makes four.
@test "walking past the oldest entry wraps around" {
  z1_zsh 'source $Z1
    mkdir -p $HOME/a/b
    cd $HOME/a
    cd $HOME/a/b
    prevd 3
    print "pwd: ${PWD:t}"'
  assert_success
  assert_line "pwd: b"
}

@test "prevd with an empty dirstack fails" {
  z1_zsh 'source $Z1
    prevd 2>/dev/null
    print "status: $?"'
  assert_success
  assert_line "status: 1"
}

@test "the skip zstyle leaves prevd and nextd undefined" {
  z1_zsh 'zstyle ":z1:dirhistory" skip yes
    source $Z1
    print "prevd: $+functions[prevd]"
    print "nextd: $+functions[nextd]"'
  assert_success
  assert_line "prevd: 0"
  assert_line "nextd: 0"
}

@test "Alt-Left and Alt-Right walk the directory history" {
  z1_zsh 'source $Z1; bindkey "^[[1;3D"; bindkey "^[[1;3C"'
  assert_success
  assert_line '"^[[1;3D" prevd-or-backward-word'
  assert_line '"^[[1;3C" nextd-or-forward-word'
}

@test "Ctrl-Left and Ctrl-Right still move by word" {
  z1_zsh 'source $Z1; bindkey "^[[1;5D"; bindkey "^[[1;5C"'
  assert_success
  assert_line '"^[[1;5D" backward-word'
  assert_line '"^[[1;5C" forward-word'
}

@test "Alt-Left and Alt-Right change directory on an empty line" {
  z1_zle 'enter "mkdir -p \$HOME/a/b"
    enter "cd \$HOME/a"
    enter "cd \$HOME/a/b"
    press $'"'"'\e[1;3D'"'"'
    probe-pwd
    press $'"'"'\e[1;3C'"'"'
    probe-pwd'
  assert_success
  assert_line "5: PWD=a"
  assert_line "7: PWD=b"
}

@test "Alt-Left moves by word on a line with text" {
  z1_zle 'type-keys "echo one two"
    press $'"'"'\e[1;3D'"'"''
  assert_success
  assert_output_contains "BUF=[echo one two] CUR=9"
}

@test "Alt-Left falls back to word movement when skipped" {
  z1_zsh 'zstyle ":z1:dirhistory" skip yes
    source $Z1
    bindkey "^[[1;3D"
    bindkey "^[[1;3C"'
  assert_success
  assert_line '"^[[1;3D" backward-word'
  assert_line '"^[[1;3C" forward-word'
}
