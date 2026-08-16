#!/usr/bin/env bats
# Where z1 looks for its libraries: your lib/ first, then the one z1 ships.

load helpers/common

setup() { z1_setup; }
teardown() { z1_teardown; }

@test "z1 loads the autosuggest library it ships with" {
  z1_zsh 'source $Z1; print "fetch: $+functions[autosuggest-fetch]"'
  assert_success
  assert_line "fetch: 1"
}

@test "an autosuggest library in your lib wins" {
  write_file "$TEST_HOME/.config/zsh/lib/z1_autosuggest.zsh" 'typeset -g MINE=1'
  z1_zsh 'source $Z1
    print "mine: $MINE"
    print "fetch: $+functions[autosuggest-fetch]"'
  assert_success
  assert_line "mine: 1"
  assert_line "fetch: 0"
}

@test "the skip zstyle loads neither autosuggest library" {
  write_file "$TEST_HOME/.config/zsh/lib/z1_autosuggest.zsh" 'typeset -g MINE=1'
  z1_zsh 'zstyle ":z1:autosuggest" skip yes
    source $Z1
    print "mine: ${MINE-unset}"
    print "fetch: $+functions[autosuggest-fetch]"'
  assert_success
  assert_line "mine: unset"
  assert_line "fetch: 0"
}

@test "an async library in your lib wins for the prompt" {
  write_file "$TEST_HOME/.config/zsh/lib/z1_async.zsh" 'typeset -g MINE=1'
  z1_zsh 'source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    print "mine: $MINE"
    print "async: $+functions[async-task]"'
  assert_success
  assert_line "mine: 1"
  assert_line "async: 0"
}
