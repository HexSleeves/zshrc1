#!/usr/bin/env zsh
# autosuggest - finish the line you are typing from what you typed before.
#
#   source /path/to/lib/autosuggest.zsh
#   zstyle ':z1:editor' autosuggest-highlight 'fg=8'
#   zstyle ':z1:editor' autosuggest-strategy 'my-suggester'
#
# The best match for what is on the line is shown after the cursor, dimmed.
# Right arrow or Ctrl+E takes all of it, Alt+F takes a word, and anything else
# ignores it. The suggestion is recomputed on every redraw rather than by
# wrapping the editing widgets, so widgets added later need no special care.

autoload -Uz is-at-least add-zle-hook-widget
is-at-least 5.9 || return 0

# Longest line still worth searching for. A prefix this long has usually
# stopped matching anything anyway.
typeset -gi Z1_AUTOSUGGEST_MAX=300

# The last line looked up and what it produced. line-pre-redraw can fire
# several times per keypress, and the answer only changes when the line does.
# The shortest line known to match nothing is worth keeping too: no longer line
# starting with it can match either, so a whole word can be typed out after a
# miss without searching again. A strategy of your own may not work that way,
# so only the history one gets the shortcut.
typeset -g _z1_suggest_buffer=
typeset -g _z1_suggest_result=
typeset -g _z1_suggest_miss=

# The default strategy: the most recent history entry starting with $1. Replace
# it with your own, which sets $suggestion rather than printing, since a command
# substitution on every keypress means a fork on every keypress:
#   zstyle ':z1:editor' autosuggest-strategy 'my-suggester'
function autosuggest-history() {
  emulate -L zsh
  setopt extended_glob
  suggestion=${history[(r)${(b)1}*]}
}

# True when a suggestion would be in the way rather than helpful.
function autosuggest-suppressed() {
  [[ -z $BUFFER || $#BUFFER -gt $Z1_AUTOSUGGEST_MAX ]] && return 0
  # PS2 lines and multi-line buffers already have text below the cursor.
  [[ -n $PREBUFFER || $BUFFER == *$'\n'* ]] && return 0
  # Only while typing: not in vi command mode, and not in an isearch.
  [[ $KEYMAP == (vicmd|isearch) ]] && return 0
  # Up and Down search fills the line itself and paints its own match.
  (( $+functions[history-search-in-progress] )) && history-search-in-progress
}

# Put the suggestion in POSTDISPLAY, which zle shows after the cursor without
# it being part of the line. The memo tag marks the highlight as ours so the
# next redraw can drop it, the same way the history search highlight does.
function autosuggest-fetch() {
  region_highlight=(${region_highlight:#*memo=z1-autosuggest})
  POSTDISPLAY=

  # An empty line is a fresh one, and the command just run may be the very
  # thing a remembered miss says not to look for.
  [[ -n $BUFFER ]] || _z1_suggest_miss=

  autosuggest-suppressed && return 0

  if [[ $BUFFER != "$_z1_suggest_buffer" ]]; then
    local strategy suggestion=
    zstyle -s ':z1:editor' autosuggest-strategy strategy || strategy=autosuggest-history

    if [[ $strategy == autosuggest-history && -n $_z1_suggest_miss &&
          $BUFFER == "$_z1_suggest_miss"* ]]; then
      _z1_suggest_buffer=$BUFFER
      _z1_suggest_result=
      return 0
    fi

    (( $+functions[$strategy] )) || return 0
    $strategy "$BUFFER"
    _z1_suggest_buffer=$BUFFER
    _z1_suggest_result=$suggestion
    [[ -n $suggestion ]] && _z1_suggest_miss= || _z1_suggest_miss=$BUFFER
  fi

  [[ -n $_z1_suggest_result && $_z1_suggest_result == "$BUFFER"* ]] || return 0
  POSTDISPLAY=${_z1_suggest_result#"$BUFFER"}
  [[ -n $POSTDISPLAY ]] || return 0

  local style
  zstyle -s ':z1:editor' autosuggest-highlight style || style=fg=8
  region_highlight+=("$#BUFFER $(($#BUFFER + $#POSTDISPLAY)) $style memo=z1-autosuggest")
}

# Move the suggestion into the line. Not a widget: it reports whether there was
# anything to take, so the widgets below can fall back to their own job.
function autosuggest-take() {
  [[ -n $POSTDISPLAY ]] && (( CURSOR == $#BUFFER )) || return 1
  BUFFER+=$POSTDISPLAY
  POSTDISPLAY=
  CURSOR=$#BUFFER
}

# Right arrow past the end of the line takes the whole suggestion, and anywhere
# else it still moves the cursor.
function autosuggest-forward-char() {
  autosuggest-take || zle .forward-char
}
zle -N autosuggest-forward-char

function autosuggest-end-of-line() {
  autosuggest-take || zle .end-of-line
}
zle -N autosuggest-end-of-line

# Take one word of the suggestion: the spaces before the next word, and the
# word itself. What is left is found again by the redraw that follows.
function autosuggest-forward-word() {
  setopt local_options extended_glob
  if [[ -n $POSTDISPLAY ]] && (( CURSOR == $#BUFFER )); then
    BUFFER+=${(M)POSTDISPLAY##[[:space:]]#[^[:space:]]#}
    CURSOR=$#BUFFER
  else
    zle .forward-word
  fi
}
zle -N autosuggest-forward-word

# A finished line is redrawn one last time and then left on the screen, so the
# suggestion has to come off it first. Otherwise `ls -l` runs but the scrollback
# reads `ls -lah`.
function autosuggest-clear() {
  region_highlight=(${region_highlight:#*memo=z1-autosuggest})
  POSTDISPLAY=
}
add-zle-hook-widget line-finish autosuggest-clear

# Highlighters append to region_highlight on every redraw and the last span
# covering a character wins, so re-register at post_zshrc to land after any
# highlighter sourced later.
function autosuggest-highlight-last() {
  add-zle-hook-widget -d line-pre-redraw autosuggest-fetch
  add-zle-hook-widget line-pre-redraw autosuggest-fetch
  # A plugin that claims zle-line-finish with its own `zle -N` throws away
  # every hook already on it, so put ours back once everything has loaded.
  add-zle-hook-widget -d line-finish autosuggest-clear
  add-zle-hook-widget line-finish autosuggest-clear
}
add-zle-hook-widget line-pre-redraw autosuggest-fetch
(( $+functions[add-post-zshrc-hook] )) && add-post-zshrc-hook autosuggest-highlight-last

# terminfo names only the sequence its own terminal sends, so the xterm and SS3
# forms are bound too. An empty sequence is skipped rather than bound.
zmodload zsh/terminfo 2>/dev/null
function autosuggest-bindkey() {
  local widget=$1 keymap seq; shift
  for keymap in emacs viins; do
    for seq in "$@"; do
      [[ -n $seq ]] && bindkey -M $keymap "$seq" $widget
    done
  done
}
autosuggest-bindkey autosuggest-forward-char "${terminfo[kcuf1]-}" '^[[C' '^[OC' '^F'
autosuggest-bindkey autosuggest-end-of-line  '^E'
autosuggest-bindkey autosuggest-forward-word '^[f'
