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
@test "the expand-alias widget exists without the zstyle" {
  z1_zsh 'source $Z1
    print "space: ${widgets[expand-alias-space]}"'
  assert_success
  assert_line "space: user:expand-alias-space"
}

@test "space keeps its usual widget by default" {
  z1_zsh 'source $Z1
    print "space: $(bindkey -M emacs " ")"'
  assert_success
  assert_line 'space: " " self-insert'
}

@test "the expand-alias zstyle binds space and hooks accept-line" {
  z1_zsh 'zstyle ":z1:editor" expand-alias yes
    source $Z1
    print "space: $(bindkey -M emacs " ")"
    print "viins: $(bindkey -M viins " ")"
    print "alt: $(bindkey -M emacs "^[ ")"
    print "isearch: $(bindkey -M isearch " ")"
    print "hooks: $accept_line_hook"'
  assert_success
  assert_line 'space: " " expand-alias-space'
  assert_line 'viins: " " expand-alias-space'
  assert_line 'alt: "^[ " magic-space'
  assert_line 'isearch: " " magic-space'
  assert_line 'hooks: expand-alias-word'
}

@test "nothing hooks accept-line without the zstyles" {
  z1_zsh 'source $Z1
    print "hooks: [$accept_line_hook]"'
  assert_success
  assert_line 'hooks: []'
}

# default-command runs ahead of the hooks, so a hook sees the filled-in line.
@test "the hooks see the default command" {
  z1_zsh 'zstyle ":z1:editor:default-command" command "print PLAIN"
    source $Z1
    function spy() { print "spy: [$BUFFER]" }
    add-accept-line-hook spy
    CONTEXT=start BUFFER=""
    default-command
    run-accept-line-hooks'
  assert_success
  assert_line 'spy: [ print PLAIN]'
}

@test "the wrapper fills the line before running the hooks" {
  z1_zsh 'source $Z1
    print "body: ${functions[accept-line-with-hooks]//[[:space:]]##/ }"'
  assert_success
  assert_output_contains "default-command run-accept-line-hooks"
}

# The hook list is a public API, so a caller has to be able to take one back off.
@test "a hook can be added and removed" {
  z1_zsh 'source $Z1
    function one() { :; }; function two() { :; }
    add-accept-line-hook one two
    print "added: $accept_line_hook"
    add-accept-line-hook one one
    print "twice: $accept_line_hook"
    add-accept-line-hook -d one
    print "removed: $accept_line_hook"'
  assert_success
  assert_line "added: one two"
  assert_line "twice: one two"
  assert_line "removed: two"
}

# A hook whose function is gone would otherwise print an error on every Enter.
@test "a hook that no longer exists is skipped" {
  z1_zsh 'source $Z1
    function gone() { :; }
    function here() { print "here: ran" }
    add-accept-line-hook gone here
    unfunction gone
    run-accept-line-hooks
    print "rc: $?"'
  assert_success
  assert_line "here: ran"
  assert_line "rc: 0"
}

@test "a failing hook does not stop the next one" {
  z1_zsh 'source $Z1
    function boom() { return 1 }
    function after() { print "after: ran" }
    add-accept-line-hook boom after
    run-accept-line-hooks
    print "rc: $?"'
  assert_success
  assert_line "after: ran"
  assert_line "rc: 0"
}

# Enter runs a command on an empty line, and does nothing until one is set. The
# styles are read per keypress, so setting one mid-session takes effect.
@test "an unset default command leaves the line alone" {
  z1_zsh 'source $Z1
    CONTEXT=start BUFFER=""
    default-command
    print "before: [$BUFFER]"
    zstyle ":z1:editor:default-command" command "print PLAIN"
    default-command
    print "after: [$BUFFER]"'
  assert_success
  assert_line 'before: []'
  assert_line 'after: [ print PLAIN]'
}

@test "the default command fills an empty line" {
  z1_zsh 'zstyle ":z1:editor:default-command" command "print PLAIN"
    source $Z1
    CONTEXT=start BUFFER=""
    builtin cd $HOME
    default-command
    print "buffer: [$BUFFER] cursor: $CURSOR"'
  assert_success
  assert_line 'buffer: [ print PLAIN] cursor: 12'
}

@test "a busy line is left alone" {
  z1_zsh 'zstyle ":z1:editor:default-command" command "print PLAIN"
    source $Z1
    CONTEXT=start BUFFER="echo hi"
    default-command
    print "buffer: [$BUFFER]"'
  assert_success
  assert_line 'buffer: [echo hi]'
}

@test "a git checkout prefers git-command" {
  git -C "$TEST_HOME" init -q
  z1_zsh 'zstyle ":z1:editor:default-command" command "print PLAIN"
    zstyle ":z1:editor:default-command" git-command "print GIT"
    source $Z1
    CONTEXT=start BUFFER=""
    builtin cd $HOME
    default-command
    print "buffer: [$BUFFER]"'
  assert_success
  assert_line 'buffer: [ print GIT]'
}

# jj wins over git, since a colocated repo is both.
@test "a jj workspace prefers jj-command" {
  git -C "$TEST_HOME" init -q
  stub_command jj 'exit 0'
  z1_zsh 'zstyle ":z1:editor:default-command" git-command "print GIT"
    zstyle ":z1:editor:default-command" jj-command "print JJ"
    source $Z1
    CONTEXT=start BUFFER=""
    builtin cd $HOME
    default-command
    print "buffer: [$BUFFER]"'
  assert_success
  assert_line 'buffer: [ print JJ]'
}

@test "jj outside a workspace falls through to git" {
  git -C "$TEST_HOME" init -q
  stub_command jj 'exit 1'
  z1_zsh 'zstyle ":z1:editor:default-command" git-command "print GIT"
    zstyle ":z1:editor:default-command" jj-command "print JJ"
    source $Z1
    CONTEXT=start BUFFER=""
    builtin cd $HOME
    default-command
    print "buffer: [$BUFFER]"'
  assert_success
  assert_line 'buffer: [ print GIT]'
}

@test "a repo command falls back to the plain one outside a checkout" {
  z1_zsh 'zstyle ":z1:editor:default-command" command "print PLAIN"
    zstyle ":z1:editor:default-command" git-command "print GIT"
    source $Z1
    CONTEXT=start BUFFER=""
    builtin cd $HOME
    default-command
    print "buffer: [$BUFFER]"'
  assert_success
  assert_line 'buffer: [ print PLAIN]'
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
