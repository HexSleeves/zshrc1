#!/usr/bin/env bats
# Line editor keymap selection.

load helpers/common

setup() { z1_setup; }
teardown() { z1_teardown; }

@test "the keymap is emacs by default" {
  z1_zsh 'source $Z1; bindkey -lL main; print "ZSH_BINDKEY: $ZSH_BINDKEY"'
  assert_success
  assert_line "bindkey -A emacs main"
  assert_line "ZSH_BINDKEY: emacs"
}

@test "the keymap zstyle selects vi" {
  z1_zsh 'zstyle ":z1:editor" keymap vi; source $Z1; bindkey -lL main'
  assert_success
  assert_line "bindkey -A viins main"
}

@test "the keymap zstyle selects emacs" {
  z1_zsh 'zstyle ":z1:editor" keymap emacs; source $Z1; bindkey -lL main'
  assert_success
  assert_line "bindkey -A emacs main"
}

# ZSH_BINDKEY is the older spelling, and still wins, the same way a preset
# ZSH_COMPDUMP beats the compinit dumpfile style.
@test "ZSH_BINDKEY still selects vi" {
  z1_zsh 'ZSH_BINDKEY=vi; source $Z1; bindkey -lL main'
  assert_success
  assert_line "bindkey -A viins main"
}

@test "ZSH_BINDKEY wins over the zstyle" {
  z1_zsh 'ZSH_BINDKEY=emacs
    zstyle ":z1:editor" keymap vi
    source $Z1
    bindkey -lL main
    print "ZSH_BINDKEY: $ZSH_BINDKEY"'
  assert_success
  assert_line "bindkey -A emacs main"
  assert_line "ZSH_BINDKEY: emacs"
}

@test "an empty ZSH_BINDKEY does not block the zstyle" {
  z1_zsh 'ZSH_BINDKEY=""
    zstyle ":z1:editor" keymap vi
    source $Z1
    bindkey -lL main'
  assert_success
  assert_line "bindkey -A viins main"
}

# The chosen keymap has to land in ZSH_BINDKEY, because update-cursor-style
# reads it on every keymap change.
@test "the zstyle answer ends up in ZSH_BINDKEY" {
  z1_zsh 'zstyle ":z1:editor" keymap vi; source $Z1; print "ZSH_BINDKEY: $ZSH_BINDKEY"'
  assert_success
  assert_line "ZSH_BINDKEY: vi"
}

# An unrecognized value is left to zsh, which picks its default from $EDITOR.
# z1 sets EDITOR=vim just above, so an unknown keymap lands on vi bindings
# rather than emacs. A typo like `vim` gets vi mode, not a warning.
@test "an unknown keymap falls through to zsh's own default" {
  z1_zsh 'zstyle ":z1:editor" keymap nonsense
    source $Z1
    print "rc: $?"
    print "editor: $EDITOR"
    bindkey -lL main'
  assert_success
  assert_line "rc: 0"
  assert_line "editor: vim"
  assert_line "bindkey -A viins main"
}

@test "the cursor style follows the chosen keymap" {
  z1_zsh 'zstyle ":z1:editor" keymap vi
    source $Z1
    print "$functions[update-cursor-style]" | grep -q ZSH_BINDKEY && print "reads: yes" || print "reads: no"'
  assert_success
  assert_line "reads: yes"
}
