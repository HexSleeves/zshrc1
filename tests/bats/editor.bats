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
# Every vi z1 picks has "vi" in the name, so an unknown keymap lands on vi
# bindings rather than emacs. A typo like `vim` gets vi mode, not a warning.
@test "an unknown keymap falls through to zsh's own default" {
  z1_zsh 'zstyle ":z1:editor" keymap nonsense
    source $Z1
    print "rc: $?"
    [[ $EDITOR == *vi* ]] && print "editor: vi-ish" || print "editor: $EDITOR"
    bindkey -lL main'
  assert_success
  assert_line "rc: 0"
  assert_line "editor: vi-ish"
  assert_line "bindkey -A viins main"
}

@test "the cursor style follows the chosen keymap" {
  z1_zsh 'zstyle ":z1:editor" keymap vi
    source $Z1
    print "$functions[update-cursor-style]" | grep -q ZSH_BINDKEY && print "reads: yes" || print "reads: no"'
  assert_success
  assert_line "reads: yes"
}

# Cursor shape per editing mode, emitted as DECSCUSR. The escapes are compared
# in their visible form, so a failure shows the sequence rather than moving the
# terminal's cursor around.
@test "the cursor is a block in vi command mode and a line elsewhere" {
  z1_zsh 'zstyle ":z1:editor" keymap vi
    source $Z1
    print "vicmd: ${(V)$(KEYMAP=vicmd update-cursor-style)}"
    print "viins: ${(V)$(KEYMAP=viins update-cursor-style)}"
    print "main:  ${(V)$(KEYMAP=main update-cursor-style)}"'
  assert_success
  assert_line 'vicmd: ^[[2 q'
  assert_line 'viins: ^[[6 q'
  assert_line 'main:  ^[[6 q'
}

@test "emacs mode gets a line cursor" {
  z1_zsh 'source $Z1; print "emacs: ${(V)$(KEYMAP=main update-cursor-style)}"'
  assert_success
  assert_line 'emacs: ^[[6 q'
}

@test "each cursor style emits its own escape" {
  z1_zsh 'source $Z1
    for s in block block-blink underscore underscore-blink line line-blink; do
      zstyle ":z1:editor:emacs" cursor $s
      print "$s: ${(V)$(KEYMAP=main update-cursor-style)}"
    done'
  assert_success
  assert_line 'block: ^[[2 q'
  assert_line 'block-blink: ^[[1 q'
  assert_line 'underscore: ^[[4 q'
  assert_line 'underscore-blink: ^[[3 q'
  assert_line 'line: ^[[6 q'
  assert_line 'line-blink: ^[[5 q'
}

@test "a cursor style is picked per mode" {
  z1_zsh 'zstyle ":z1:editor" keymap vi
    zstyle ":z1:editor:vicmd" cursor underscore
    zstyle ":z1:editor:viins" cursor block-blink
    source $Z1
    print "vicmd: ${(V)$(KEYMAP=vicmd update-cursor-style)}"
    print "viins: ${(V)$(KEYMAP=main update-cursor-style)}"'
  assert_success
  assert_line 'vicmd: ^[[4 q'
  assert_line 'viins: ^[[1 q'
}

# The emacs and viins styles are separate, so setting one leaves the other on
# its default even though zle calls both keymaps `main`.
@test "the emacs style does not leak into vi insert mode" {
  z1_zsh 'zstyle ":z1:editor" keymap vi
    zstyle ":z1:editor:emacs" cursor underscore
    source $Z1
    print "viins: ${(V)$(KEYMAP=main update-cursor-style)}"'
  assert_success
  assert_line 'viins: ^[[6 q'
}

@test "an unknown cursor style emits nothing" {
  z1_zsh 'zstyle ":z1:editor:emacs" cursor nonsense
    source $Z1
    out=$(KEYMAP=main update-cursor-style)
    print "len: ${#out}"'
  assert_success
  assert_line "len: 0"
}

@test "a terminal without DECSCUSR gets nothing" {
  z1_zsh 'source $Z1
    out=$(TERM=dumb TMUX= update-cursor-style)
    print "len: ${#out}"'
  assert_success
  assert_line "len: 0"
}

# Alias expansion. Keys are opt-in, widgets always exist so they can be bound
# elsewhere.
@test "the expand-alias widgets exist without the zstyle" {
  z1_zsh 'source $Z1
    print "space: ${widgets[expand-alias-space]}"
    print "accept: ${widgets[expand-alias-accept]}"'
  assert_success
  assert_line "space: user:expand-alias-space"
  assert_line "accept: user:expand-alias-accept"
}

@test "space and enter keep their usual widgets by default" {
  z1_zsh 'source $Z1
    print "space: $(bindkey -M emacs " ")"
    print "enter: $(bindkey -M emacs "^M")"'
  assert_success
  assert_line 'space: " " self-insert'
  assert_line 'enter: "^M" accept-line'
}

