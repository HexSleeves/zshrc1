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

# The character comes from $KEYMAP and the color from $?, both resolved during
# prompt expansion. These render with `print -P` after forcing an exit status,
# and compare the escapes in visible form. Characters are set explicitly so the
# assertions do not move when the default glyphs are changed.
setup_chars() {
  echo 'zstyle ":z1:prompt:character" success S
    zstyle ":z1:prompt:character" error E
    zstyle ":z1:prompt:character" vicmd V
    source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    render() { KEYMAP=$2; ( exit $1 ); local o=$(print -Pn -- $PROMPT); print -r -- "${(V)o}" }'
}

@test "vi command mode gets its own prompt character" {
  z1_zsh "$(setup_chars)"'
    print "main:  $(render 0 main)"
    print "viins: $(render 0 viins)"
    print "vicmd: $(render 0 vicmd)"'
  assert_success
  assert_output_contains "main:  ^[[38;5;39m^[[39m^[[1m^[[38;5;37m^[[39m^[[0m ^[[38;5;76mS^[[39m"
  assert_output_contains "viins: ^[[38;5;39m^[[39m^[[1m^[[38;5;37m^[[39m^[[0m ^[[38;5;76mS^[[39m"
  assert_output_contains "vicmd: ^[[38;5;39m^[[39m^[[1m^[[38;5;37m^[[39m^[[0m ^[[38;5;76mV^[[39m"
}

# zle also reports isearch and listscroll. Looking the keymap up in the
# character table means an unnamed one falls back rather than printing itself.
@test "an unrecognized keymap falls back to the success character" {
  z1_zsh "$(setup_chars)"'
    for k in isearch listscroll nonsense ""; do print "[$k] $(render 0 $k)"; done'
  assert_success
  assert_output_contains "[isearch] ^[[38;5;39m^[[39m^[[1m^[[38;5;37m^[[39m^[[0m ^[[38;5;76mS^[[39m"
  assert_output_contains "[listscroll] ^[[38;5;39m^[[39m^[[1m^[[38;5;37m^[[39m^[[0m ^[[38;5;76mS^[[39m"
  assert_output_contains "[nonsense] ^[[38;5;39m^[[39m^[[1m^[[38;5;37m^[[39m^[[0m ^[[38;5;76mS^[[39m"
  assert_output_contains "[] ^[[38;5;39m^[[39m^[[1m^[[38;5;37m^[[39m^[[0m ^[[38;5;76mS^[[39m"
}

@test "a failed command switches to the error character in red" {
  z1_zsh "$(setup_chars)"'
    print "ok:   $(render 0 main)"
    print "fail: $(render 1 main)"'
  assert_success
  assert_output_contains "ok:   ^[[38;5;39m^[[39m^[[1m^[[38;5;37m^[[39m^[[0m ^[[38;5;76mS^[[39m"
  assert_output_contains "fail: ^[[38;5;39m^[[39m^[[1m^[[38;5;37m^[[39m^[[0m ^[[38;5;160mE^[[39m"
}

# In command mode the keymap still owns the character, but the color follows the
# exit status, so a failure is not hidden by being in vi command mode.
@test "vi command mode keeps its character but takes the error color" {
  z1_zsh "$(setup_chars)"'
    print "ok:   $(render 0 vicmd)"
    print "fail: $(render 1 vicmd)"'
  assert_success
  assert_output_contains "ok:   ^[[38;5;39m^[[39m^[[1m^[[38;5;37m^[[39m^[[0m ^[[38;5;76mV^[[39m"
  assert_output_contains "fail: ^[[38;5;39m^[[39m^[[1m^[[38;5;37m^[[39m^[[0m ^[[38;5;160mV^[[39m"
}

@test "the color styles are honored" {
  z1_zsh "$(setup_chars)"'
    zstyle ":z1:prompt:colors" red 196
    zstyle ":z1:prompt:colors" green 046
    prompt z1
    print "ok:   $(render 0 main)"
    print "fail: $(render 1 main)"'
  assert_success
  assert_output_contains "ok:   ^[[38;5;39m^[[39m^[[1m^[[38;5;37m^[[39m^[[0m ^[[38;5;46mS^[[39m"
  assert_output_contains "fail: ^[[38;5;39m^[[39m^[[1m^[[38;5;37m^[[39m^[[0m ^[[38;5;196mE^[[39m"
}

@test "disabling unicode gives ASCII characters" {
  z1_zsh 'zstyle ":z1:prompt:unicode" disable yes
    source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    render() { KEYMAP=$2; ( exit $1 ); local o=$(print -Pn -- $PROMPT); print -r -- "${(V)o}" }
    print "ok:    $(render 0 main)"
    print "vicmd: $(render 0 vicmd)"'
  assert_success
  assert_output_contains "ok:    ^[[38;5;39m^[[39m^[[1m^[[38;5;37m^[[39m^[[0m ^[[38;5;76m%^[[39m"
  assert_output_contains "vicmd: ^[[38;5;39m^[[39m^[[1m^[[38;5;37m^[[39m^[[0m ^[[38;5;76mV^[[39m"
}

