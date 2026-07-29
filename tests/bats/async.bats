#!/usr/bin/env bats
# lib/async.zsh runs tasks off the prompt's critical path. zle -F cannot fire
# outside an interactive session, so these drive the cycle with async-wait,
# which collects the same way the zle handler would.

load helpers/common

setup() { z1_setup; }
teardown() { z1_teardown; }

@test "a task's output lands in async_output" {
  z1_zsh 'source ${Z1:h}/lib/async.zsh
    function slow { print -n "the-answer" }
    async-task job slow
    print "before: [${async_output[job]}]"
    async-run; async-wait
    print "after: [${async_output[job]}]"'
  assert_success
  assert_line "before: []"
  assert_line "after: [the-answer]"
}

@test "the task really runs in the background" {
  z1_zsh 'source ${Z1:h}/lib/async.zsh
    function slow { sleep 2; print -n late }
    async-task job slow
    typeset -F SECONDS=0
    async-run
    print "returned after: $(( SECONDS < 1 ))"
    print "still empty: [${async_output[job]}]"'
  assert_success
  assert_line "returned after: 1"
  assert_line "still empty: []"
}

@test "several tasks run at once" {
  z1_zsh 'source ${Z1:h}/lib/async.zsh
    function one { print -n first }
    function two { print -n second }
    async-task a one
    async-task b two
    async-run; async-wait
    print "a: ${async_output[a]}"
    print "b: ${async_output[b]}"'
  assert_success
  assert_line "a: first"
  assert_line "b: second"
}

@test "descriptors are released after collection" {
  z1_zsh 'source ${Z1:h}/lib/async.zsh
    function slow { print -n x }
    async-task job slow
    async-run
    print "running: $(( async_fds[job] != -1 ))"
    async-wait
    print "released: $(( async_fds[job] == -1 ))"'
  assert_success
  assert_line "running: 1"
  assert_line "released: 1"
}

# A task still going when the next prompt arrives is killed, so a slow repo
# cannot pile up jobs.
@test "a pending task is cancelled by the next run" {
  z1_zsh 'source ${Z1:h}/lib/async.zsh
    function slow { sleep 5; print -n never }
    async-task job slow
    async-run
    pid=$async_pids[job]
    async-run
    sleep 0.3
    kill -0 $pid 2>/dev/null && print "old job: alive" || print "old job: gone"'
  assert_success
  assert_line "old job: gone"
}

@test "a task that prints nothing leaves an empty result" {
  z1_zsh 'source ${Z1:h}/lib/async.zsh
    function quiet { : }
    async-task job quiet
    async-run; async-wait
    print "output: [${async_output[job]}]"
    print "released: $(( async_fds[job] == -1 ))"'
  assert_success
  assert_line "output: []"
  assert_line "released: 1"
}

@test "multi-line output survives intact" {
  z1_zsh 'source ${Z1:h}/lib/async.zsh
    function multi { print "one"; print "two" }
    async-task job multi
    async-run; async-wait
    print "lines: ${(f)#async_output[job]}"
    print "raw: ${async_output[job]//$'"'"'\n'"'"'/|}"'
  assert_success
  assert_line "raw: one|two|"
}

@test "untasking stops the task and drops its output" {
  z1_zsh 'source ${Z1:h}/lib/async.zsh
    function slow { print -n x }
    async-task job slow
    async-run; async-wait
    async-untask job
    print "tasks: ${#async_tasks}"
    print "output key: ${+async_output[job]}"
    print "precmd hook: $(( ${precmd_functions[(I)async-run]:-0} ))"'
  assert_success
  assert_line "tasks: 0"
  assert_line "output key: 0"
  assert_line "precmd hook: 0"
}

@test "registering requires a function that exists" {
  z1_zsh 'source ${Z1:h}/lib/async.zsh
    async-task job nosuchfunction
    print "rc: $?"
    async-task job
    print "arity: $?"
    print "tasks: ${#async_tasks}"'
  assert_success
  assert_line "rc: 1"
  assert_line "arity: 1"
  assert_line "tasks: 0"
}

@test "async-run is hooked to precmd once" {
  z1_zsh 'source ${Z1:h}/lib/async.zsh
    function a { : }; function b { : }
    async-task one a
    async-task two b
    hooks=(${(M)precmd_functions:#async-run})
    print "hooks: $#hooks"'
  assert_success
  assert_line "hooks: 1"
}
