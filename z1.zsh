#!/usr/bin/env zsh
# z1 - the first thing to run for a modern Zsh config

#
# Init
#

0=${(%):-%N}

# Set Zsh location vars.
ZSH_CONFIG_DIR="${ZDOTDIR:-${XDG_CONFIG_HOME:-$HOME/.config}/zsh}"
ZSH_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh"
ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
mkdir -p $ZSH_CONFIG_DIR $ZSH_DATA_DIR $ZSH_CACHE_DIR

# Set any zstyles you might use for configuration. To source .zstyles yourself
# instead of here set the following zstyle:
#   zstyle ':z1:zstyles' loaded 'yes'
if ! zstyle -t ':z1:zstyles' loaded; then
  [ -r $ZSH_CONFIG_DIR/.zstyles ] \
  && . $ZSH_CONFIG_DIR/.zstyles
  zstyle ':z1:zstyles' loaded 'yes'
fi

# Run a command that prints Zsh code and source its output, keeping a cached copy so
# later shells benefit.
#   cached-eval brew shellenv
# Caches live in $ZSH_CACHE_DIR and lasts 20 hours. Be careful to only cache commands
# with stable output. To reset the cache, use --clear:
#   cached-eval --clear brew shellenv  # just clear brew shellenv
#   cached-eval --clear                # clear all
function cached-eval() {
  emulate -L zsh
  setopt local_options extended_glob

  local cachedir=$ZSH_CACHE_DIR/cached-eval
  [[ -n "$ZSH_CACHE_DIR" ]] || return 1

  local -i clear=0
  [[ "$1" == --clear ]] && { clear=1; shift }

  # A bare --clear takes out every cache.
  if (( clear && ! $# )); then
    command rm -f $cachedir/*(N.)
    return
  fi
  (( $# )) || return 1

  # Name the cache file after the command, with a djb2 hash of the whole command
  # line so that different arguments, or two same-named commands in different
  # places, each get their own cache.
  local c
  local -i hash=5381
  for c in ${(s::)${(j: :)@}}; do
    (( hash = (hash * 33 + #c) % 4294967296 ))
  done
  local cachefile=$cachedir/${1:t}-${hash}.zsh

  if (( clear )); then
    command rm -f $cachefile
    return
  fi

  # Rebuild via a temp file so a failed command doesn't poison the cache.
  if [[ -z $cachefile(#qNmh-20) ]]; then
    mkdir -p $cachefile:h
    if ! "$@" >| $cachefile.$$; then
      command rm -f $cachefile.$$
      return 1
    fi
    command mv -f $cachefile.$$ $cachefile
  fi

  source $cachefile
}

#
# Paths
#

# Ensure path arrays do not contain duplicates.
typeset -gaU cdpath fpath mailpath path prepath

# prepath lets you keep elements at the front of path. Set it yourself, or via a
# zstyle, and z1 will leave it alone:
#   zstyle ':z1:path' prepath ~/bin ~/.local/bin
if (( ! $#prepath )); then
  zstyle -a ':z1:path' prepath 'prepath' \
  || prepath=(
    $HOME/{,s}bin(N)
    $HOME/.local/{,s}bin(N)
  )
  prepath=(${~prepath})
fi

# path sets where Zsh searches for programs.
path=(
  $prepath
  /opt/{homebrew,local}/{,s}bin(N)
  /usr/local/{,s}bin(N)
  $path
)

# repath will reset the path order
function repath() {
  path=($prepath $path)
}

#
# Homebrew
#

# Setup homebrew if it exists on the system.
if (( $+commands[brew] )); then
  if zstyle -t ':z1:homebrew' cache; then
    cached-eval brew shellenv
  else
    source <(brew shellenv)
  fi

  # Preserve the desired path order.
  path=($prepath $path)
fi

#
# Environment
#

# Ensure reasonable defaults.
if (( $+commands[open] )); then
  export BROWSER="${BROWSER:-open}"
fi
export PAGER="${PAGER:-less}"
export LANG="${LANG:-en_US.UTF-8}"
export LESS="${LESS:--g -i -M -R -S -w -z-4}"
export EDITOR="${EDITOR:-vim}"
export VISUAL="${VISUAL:-vim}"

# Reduce vi-mode switch lag.
export KEYTIMEOUT=${KEYTIMEOUT:-1}

# Hook lesspipe(.sh) into less so it can handle non-text formats.
if [[ -z "$LESSOPEN" ]] && (( $#commands[(i)lesspipe(|.sh)] )); then
  export LESSOPEN="| /usr/bin/env $commands[(i)lesspipe(|.sh)] %s 2>&-"
fi

#
# Globbing
#

# 16.2.3 Expansion and Globbing
setopt extended_glob           # Use extended globbing syntax.

#
# IO
#

# 16.2.6 Input/Output
setopt interactive_comments    # Enable comments in interactive shell.
setopt multios                 # Write to multiple descriptors.
setopt rc_quotes               # Allow 'Hitchhiker''s Guide' instead of 'Hitchhiker'\''s Guide'.
setopt NO_clobber              # Don't overwrite files with >. Use >| to bypass.
setopt NO_mail_warning         # Don't print a warning if a mail file was accessed.
setopt NO_rm_star_silent       # Ask for confirmation for `rm *' or `rm path/*'

#
# History
#

# Set history options.
setopt bang_hist               # Treat the '!' character specially during expansion.
setopt extended_history        # Write the history file in the ':start:elapsed;command' format.
setopt hist_expire_dups_first  # Expire a duplicate event first when trimming history.
setopt hist_find_no_dups       # Do not display a previously found event.
setopt hist_ignore_dups        # Don't write to history if the prior command is a duplicate.
setopt hist_ignore_space       # Do not record an event starting with a space.
setopt hist_reduce_blanks      # Remove extra blanks from commands added to the history list.
setopt hist_verify             # Do not execute immediately upon history expansion.
setopt inc_append_history      # Write to the history file immediately, not when the shell exits.
setopt NO_hist_beep            # Don't beep when accessing non-existent history.
setopt NO_share_history        # Don't share history between all sessions.

# Set the history file and its sizes. HISTSIZE and SAVEHIST always have a value
# in Zsh, so a zstyle is the only way to opt out of these defaults, eg:
#   zstyle ':z1:history' histfile "$HOME/.zsh_history"
#   zstyle ':z1:history' savehist 500000
# Absent a zstyle, the sizes only grow, and never shrink a larger existing value.
HISTFILE="$ZSH_DATA_DIR/zsh_history"
[[ "$SAVEHIST" -gt 100000 ]] || SAVEHIST=100000  # History file size.
[[ "$HISTSIZE" -gt  50000 ]] || HISTSIZE=50000   # Session history size.

# A zstyle wins outright. Assign via a temp because `zstyle -s` empties its
# target variable when the style isn't set.
zstyle -s ':z1:history' histfile _z1_val && HISTFILE=$_z1_val
zstyle -s ':z1:history' savehist _z1_val && SAVEHIST=$_z1_val
zstyle -s ':z1:history' histsize _z1_val && HISTSIZE=$_z1_val
unset _z1_val

# Helpful history commands.
alias history='fc -li'
alias histsync='fc -RI'

#
# Color
#

# Built-in zsh colors
autoload -Uz colors && colors

# Colorize man pages.
export LESS_TERMCAP_md=${LESS_TERMCAP_md:-$fg_bold[blue]}   # start bold
export LESS_TERMCAP_mb=${LESS_TERMCAP_mb:-$fg_bold[blue]}   # start blink
export LESS_TERMCAP_so=${LESS_TERMCAP_so:-$'\e[00;47;30m'}  # start standout: white bg, black fg
export LESS_TERMCAP_us=${LESS_TERMCAP_us:-$'\e[04;35m'}     # start underline: underline magenta
export LESS_TERMCAP_se=${LESS_TERMCAP_se:-$reset_color}     # end standout
export LESS_TERMCAP_ue=${LESS_TERMCAP_ue:-$reset_color}     # end underline
export LESS_TERMCAP_me=${LESS_TERMCAP_me:-$reset_color}     # end bold/blink

# Colorize commands. Build on any alias already set rather than replacing it, and
# leave it alone if it already asks for color.
[[ "$aliases[grep]" == *--color* ]] || alias grep="${aliases[grep]:-grep} --color=auto"

# Older BSD diff has no --color, so ask before aliasing.
if [[ "$aliases[diff]" != *--color* ]] && command diff --color /dev/null{,} &>/dev/null; then
  alias diff="${aliases[diff]:-diff} --color"
fi

# GNU ls colorizes with --color, BSD ls with -G, and passing the wrong one to an
# old BSD ls is fatal rather than ignored. dircolors ships with GNU coreutils,
# so having it already tells us which ls this is, for free.
if (( $+commands[dircolors] )); then
  [[ "$aliases[ls]" == *(--color|-G)* ]] || alias ls="${aliases[ls]:-ls} --color=auto"
  if zstyle -t ':z1:color' cache; then
    cached-eval dircolors --sh
  else
    source <(dircolors --sh)
  fi
else
  # -G is BSD ls's own spelling, and says nothing about a replacement someone
  # aliased in: eza reads -G as --grid. So go by what the alias actually runs,
  # since replacements do understand --color=auto.
  if [[ "$aliases[ls]" != *(--color|-G)* ]]; then
    if [[ "${${aliases[ls]:-ls}%% *}" == ls ]]; then
      alias ls="${aliases[ls]:-ls} -G"
    else
      alias ls="${aliases[ls]} --color=auto"
    fi
  fi

  export CLICOLOR=${CLICOLOR:-1}
  export LSCOLORS=${LSCOLORS:-exfxcxdxbxGxDxabagacad}
fi

# Pick a reasonable default for LS_COLORS if it hasn't been set by this point.
export LS_COLORS="${LS_COLORS:-di=34:ln=35:so=32:pi=33:ex=31:bd=1;36:cd=1;33:su=30;41:sg=30;46:tw=30;42:ow=30;43}"

# Colorize completions.
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

#
# Directory
#

# 16.2.1 Changing Directories
setopt auto_pushd              # Make cd push the old directory onto the dirstack.
setopt pushd_ignore_dups       # Don’t push multiple copies of the same directory onto the dirstack.
setopt pushd_minus             # Exchanges meanings of +/- when navigating the dirstack.
setopt pushd_silent            # Do not print the directory stack after pushd or popd.
setopt pushd_to_home           # Push to home directory when no argument is given.

# Set directory aliases.
alias -- -='cd -'
alias dirh='dirs -v'

#
# Compstyles
#

# Display: menu select, grouped output, descriptions and warnings highlighted.
zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''
zstyle ':completion:*' verbose yes
zstyle ':completion:*:matches' group 'yes'
zstyle ':completion:*:descriptions' format ' %F{magenta}-- %d --%f'
zstyle ':completion:*:warnings' format ' %F{yellow}-- no matches found --%f'

# Case-insensitive, then partial-word, then substring matching.
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# Path completion polish.
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' special-dirs ..

#
# Completion
#

# 16.2.2 Completion
setopt always_to_end           # Move cursor to the end of a completed word.
setopt auto_list               # Automatically list choices on ambiguous completion.
setopt auto_menu               # Show completion menu on a successive tab press.
setopt auto_param_slash        # If completed parameter is a directory, add a trailing slash.
setopt complete_in_word        # Complete from both ends of a word.
setopt path_dirs               # Perform path search even on command names with slashes.
setopt NO_menu_complete        # Do not autoselect the first completion entry.
setopt NO_list_beep            # Do not beep on ambiguous completion

# Load modules
zmodload zsh/complist

# Lazy-load my completions
fpath=($ZSH_CONFIG_DIR/completions(-/FN) $fpath)

# Location of the completion dumpfile. A ZSH_COMPDUMP set before we're sourced
# wins, otherwise a zstyle, otherwise a versioned file in the cache dir:
#   zstyle ':z1:compinit' dumpfile "$ZSH_CACHE_DIR/zcompdump"
typeset -g ZSH_COMPDUMP
if [[ -z "$ZSH_COMPDUMP" ]]; then
  zstyle -s ':z1:compinit' dumpfile ZSH_COMPDUMP ||
    ZSH_COMPDUMP=$ZSH_CACHE_DIR/ZSH_COMPDUMP-${ZSH_VERSION}
fi

# Queue compdef calls until the real compinit runs at the end of .zshrc.
typeset -gHa __compdef_queue=()
function compdef() {
  (( $# )) && __compdef_queue+=("${(j: :)${(@q+)@}}")
}

# Print the completion directories compaudit objects to, and how to fix them.
# Backgrounded by compinit, because the alternative is compinit stopping to ask,
# which a shell with no terminal cannot answer.
function z1-compaudit-warn() {
  emulate -L zsh
  autoload -Uz compaudit

  local -a insecure=(${(f)"$(compaudit 2>/dev/null)"})
  (( $#insecure )) || return 0

  print -u2 "z1: ignoring insecure completion directories:"
  print -lu2 -- $insecure
  print -u2 "z1: fix them with: compaudit | xargs chmod g-w,o-w"
}

# Wrap compinit to replay our compdef queue when it's called. Caching the
# dumpfile skips most of compinit's work and makes startup much faster:
#   zstyle ':z1:compinit' cache 'yes'
# See ZSH_COMPDUMP above to move the dumpfile. Args are passed through to the
# real compinit and win over what we set, since a later -d beats an earlier one.
function compinit() {
  emulate -L zsh
  setopt local_options extended_glob

  # Load the real compinit so we can call it from this wrapper.
  unfunction compinit compdef
  autoload -Uz compinit

  # Running this elsewhere is fine, and means the post_zshrc hook has no work left.
  post_zshrc_hook=(${post_zshrc_hook:#compinit})

  # -i ignores insecure directories rather than prompting about them. Say so
  # afterwards instead, since a prompt during startup blocks a shell that has no
  # terminal to answer with, and tells a user with one nothing actionable.
  mkdir -p $ZSH_COMPDUMP:h
  if ! zstyle -t ':z1:compinit' cache; then
    compinit -i -d "$ZSH_COMPDUMP" "$@"
  else
    # A dumpfile built from a different fpath is missing whatever the new
    # entries provide, and an age check alone would hide that for 20 hours. So
    # record the fpath it was built from alongside it, and start over when that
    # moves. The stamp lives in its own file because `$(<file)` costs nothing,
    # while searching the dumpfile itself means forking grep on every startup.
    # Snapshot fpath first: compinit -i drops insecure directories from it, so
    # stamping afterwards would record something the next startup never matches,
    # and the cache would rebuild every time.
    local stampfile=$ZSH_COMPDUMP.fpath stamped= wanted="$fpath"
    [[ -r $stampfile ]] && stamped="$(<$stampfile)"
    if [[ "$wanted" != "$stamped" ]]; then
      command rm -f "$ZSH_COMPDUMP" "$ZSH_COMPDUMP.zwc"
    fi

    # -C skips the function check (and implies -i, the security check skip).
    if [[ -n $ZSH_COMPDUMP(#qNmh-20) ]]; then
      compinit -C -d "$ZSH_COMPDUMP" "$@"  # Take the fast path.
    else
      compinit -i -d "$ZSH_COMPDUMP" "$@"
      print -r -- "$wanted" >| $stampfile
      touch "$ZSH_COMPDUMP"  # Always reset the time when we take the slow path.
    fi

    # Recompile only if stale; atomic rename, safe under concurrent shells.
    autoload -Uz zrecompile
    zrecompile -q -p "$ZSH_COMPDUMP" &!
  fi

  z1-compaudit-warn &|

  local entry
  for entry in "${__compdef_queue[@]}"; do
    eval "compdef $entry"
  done
  unset __compdef_queue
}

#
# Jobs
#

# 16.2.7 Job Control
setopt auto_resume             # Attempt to resume existing job before creating a new process.
setopt long_list_jobs          # List jobs in the long format by default.
setopt notify                  # Report status of background jobs immediately.
setopt NO_bg_nice              # Don't run all background jobs at a lower priority.
setopt NO_check_jobs           # Don't report on jobs when shell exit.
setopt NO_hup                  # Don't kill jobs on shell exit.

#
# Hooks
#

# Zsh doesn't have a proper post_zshrc event, so we fake one by adding a run_post_zshrc
# function to the precmd event. That function only runs once, and then unregisters
# itself from precmd. If the user wants to (or needs to because it doesn't play well
# with a plugin), they can run it themselves manually at the very end of their .zshrc,
# and then it unregisters the precmd event.

# Define a variable to hold actions run during the post_zshrc event, and a flag
# recording whether the event has fired yet.
typeset -ga post_zshrc_hook
typeset -gi post_zshrc_done=0

# Add our new event.
function run_post_zshrc() {
  # Run anything attached to the post_zshrc hook
  local fn
  for fn in $post_zshrc_hook; do
    zstyle -t ':z1:post_zshrc' debug && print -u2 "post_zshrc is about to run: ${=fn}"
    "${=fn}"
  done

  # Now delete the precmd hook and drain the list so that this only runs once,
  # and doesn't keep running on every future precmd event. This function and its
  # list var stay defined so that add-post-zshrc-hook still works afterwards.
  post_zshrc_hook=()
  post_zshrc_done=1
  add-zsh-hook -d precmd run_post_zshrc
}

# Attach a function to the post_zshrc event. Adding one after the event already
# fired runs it immediately, rather than dropping it on the floor.
function add-post-zshrc-hook() {
  if (( ! post_zshrc_done )); then
    post_zshrc_hook+=("$@")
    return
  fi

  local fn
  for fn in "$@"; do
    zstyle -t ':z1:post_zshrc' debug && print -u2 "post_zshrc already ran: ${=fn}"
    "${=fn}"
  done
}

# Attach run_post_zshrc to built-in precmd.
autoload -U add-zsh-hook
add-zsh-hook precmd run_post_zshrc

#
# Prompt
#

# 16.2.8 Prompt
setopt prompt_subst            # Expand parameters in prompt variables

# Let the built-in prompt system find prompts: yours first, then any that shipped
# with z1. Both vanish when absent, so a lone z1.zsh file is fine. Starting the
# prompt system is left to you, since not everyone wants it:
#   autoload -Uz promptinit && promptinit
#   prompt z1
fpath=(
  $ZSH_CONFIG_DIR/prompts(-/FN)
  ${0:A:h}/prompts(-/FN)
  $fpath
)

# Set 2 space indent for each new level in a multi-line script. This can then be
# overridden by a prompt or plugin, but is a better default than Zsh's.
PS2='${${${(%):-%_}//[^ ]}// /  }    '

#
# Editor
#

# 16.2.12 Zle
setopt combining_chars         # Combine 0-len chars with base chars (eg: accents).
setopt NO_beep                 # Don't beep on error in line editor.
setopt NO_flow_control         # Allow ^Q/^S in zsh.

# Treat these characters as part of a word.
WORDCHARS='*?_-.[]~&;!#$%^(){}<>'

# Pick the keymap, vi or emacs:
[[ -n "$ZSH_BINDKEY" ]] || zstyle -s ':z1:editor' keymap ZSH_BINDKEY

bindkey -d
case "${ZSH_BINDKEY:=emacs}" in
  vi)    bindkey -v ;;
  emacs) bindkey -e ;;
  *)                ;;
esac

# Prefer terminal-reported key sequences when available.
zmodload zsh/terminfo 2>/dev/null

# Allow Ctrl+S/Ctrl+Q for shell editing.
if [[ -r ${TTY:-} && -w ${TTY:-} && $+commands[stty] == 1 ]]; then
  stty -ixon <"$TTY" >"$TTY"
fi

# Run bindkey across every keymap. With no args, prints mappings per keymap.
function bindkey-all() {
  local keymap=''
  for keymap in $(bindkey -l); do
    [[ "$#" -eq 0 ]] && printf "#### %s\n" "${keymap}" 1>&2
    bindkey -M "${keymap}" "$@"
  done
}

# Bind one widget to multiple key sequences; skip empties.
function bindkey-multiple() {
  local widget=$1 seq; shift
  for seq in "$@"; do
    [[ -n "$seq" ]] && bindkey "$seq" "$widget"
  done
}

# Block cursor in vi cmd mode, beam in insert/emacs. Pick your own per mode:
#   zstyle ':z1:editor:vicmd' cursor 'block'
#   zstyle ':z1:editor:viins' cursor 'line'
#   zstyle ':z1:editor:emacs' cursor 'underscore'
# Styles are block, underscore, and line, each also with a -blink suffix.
# Skip on terminals that don't grok DECSCUSR.
function update-cursor-style() {
  case $TERM in
    xterm*|rxvt*|tmux*|screen*) ;;
    *) [[ -z "$TMUX" ]] && return ;;
  esac

  # zle reports insert mode as `main`, which is viins under `bindkey -v` and the
  # emacs keymap otherwise. Name it for the mode so the styles read plainly.
  local mode=${KEYMAP:-main}
  if [[ $mode == main ]]; then
    [[ "$ZSH_BINDKEY" == vi ]] && mode=viins || mode=emacs
  fi

  local style
  if ! zstyle -s ":z1:editor:$mode" cursor style; then
    [[ $mode == vicmd ]] && style=block || style=line
  fi

  case $style in
    block-blink)      printf '\e[1 q' ;;
    block)            printf '\e[2 q' ;;
    underscore-blink) printf '\e[3 q' ;;
    underscore)       printf '\e[4 q' ;;
    line-blink)       printf '\e[5 q' ;;
    line)             printf '\e[6 q' ;;
  esac
}
zle -N update-cursor-style

# Enable terminal application mode so $terminfo key sequences are valid.
function zle-line-init() {
  (( $+terminfo[smkx] )) && echoti smkx
  zle update-cursor-style
}
zle -N zle-line-init

function zle-line-finish() {
  (( $+terminfo[rmkx] )) && echoti rmkx
}
zle -N zle-line-finish

function zle-keymap-select() {
  zle update-cursor-style
  zle reset-prompt
  zle -R
}
zle -N zle-keymap-select

# Insert 'sudo ' at the beginning of the line.
function prepend-sudo() {
  if [[ "$BUFFER" != su(do|)\ * ]]; then
    BUFFER="sudo $BUFFER"
    (( CURSOR += 5 ))
  fi
}
zle -N prepend-sudo

# Toggle a leading '#' on the current line. Workaround for buggy pound-insert
# in emacs mode; vi mode uses the built-in vi-pound-insert.
function pound-toggle() {
  if [[ "$BUFFER" = '#'* ]]; then
    [[ $CURSOR != $#BUFFER ]] && (( CURSOR -= 1 ))
    BUFFER="${BUFFER:1}"
  else
    BUFFER="#$BUFFER"
    (( CURSOR += 1 ))
  fi
}
zle -N pound-toggle

# Edit current command in $EDITOR.
autoload -Uz edit-command-line
zle -N edit-command-line

# Auto-quote URLs on paste and as you type (prevents ? and & from globbing).
autoload -Uz bracketed-paste-url-magic
zle -N bracketed-paste bracketed-paste-url-magic
autoload -Uz url-quote-magic
zle -N self-insert url-quote-magic

# Common terminal key fixes: terminfo first, xterm CSI fallbacks second.
bindkey-multiple beginning-of-line                 "${terminfo[khome]-}" '^[[H'
bindkey-multiple end-of-line                       "${terminfo[kend]-}"  '^[[F'
bindkey-multiple delete-char                       "${terminfo[kdch1]-}" '^[[3~'
bindkey-multiple history-beginning-search-backward "${terminfo[kcuu1]-}" '^[[A'
bindkey-multiple history-beginning-search-forward  "${terminfo[kcud1]-}" '^[[B'
bindkey-multiple backward-word                     '^[[1;3D' '^[[1;5D'   # Alt/Ctrl + Left
bindkey-multiple forward-word                      '^[[1;3C' '^[[1;5C'   # Alt/Ctrl + Right

# Backspace and word deletion.
bindkey '^?' backward-delete-char
bindkey '^W' backward-kill-word

# Edit command in $EDITOR.
bindkey '^X^E' edit-command-line

# Toggle comment at start of line. Alt-; in emacs, # in vi cmd mode.
bindkey -M emacs '^[;' pound-toggle
bindkey -M vicmd '#' vi-pound-insert

# Prepend sudo with Alt-s.
bindkey -M emacs '^[s' prepend-sudo
bindkey -M viins '^[s' prepend-sudo

#
# Utility
#

# Replace the stub run-help (aliased to man) with the real autoload version.
(( $+aliases[run-help] )) && unalias run-help
autoload -Uz run-help
alias help=run-help

# Fill in commands everyone expects but not every platform ships, so the same
# config works on a Mac laptop and whatever the server is running.
if (( ! $+commands[open] )); then
  if [[ "$OSTYPE" == cygwin* ]]; then
    alias open='cygstart'
  elif [[ "$OSTYPE" == linux-android ]]; then
    alias open='termux-open'
  elif (( $+commands[xdg-open] )); then
    alias open='xdg-open'
  fi
fi

if (( ! $+commands[pbcopy] )); then
  if [[ "$OSTYPE" == cygwin* ]]; then
    alias pbcopy='tee > /dev/clipboard'
    alias pbpaste='cat /dev/clipboard'
  elif [[ "$OSTYPE" == linux-android ]]; then
    alias pbcopy='termux-clipboard-set'
    alias pbpaste='termux-clipboard-get'
  elif (( $+commands[wl-copy] && $+commands[wl-paste] )); then
    alias pbcopy='wl-copy'
    alias pbpaste='wl-paste'
  elif [[ -n "$DISPLAY" ]] && (( $+commands[xclip] )); then
    alias pbcopy='xclip -selection clipboard -in'
    alias pbpaste='xclip -selection clipboard -out'
  elif [[ -n "$DISPLAY" ]] && (( $+commands[xsel] )); then
    alias pbcopy='xsel --clipboard --input'
    alias pbpaste='xsel --clipboard --output'
  fi
fi

if (( ! $+commands[hd] )) && (( $+commands[hexdump] )); then
  alias hd='hexdump -C'
fi

# Lazy-load my functions.
ZFUNCDIR=${ZFUNCDIR:-$ZSH_CONFIG_DIR/functions}
for _zfndir in $ZFUNCDIR(-/FN) $ZFUNCDIR/*(-/FN); do
  fpath=($_zfndir $fpath)
  autoload -Uz $_zfndir/*~*/_*(N.:t)
done
unset _zfndir

#
# Conf.d
#

# Source everything in a Fish-like conf.d directory, in name order. Files
# starting with '~' are skipped, so you can park one without deleting it. Point
# it somewhere else with:
#   zstyle ':z1:confd' directory "$ZSH_CONFIG_DIR/rc.d"
# No `emulate -L`/`local_options` here on purpose. These are config files, so
# whatever they setopt has to outlive this function.
function run_confd() {
  local confd
  zstyle -s ':z1:confd' directory confd || confd=$ZSH_CONFIG_DIR/conf.d

  # Running this elsewhere is fine, and means the post_zshrc hook has no work left.
  post_zshrc_hook=(${post_zshrc_hook:#run_confd})

  local rc
  local -a rcs=(${~confd}/*.{z,}sh(N-.))
  for rc in ${(o)rcs}; do
    [[ "${rc:t}" == '~'* ]] || source "$rc"
  done
}

# Register functions to run at the end of .zshrc. Each function here runs in order,
# and should unregister itself from the post_zshrc_hook if it runs early.
add-post-zshrc-hook run_confd
add-post-zshrc-hook compinit
