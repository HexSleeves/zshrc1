#!/usr/bin/env bats
# The faked post_zshrc event: a precmd hook that fires once and removes itself.

load helpers/common

setup() { z1_setup; }
teardown() { z1_teardown; }

@test "hooks run on the event, in the order added" {
  z1_zsh <<'EOS'
source $Z1
typeset -ga FIRED=()
first() { FIRED+=(first) }
second() { FIRED+=(second) }
add-post-zshrc-hook first
add-post-zshrc-hook second
print "before: $FIRED"
run_post_zshrc
print "after: $FIRED"
EOS
  assert_success
  assert_line "before: "
  assert_line "after: first second"
}

@test "the event fires once and unregisters itself from precmd" {
  z1_zsh <<'EOS'
source $Z1
typeset -gi COUNT=0
bump() { (( COUNT++ )) }
add-post-zshrc-hook bump
run_post_zshrc
print "once: $COUNT"
run_post_zshrc
print "twice: $COUNT"
(( $precmd_functions[(I)run_post_zshrc] )) && print "precmd: still" || print "precmd: gone"
EOS
  assert_success
  assert_line "once: 1"
  assert_line "twice: 1"
  assert_line "precmd: gone"
}

@test "a hook added after the event has fired runs immediately" {
  z1_zsh <<'EOS'
source $Z1
run_post_zshrc
typeset -gi COUNT=0
bump() { (( COUNT++ )) }
print "done: $post_zshrc_done"
add-post-zshrc-hook bump
print "count: $COUNT"
EOS
  assert_success
  assert_line "done: 1"
  assert_line "count: 1"
}

@test "run_post_zshrc is registered as a precmd hook on load" {
  z1_zsh <<'EOS'
source $Z1
(( $precmd_functions[(I)run_post_zshrc] )) && print "precmd: yes" || print "precmd: no"
print "done: $post_zshrc_done"
EOS
  assert_success
  assert_line "precmd: yes"
  assert_line "done: 0"
}
