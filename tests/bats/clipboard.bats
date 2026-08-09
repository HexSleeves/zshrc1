#!/usr/bin/env bats
# Clipboard helpers: copyfile, copypath, and the copybuffer widget.

load helpers/common

setup() {
  z1_setup
  # Every test needs somewhere for the clipboard to land. The stub shadows a
  # real pbcopy, so the suite never touches the machine's own clipboard.
  stub_command pbcopy 'cat >$HOME/clip.txt'
}
teardown() { z1_teardown; }

@test "copyfile copies a file's contents" {
  write_file "$TEST_HOME/note.txt" "hello" "there"
  z1_zsh 'source $Z1
    copyfile $HOME/note.txt
    print "rc: $?"
    print "clip: ${(j:|:)${(f)$(<$HOME/clip.txt)}}"'
  assert_success
  assert_line "rc: 0"
  assert_line "clip: hello|there"
}

@test "copyfile takes a relative path" {
  write_file "$TEST_HOME/note.txt" "hello"
  z1_zsh 'source $Z1
    builtin cd $HOME
    copyfile note.txt
    print "clip: $(<$HOME/clip.txt)"'
  assert_success
  assert_line "clip: hello"
}

# A missing file, a directory, and no argument at all are the same mistake, and
# none of them should leave the clipboard holding something unexpected.
@test "copyfile refuses anything that is not a file" {
  z1_zsh 'source $Z1
    copyfile $HOME/nope.txt
    print "missing: $?"
    copyfile $HOME
    print "dir: $?"
    copyfile
    print "empty: $?"
    [[ -f $HOME/clip.txt ]] && print "clip: written" || print "clip: untouched"'
  assert_success
  assert_line "copyfile: not a file: $TEST_HOME/nope.txt"
  assert_line "missing: 1"
  assert_line "copyfile: not a file: $TEST_HOME"
  assert_line "dir: 1"
  assert_line "copyfile: not a file: "
  assert_line "empty: 1"
  assert_line "clip: untouched"
}

# The point of copypath is pasting a path somewhere else, so what lands on the
# clipboard has to be absolute and free of . and .. no matter how it was typed.
@test "copypath makes a relative path absolute" {
  write_file "$TEST_HOME/sub/note.txt" "hello"
  z1_zsh 'source $Z1
    builtin cd $HOME/sub
    copypath ../sub/note.txt
    print "clip: $(<$HOME/clip.txt)"'
  assert_success
  assert_line "clip: $TEST_HOME/sub/note.txt"
}

@test "copypath defaults to the current directory" {
  z1_zsh 'source $Z1
    builtin cd $HOME
    copypath
    print "clip: $(<$HOME/clip.txt)"'
  assert_success
  assert_line "clip: $TEST_HOME"
}

# No trailing newline, or pasting the path into a shell runs it.
@test "copypath copies the path alone" {
  z1_zsh 'source $Z1
    builtin cd $HOME
    copypath
    print "bytes: $(( $(wc -c <$HOME/clip.txt) ))"
    print "want: ${#HOME}"'
  assert_success
  assert_line "want: ${#TEST_HOME}"
  assert_line "bytes: ${#TEST_HOME}"
}

@test "copypath names a path that does not exist yet" {
  z1_zsh 'source $Z1
    builtin cd $HOME
    copypath nothing-here.txt
    print "clip: $(<$HOME/clip.txt)"'
  assert_success
  assert_line "clip: $TEST_HOME/nothing-here.txt"
}

# copybuffer only calls zle on the error path, so the copy itself can be
# checked without a line editor.
@test "copybuffer copies the line being edited" {
  z1_zsh 'source $Z1
    PREBUFFER="" BUFFER="echo hi"
    copybuffer
    print "clip: [$(<$HOME/clip.txt)]"'
  assert_success
  assert_line "clip: [echo hi]"
}

# A half-typed multi-line command has its finished lines in $PREBUFFER, and
# copying only $BUFFER would hand back the last line on its own.
@test "copybuffer includes PS2 continuation lines" {
  z1_zsh 'source $Z1
    PREBUFFER="function foo {
" BUFFER="  echo bar"
    copybuffer
    print "clip: ${(j:|:)${(f)$(<$HOME/clip.txt)}}"'
  assert_success
  assert_line "clip: function foo {|  echo bar"
}

# With no clipboard command anywhere, the widget says so on the status line
# rather than printing an error over the prompt.
@test "copybuffer reports a missing pbcopy" {
  z1_zsh 'source $Z1
    mkdir -p $HOME/empty
    path=($HOME/empty) && rehash
    unalias pbcopy 2>/dev/null
    zle() { print "zle: $*" }
    copybuffer
    print "rc: $?"'
  assert_success
  assert_line "zle: -M copybuffer: pbcopy not found"
  assert_line "rc: 1"
}

@test "the copybuffer widget exists" {
  z1_zsh 'source $Z1; print "widget: ${widgets[copybuffer]}"'
  assert_success
  assert_line "widget: user:copybuffer"
}

# Ctrl+X Ctrl+C has to be bound in each keymap by name: vi insert mode is
# `main` but not `emacs`, and vicmd shares nothing with either.
@test "Ctrl+X Ctrl+C copies the line in every keymap" {
  z1_zsh 'source $Z1
    print "emacs: $(bindkey -M emacs "^X^C")"
    print "viins: $(bindkey -M viins "^X^C")"
    print "vicmd: $(bindkey -M vicmd "^X^C")"'
  assert_success
  assert_line 'emacs: "^X^C" copybuffer'
  assert_line 'viins: "^X^C" copybuffer'
  assert_line 'vicmd: "^X^C" copybuffer'
}

# Ctrl+O is accept-line-and-down-history, which other configs take for this.
@test "Ctrl+O keeps its usual widget" {
  z1_zsh 'source $Z1; print "emacs: $(bindkey -M emacs "^O")"'
  assert_success
  assert_line 'emacs: "^O" accept-line-and-down-history'
}
