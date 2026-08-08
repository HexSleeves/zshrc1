#!/usr/bin/env zsh
# async - run slow things off the prompt's critical path.
#
#   source /path/to/lib/async.zsh
#   function slow_thing { git status --short }
#   async-task vcs slow_thing
#   RPROMPT='$async_output[vcs]'
#
# Each registered task runs in a background job before every prompt. Its stdout
# lands in $async_output[<name>], and the prompt is redrawn when that changes.
# A task still running when the next prompt arrives is killed and restarted.

zmodload zsh/system

typeset -gA async_output async_fds async_pids async_tasks

# Register a function to run before each prompt. Its output shows up in
# $async_output[<name>].
function async-task() {
  emulate -L zsh
  (( $# == 2 )) || return 1
  (( $+functions[$2] )) || return 1

  async_tasks[$1]=$2
  async_output[$1]=${async_output[$1]:-}

  autoload -Uz add-zsh-hook
  add-zsh-hook precmd async-run
}

# Forget a task, and drop whatever it last produced.
function async-untask() {
  emulate -L zsh
  (( $# )) || return 1

  async-cancel $1
  unset "async_tasks[$1]" "async_output[$1]"
  (( $#async_tasks )) || add-zsh-hook -d precmd async-run
}

# Kill a task that is still running, and let go of its descriptor.
function async-cancel() {
  emulate -L zsh
  local name=$1
  local fd=${async_fds[$name]:--1} pid=${async_pids[$name]:--1}

  if (( fd != -1 )) && { true <&$fd } 2>/dev/null; then
    exec {fd}<&-
    zle -F $fd 2>/dev/null
    # With job control the child has its own process group, so signal the group
    # to catch anything it forked.
    if (( pid != -1 )); then
      [[ -o monitor ]] && kill -TERM -$pid 2>/dev/null || kill -TERM $pid 2>/dev/null
    fi
  fi

  async_fds[$name]=-1
  async_pids[$name]=-1
}

# Start every registered task. Runs on precmd.
function async-run() {
  emulate -L zsh
  local ret=$?
  local name fd

  for name in ${(k)async_tasks}; do
    (( $+functions[${async_tasks[$name]}] )) || continue
    async-cancel $name

    exec {fd}< <(
      builtin print -r -- ${sysparams[pid]}
      () { return $ret }
      ${async_tasks[$name]}
    )
    async_fds[$name]=$fd

    # Forces a fork, without which ^C stops working on zsh below 5.8.
    autoload -Uz is-at-least
    is-at-least 5.8 || command true

    read -u $fd "async_pids[$name]"
    zle -F $fd async-collect 2>/dev/null
  done
}

# Read a finished task and redraw. zle calls this with the ready descriptor;
# call it yourself to collect without zle.
function async-collect() {
  emulate -L zsh
  local fd=$1 err=$2
  local name="${(k)async_fds[(r)$fd]}"

  if [[ -z "$name" ]]; then
    zle -F $fd 2>/dev/null
    return 1
  fi

  if [[ -z "$err" || "$err" == hup ]]; then
    local previous="${async_output[$name]}"

    # sysread, not `read -d ''`: reading to a delimiter makes zsh write the
    # terminal settings, which stops the shell with SIGTTOU whenever it is not
    # in the foreground process group.
    local chunk collected=
    while sysread -i $fd chunk; do
      collected+=$chunk
    done
    async_output[$name]=$collected

    # Only meaningful inside zle, which is where the fd handler normally runs.
    if [[ "$previous" != "${async_output[$name]}" ]]; then
      zle .reset-prompt 2>/dev/null && zle -R 2>/dev/null
    fi
    exec {fd}<&-
  fi

  zle -F $fd 2>/dev/null
  async_fds[$name]=-1
  async_pids[$name]=-1
}

# Run every pending task to completion. Useful in scripts and tests, where
# there is no zle to call async-collect for us.
function async-wait() {
  emulate -L zsh
  local name fd

  for name in ${(k)async_fds}; do
    fd=${async_fds[$name]:--1}
    (( fd == -1 )) && continue
    async-collect $fd
  done
}