@test "the expand-alias zstyle binds space and enter" {
  z1_zsh 'zstyle ":z1:editor" expand-alias yes
    source $Z1
    print "space: $(bindkey -M emacs " ")"
    print "enter: $(bindkey -M emacs "^M")"
    print "viins: $(bindkey -M viins " ")"
    print "alt: $(bindkey -M emacs "^[ ")"
    print "isearch: $(bindkey -M isearch " ")"'
  assert_success
  assert_line 'space: " " expand-alias-space'
  assert_line 'enter: "^M" expand-alias-accept'
  assert_line 'viins: " " expand-alias-space'
  assert_line 'alt: "^[ " magic-space'
  assert_line 'isearch: " " magic-space'
}

# These call expand-alias-word with zle stubbed, since a widget needs a real
# line editor.
@test "a global alias expands" {
  z1_zsh 'source $Z1
    zle() { print "zle: $*"; }
    alias -g GG="| grep"
    LBUFFER="ls GG"
    expand-alias-word'
  assert_success
  assert_line "zle: _expand_alias"
}

@test "an alias that shadows a command is left alone" {
  z1_zsh 'source $Z1
    zle() { print "zle: $*"; }
    LBUFFER="ls"
    expand-alias-word
    print "done"'
  assert_success
  assert_line "done"
  refute_line "zle: _expand_alias"
}

@test "an alias that is not a command expands" {
  z1_zsh 'source $Z1
    zle() { print "zle: $*"; }
    alias gs="git status"
    LBUFFER="gs"
    expand-alias-word'
  assert_success
  assert_line "zle: _expand_alias"
}

@test "the exclude zstyle keeps a word from expanding" {
  z1_zsh 'source $Z1
    zle() { print "zle: $*"; }
    zstyle ":z1:editor:expand-alias" exclude gs nope
    alias gs="git status"
    LBUFFER="gs"
    expand-alias-word
    print "done"'
  assert_success
  assert_line "done"
  refute_line "zle: _expand_alias"
}

@test "the include zstyle expands an alias named after a command" {
  z1_zsh 'source $Z1
    zle() { print "zle: $*"; }
    zstyle ":z1:editor:expand-alias" include ls
    LBUFFER="ls"
    expand-alias-word'
  assert_success
  assert_line "zle: _expand_alias"
}

@test "exclude beats include" {
  z1_zsh 'source $Z1
    zle() { print "zle: $*"; }
    zstyle ":z1:editor:expand-alias" exclude gs
    zstyle ":z1:editor:expand-alias" include gs
    alias gs="git status"
    LBUFFER="gs"
    expand-alias-word
    print "done"'
  assert_success
  assert_line "done"
  refute_line "zle: _expand_alias"
}

@test "only the last word on the line is considered" {
  z1_zsh 'source $Z1
    zle() { print "zle: $*"; }
    zstyle ":z1:editor:expand-alias" exclude gs
    alias gs="git status" ll="ls -l"
    LBUFFER="gs; ll"
    expand-alias-word'
  assert_success
  assert_line "zle: _expand_alias"
}

# $EDITOR names a command, not an alias, since git and friends exec it.
@test "EDITOR picks the newest vi on the system" {
  stub_command nvim 'true'
  stub_command vim 'true'

  z1_zsh 'source $Z1; print "editor: $EDITOR"; print "visual: $VISUAL"'
  assert_success
  assert_line "editor: nvim"
  assert_line "visual: nvim"
}

# Whichever branch of the fallback chain wins, the answer is some vi. That
# holds without caring which of them the machine actually has.
@test "EDITOR lands on a vi either way" {
  z1_zsh 'source $Z1
    [[ $EDITOR == *vi* ]] && print "editor: vi-ish" || print "editor: $EDITOR"'
  assert_success
  assert_line "editor: vi-ish"
}

@test "a preset EDITOR wins, and VISUAL follows it" {
  stub_command nvim 'true'

  z1_zsh 'EDITOR=nano; source $Z1; print "editor: $EDITOR"; print "visual: $VISUAL"'
  assert_success
  assert_line "editor: nano"
  assert_line "visual: nano"
}

# stty -ixon writes terminal settings, which stops the shell with SIGTTOU when
# it runs in a background process group. A non-interactive z1 has no line
# editor to unblock Ctrl+S for, so it must not touch the terminal at all.
# $TTY points at /dev/null so the check does not depend on how the suite ran.
@test "a non-interactive shell does not touch the terminal" {
  stub_command stty 'print ran >>$HOME/stty-ran'

  z1_zsh 'TTY=/dev/null
    source $Z1
    [[ -f $HOME/stty-ran ]] && print "stty: ran" || print "stty: skipped"'
  assert_success
  assert_line "stty: skipped"
}

@test "a preset VISUAL is left alone" {
  z1_zsh 'VISUAL=code; source $Z1; print "visual: $VISUAL"'
  assert_success
  assert_line "visual: code"
}
