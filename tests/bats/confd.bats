#!/usr/bin/env bats
# conf.d: Fish-like config directory, sourced on the post_zshrc event.

load helpers/common

setup() {
  z1_setup
  CONFD="$TEST_HOME/.config/zsh/conf.d"
}
teardown() { z1_teardown; }

@test "conf.d is deferred until post_zshrc, then runs once" {
  write_file "$CONFD/10-a.zsh" 'print x >>! $HOME/runs'

  z1_zsh <<'EOS'
source $Z1
[[ -f $HOME/runs ]] && print "early: yes" || print "early: no"
run_post_zshrc
print "after: $(wc -l <$HOME/runs | tr -d ' ')"
run_post_zshrc
print "twice: $(wc -l <$HOME/runs | tr -d ' ')"
EOS
  assert_success
  assert_line "early: no"
  assert_line "after: 1"
  assert_line "twice: 1"
}

@test "files load in name order regardless of extension" {
  write_file "$CONFD/05-z.sh" 'ORDER+=(05-z.sh)'
  write_file "$CONFD/10-a.zsh" 'ORDER+=(10-a.zsh)'
  write_file "$CONFD/20-b.sh" 'ORDER+=(20-b.sh)'
  write_file "$CONFD/30-c.zsh" 'ORDER+=(30-c.zsh)'

  z1_zsh <<'EOS'
typeset -ga ORDER=()
source $Z1
run_confd
print "order: $ORDER"
EOS
  assert_success
  assert_line "order: 05-z.sh 10-a.zsh 20-b.sh 30-c.zsh"
}

@test "files starting with ~ are skipped" {
  write_file "$CONFD/10-on.zsh" 'LOADED+=(on)'
  write_file "$CONFD/~20-off.zsh" 'LOADED+=(off)'

  z1_zsh <<'EOS'
typeset -ga LOADED=()
source $Z1
run_confd
print "loaded: $LOADED"
EOS
  assert_success
  assert_line "loaded: on"
}

@test "symlinked files load, but directories and broken links do not" {
  write_file "$CONFD/10-plain.zsh" 'LOADED+=(plain)'
  write_file "$TEST_HOME/elsewhere/target.zsh" 'LOADED+=(linked)'
  ln -s "$TEST_HOME/elsewhere/target.zsh" "$CONFD/20-link.zsh"
  mkdir -p "$TEST_HOME/elsewhere/adir.zsh"
  ln -s "$TEST_HOME/elsewhere/adir.zsh" "$CONFD/30-dirlink.zsh"
  mkdir -p "$CONFD/40-realdir.zsh"
  ln -s "$TEST_HOME/gone.zsh" "$CONFD/50-broken.zsh"

  z1_zsh <<'EOS'
typeset -ga LOADED=()
source $Z1
run_confd
print "loaded: $LOADED"
EOS
  assert_success
  assert_line "loaded: plain linked"
}

# The reason run_confd deliberately skips `emulate -L`: these are config files,
# so what they set has to outlive the function that sourced them.
@test "setopts, aliases and variables set in conf.d survive" {
  write_file "$CONFD/10-opts.zsh" \
    'setopt cdable_vars' \
    'alias confdalias=true' \
    'CONFD_VAR=kept'

  z1_zsh <<'EOS'
source $Z1
run_confd
[[ -o cdable_vars ]] && print "setopt: kept" || print "setopt: lost"
(( $+aliases[confdalias] )) && print "alias: kept" || print "alias: lost"
print "var: $CONFD_VAR"
EOS
  assert_success
  assert_line "setopt: kept"
  assert_line "alias: kept"
  assert_line "var: kept"
}

@test "running run_confd by hand unregisters the post_zshrc hook" {
  write_file "$CONFD/10-a.zsh" 'print x >>! $HOME/runs'

  z1_zsh <<'EOS'
source $Z1
(( $post_zshrc_hook[(I)run_confd] )) && print "registered: yes" || print "registered: no"
run_confd
(( $post_zshrc_hook[(I)run_confd] )) && print "still: yes" || print "still: no"
run_post_zshrc
print "runs: $(wc -l <$HOME/runs | tr -d ' ')"
EOS
  assert_success
  assert_line "registered: yes"
  assert_line "still: no"
  assert_line "runs: 1"
}

@test "the directory zstyle moves conf.d" {
  write_file "$CONFD/10-default.zsh" 'LOADED+=(default)'
  write_file "$TEST_HOME/.config/zsh/rc.d/10-custom.zsh" 'LOADED+=(custom)'

  z1_zsh <<'EOS'
typeset -ga LOADED=()
zstyle ':z1:confd' directory "$ZDOTDIR/rc.d"
source $Z1
run_confd
print "loaded: $LOADED"
EOS
  assert_success
  assert_line "loaded: custom"
}

@test "the skip zstyle unregisters the hook but keeps run_confd callable" {
  write_file "$CONFD/10-a.zsh" 'LOADED+=(a)'

  z1_zsh <<'EOS'
typeset -ga LOADED=()
zstyle ':z1:confd' skip 'yes'
source $Z1
(( $post_zshrc_hook[(I)run_confd] )) && print "registered: yes" || print "registered: no"
run_post_zshrc
print "auto: $LOADED"
run_confd
print "byhand: $LOADED"
EOS
  assert_success
  assert_line "registered: no"
  assert_line "auto: "
  assert_line "byhand: a"
}

@test "a missing conf.d directory is not an error" {
  z1_zsh <<'EOS'
source $Z1
run_confd
print "rc: $?"
EOS
  assert_success
  assert_line "rc: 0"
}
