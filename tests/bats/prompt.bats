#!/usr/bin/env bats
# Prompts are made available to zsh's own prompt system through fpath. Starting
# that system is left to the user, so these tests run promptinit themselves.

load helpers/common

setup() { z1_setup; }
teardown() { z1_teardown; }

@test "the bundled z1 prompt is on fpath" {
  z1_zsh 'source $Z1
    autoload -Uz promptinit && promptinit
    print -l $prompt_themes | grep -qx z1 && print "z1: listed" || print "z1: missing"'
  assert_success
  assert_line "z1: listed"
}

@test "the bundled prompt actually loads" {
  z1_zsh 'source $Z1
    autoload -Uz promptinit && promptinit
    prompt z1
    print "rc: $?"
    print "precmd: $(( $precmd_functions[(I)prompt_z1_precmd] > 0 ))"
    [[ -n "$PROMPT" ]] && print "prompt: set" || print "prompt: empty"'
  assert_success
  assert_line "rc: 0"
  assert_line "precmd: 1"
  assert_line "prompt: set"
}

@test "your own prompts directory is picked up" {
  write_file "$TEST_HOME/.config/zsh/prompts/prompt_mine_setup" \
    'function prompt_mine_setup { PROMPT="mine> " }' \
    'prompt_mine_setup "$@"'

  z1_zsh 'source $Z1
    autoload -Uz promptinit && promptinit
    print -l $prompt_themes | grep -qx mine && print "mine: listed" || print "mine: missing"'
  assert_success
  assert_line "mine: listed"
}

# Your prompts come first, so a prompt of your own with the same name as one z1
# ships wins.
@test "your prompts directory wins over the bundled one" {
  write_file "$TEST_HOME/.config/zsh/prompts/prompt_z1_setup" \
    'function prompt_z1_setup { PROMPT="overridden> " }' \
    'prompt_z1_setup "$@"'

  z1_zsh 'source $Z1
    autoload -Uz promptinit && promptinit
    prompt z1
    print "PROMPT: $PROMPT"'
  assert_success
  assert_line "PROMPT: overridden> "
}

# $ZDOTDIR has no prompts directory here, so only z1's own is added.
@test "only prompt directories that exist are added" {
  z1_zsh 'source $Z1
    print "missing: $(print -l $fpath | grep -c "prompts")"'
  assert_success
  assert_line "missing: 1"
}

@test "a copy of z1.zsh with no prompts directory still loads" {
  cp "$PRJDIR/z1.zsh" "$TEST_HOME/solo.zsh"

  z1_zsh 'source $HOME/solo.zsh
    print "rc: $?"
    print "prompts in fpath: $(print -l $fpath | grep -c "prompts")"'
  assert_success
  assert_line "rc: 0"
  assert_line "prompts in fpath: 0"
}
