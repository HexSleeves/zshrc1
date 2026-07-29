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

# The prompt character is chosen while PROMPT is expanded, so these set $KEYMAP
# and expand it by hand, the way `zle reset-prompt` would.
@test "vi command mode gets its own prompt character" {
  z1_zsh 'source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    for k in main viins vicmd emacs; do
      KEYMAP=$k; print -r -- "$k: ${(e)PROMPT}"
    done'
  assert_success
  assert_output_contains "main: %F{039}%f %F{076}❱%f"
  assert_output_contains "viins: %F{039}%f %F{076}❱%f"
  assert_output_contains "vicmd: %F{039}%f %F{076}❰%f"
  assert_output_contains "emacs: %F{039}%f %F{076}❱%f"
}

# zle also reports isearch and listscroll. Looking the keymap up in the
# character table means an unnamed one falls back rather than printing itself.
@test "an unrecognized keymap falls back to the success character" {
  z1_zsh 'source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    for k in isearch listscroll nonsense ""; do
      KEYMAP=$k; print -r -- "[$k] ${(e)PROMPT}"
    done
    unset KEYMAP; print -r -- "[unset] ${(e)PROMPT}"'
  assert_success
  refute_line "[isearch] %F{039}%f %F{076}isearch%f "
  assert_output_contains "[isearch] %F{039}%f %F{076}❱%f"
  assert_output_contains "[listscroll] %F{039}%f %F{076}❱%f"
  assert_output_contains "[nonsense] %F{039}%f %F{076}❱%f"
  assert_output_contains "[unset] %F{039}%f %F{076}❱%f"
}

@test "the vicmd character style is honored" {
  z1_zsh 'zstyle ":z1:prompt:character" vicmd "N"
    source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    KEYMAP=vicmd; print -r -- "vicmd: ${(e)PROMPT}"'
  assert_success
  assert_output_contains "vicmd: %F{039}%f %F{076}N%f"
}

@test "disabling unicode gives vi command mode an ASCII character" {
  z1_zsh 'zstyle ":z1:prompt:unicode" disable yes
    source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    KEYMAP=vicmd; print -r -- "vicmd: ${(e)PROMPT}"
    KEYMAP=main;  print -r -- "main: ${(e)PROMPT}"'
  assert_success
  assert_output_contains "vicmd: %F{039}%f %F{076}V%f"
  assert_output_contains "main: %F{039}%f %F{076}%%%f"
}

# prompt_z1_preview used to call editor-info, a prezto function z1 does not have.
@test "previewing the prompt does not call a missing function" {
  z1_zsh 'source $Z1
    autoload -Uz promptinit && promptinit
    print "$functions[prompt_z1_preview]" | grep -q editor-info && print "leftover: yes" || print "leftover: no"'
  assert_success
  assert_line "leftover: no"
}