# prompt_z1_preview used to call editor-info, a prezto function z1 does not have.
@test "previewing the prompt does not call a missing function" {
  z1_zsh 'source $Z1
    autoload -Uz promptinit && promptinit
    print "$functions[prompt_z1_preview]" | grep -q editor-info && print "leftover: yes" || print "leftover: no"'
  assert_success
  assert_line "leftover: no"
}

@test "the prompt runs vcs_info asynchronously when lib/z1_async.zsh is there" {
  z1_zsh 'source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    print "async: $(( $+functions[async-task] ))"
    print "rprompt: $RPROMPT"
    print "task: ${async_tasks[prompt_z1_vcs]}"'
  assert_success
  assert_line "async: 1"
  assert_line 'rprompt: ${async_output[prompt_z1_vcs]}'
  assert_line "task: prompt_z1_vcs"
}

# The prompt has to work on its own, since a lone z1.zsh has no lib/ beside it.
@test "the prompt falls back to synchronous vcs_info without the library" {
  mkdir -p "$TEST_HOME/solo/prompts"
  cp "$PRJDIR/z1.zsh" "$TEST_HOME/solo/z1.zsh"
  cp "$PRJDIR/prompts/prompt_z1_setup" "$TEST_HOME/solo/prompts/"

  z1_zsh 'source $HOME/solo/z1.zsh
    autoload -Uz promptinit && promptinit && prompt z1
    print "async: $(( $+functions[async-task] ))"
    print "rprompt: $RPROMPT"'
  assert_success
  assert_line "async: 0"
  assert_line 'rprompt: ${vcs_info_msg_0_}'
}

@test "precmd does not run vcs_info when the async task has it" {
  z1_zsh 'source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    vcs_info_msg_0_=untouched
    prompt_z1_precmd
    print "sync ran: $([[ $vcs_info_msg_0_ == untouched ]] && print no || print yes)"'
  assert_success
  assert_line "sync ran: no"
}

@test "the async task produces the branch name in a repo" {
  mkdir -p "$TEST_HOME/repo"
  git -C "$TEST_HOME/repo" init -q
  git -C "$TEST_HOME/repo" config user.email t@example.com
  git -C "$TEST_HOME/repo" config user.name tester
  : >"$TEST_HOME/repo/file"
  git -C "$TEST_HOME/repo" add file
  git -C "$TEST_HOME/repo" commit -qm init

  z1_zsh 'source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    builtin cd $HOME/repo
    prompt_z1_precmd; async-run; async-wait
    print "vcs: ${async_output[prompt_z1_vcs]}"'
  assert_success
  assert_output_contains "vcs: "
  refute_line "vcs: "
}

# Transient prompt collapses an accepted line to the character alone. It cannot
# be observed without a terminal repainting, so these check the parts: the
# widget binding, the collapsed string, and precmd putting the full prompt back.
# The style is read in precmd, so these call it rather than only loading.
@test "transient prompt is off by default" {
  z1_zsh 'source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    prompt_z1_precmd
    print "transient: [$_prompt_z1_transient]"'
  assert_success
  assert_line "transient: []"
}

@test "the prompt joins the accept-line hooks" {
  z1_zsh 'source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    print "hooks: $accept_line_hook"'
  assert_success
  assert_line "hooks: prompt_z1_accept_line"
}

# Setting the style after the prompt is already running has to work, since that
# is how anyone tries it out.
@test "the style can be turned on after the prompt is initialized" {
  z1_zsh 'source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    prompt_z1_precmd
    print "before: [$_prompt_z1_transient]"
    zstyle ":z1:prompt" transient yes
    prompt_z1_precmd
    print "after: [${(V)_prompt_z1_transient}]"'
  assert_success
  assert_line "before: []"
  refute_line "after: []"
}

@test "the style can be turned off again" {
  z1_zsh 'zstyle ":z1:prompt" transient yes
    source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    prompt_z1_precmd
    print "on: [${(V)_prompt_z1_transient}]"
    zstyle ":z1:prompt" transient no
    prompt_z1_precmd
    print "off: [$_prompt_z1_transient]"'
  assert_success
  refute_line "on: []"
  assert_line "off: []"
}

@test "the collapsed prompt is the character in cyan, with no path" {
  z1_zsh 'zstyle ":z1:prompt" transient yes
    zstyle ":z1:prompt:character" success S
    source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    prompt_z1_precmd
    o=$(print -Pn -- $_prompt_z1_transient); print "transient: ${(V)o}"'
  assert_success
  assert_line "transient: ^[[38;5;37mS^[[39m "
}

# Cyan regardless of exit status, so scrollback has no red in it.
@test "the collapsed prompt keeps its color after a failure" {
  z1_zsh 'zstyle ":z1:prompt" transient yes
    zstyle ":z1:prompt:character" success S
    zstyle ":z1:prompt:character" error E
    source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    ( exit 1 ); prompt_z1_precmd
    o=$(print -Pn -- $_prompt_z1_transient); print "transient: ${(V)o}"'
  assert_success
  assert_line "transient: ^[[38;5;37mS^[[39m "
}

@test "precmd puts the full prompt back after a collapse" {
  z1_zsh 'zstyle ":z1:prompt" transient yes
    source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    PROMPT=$_prompt_z1_transient
    prompt_z1_precmd
    print "restored: $([[ $PROMPT == $_prompt_z1_full ]] && print yes || print no)"'
  assert_success
  assert_line "restored: yes"
}

# Unbinding only reverts a widget z1 installed, so another plugin's accept-line
# wrapper is left alone.
@test "another accept-line wrapper is not unbound" {
  z1_zsh 'source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    function other-accept-line { zle .accept-line }
    zle -N accept-line other-accept-line
    prompt_z1_precmd
    print "widget: ${widgets[accept-line]}"'
  assert_success
  assert_line "widget: user:other-accept-line"
}

@test "the branch name is magenta" {
  mkdir -p "$TEST_HOME/repo"
  git -C "$TEST_HOME/repo" init -q
  git -C "$TEST_HOME/repo" config user.email t@example.com
  git -C "$TEST_HOME/repo" config user.name tester
  : >"$TEST_HOME/repo/file"
  git -C "$TEST_HOME/repo" add file
  git -C "$TEST_HOME/repo" commit -qm init

  z1_zsh 'source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    builtin cd $HOME/repo
    prompt_z1_precmd; async-run; async-wait
    o=$(print -Pn -- $RPROMPT); print "branch: ${(V)o}"'
  assert_success
  assert_output_contains "branch: ^[[38;5;168m"
}

# The last path component is highlighted on its own: leading part blue, final
# component bold and cyan.
@test "the last path component is bold cyan and the rest blue" {
  mkdir -p "$TEST_HOME/one/two/three"

  z1_zsh 'source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    builtin cd $HOME/one/two/three
    prompt_z1_precmd
    print "head: [$_prompt_z1_pwd_head]"
    print "tail: [$_prompt_z1_pwd_tail]"
    o=$(print -Pn -- $PROMPT); print "rendered: ${(V)o}"'
  assert_success
  assert_line "head: [~/o/t/]"
  assert_line "tail: [three]"
  assert_output_contains "^[[38;5;39m~/o/t/^[[39m^[[1m^[[38;5;37mthree^[[39m^[[0m"
}

@test "home is a single bold cyan component" {
  z1_zsh 'source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    builtin cd $HOME
    prompt_z1_precmd
    print "head: [$_prompt_z1_pwd_head]"
    print "tail: [$_prompt_z1_pwd_tail]"'
  assert_success
  assert_line "head: []"
  assert_line "tail: [~]"
}

@test "root keeps its slash in the leading part" {
  z1_zsh 'source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    builtin cd /
    prompt_z1_precmd
    print "head: [$_prompt_z1_pwd_head]"
    print "tail: [$_prompt_z1_pwd_tail]"'
  assert_success
  assert_line "head: [/]"
  assert_line "tail: []"
}

# vcs_info's git backend fills %m with rebase patch state, including a raw sha.
# The hook clears it, since actionformats already names the action.
@test "a rebase does not leak patch state into the prompt" {
  local r="$TEST_HOME/repo"
  git -C "$TEST_HOME" init -q repo
  git -C "$r" config user.email t@example.com
  git -C "$r" config user.name tester
  echo one >"$r/f"; git -C "$r" add f; git -C "$r" commit -qm one
  git -C "$r" checkout -q -b side
  echo side >"$r/f"; git -C "$r" commit -qam side
  git -C "$r" checkout -q -
  echo main >"$r/f"; git -C "$r" commit -qam main
  git -C "$r" rebase side >/dev/null 2>&1 || true

  z1_zsh 'source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    builtin cd $HOME/repo
    prompt_z1_precmd; async-run; async-wait
    print "rprompt: ${(V)$(print -Pn -- $RPROMPT)}"'
  assert_success
  assert_output_contains "rebase"
  refute_output_matches "applied"
  refute_output_matches "[0-9a-f]{40}"
}

@test "the dirty marker uses the palette red, not basic red" {
  local r="$TEST_HOME/repo"
  git -C "$TEST_HOME" init -q repo
  git -C "$r" config user.email t@example.com
  git -C "$r" config user.name tester
  : >"$r/tracked"; git -C "$r" add tracked; git -C "$r" commit -qm init
  : >"$r/untracked"

  z1_zsh 'source $Z1
    autoload -Uz promptinit && promptinit && prompt z1
    builtin cd $HOME/repo
    prompt_z1_precmd; async-run; async-wait
    print "rprompt: ${(V)$(print -Pn -- $RPROMPT)}"'
  assert_success
  assert_output_contains "^[[38;5;160m"
  refute_output_matches '\^\[\[31m'
}
