# z1

[![MIT License](https://img.shields.io/badge/license-MIT-007EC7.svg)](/LICENSE)
![version](https://img.shields.io/badge/version-v2.0.1-orange)

> First things first - start your .zshrc off right

## Description

`z1` is designed to be a portable, lightweight, ultra-fast, Zsh configuration in a
single file. Equally useful on your desktop machine or on a remote server, z1 enables
much of the useful functionality already built into Zsh without the need for frameworks.
And, it's ridiculously fast!

`z1`'s goal of giving you a great starter DIY Zsh experience in a single file stands in
contrast to other full Zsh Frameworks like [Oh-My-Zsh][ohmyzsh] and [Prezto][prezto].
Those frameworks are nice if you want everything-and-the-kitchen-sink, but you pay a
performance and complexity penalty for using these frameworks.

Many prefer to build their own Zsh config from scratch, but that can be a lot of work
and often requires you to pull together functionality already baked into the Zsh
frameworks you leave behind.

`z1` is simpler. Similar to [Grml's .zshrc][grml-zshrc], `z1` gives you everything you
need for a full-featured Zsh config, but contained in one simple to grok Zsh include
that will grow with you as you use Zsh. It is heavily inspired by the [Fish
shell][fish].

Feel free to use it as-is, build off it, or fork it and make it entirely your own.

## Features

- Set common Zsh environment variables
- Enable better Zsh options than the defaults
- Set better Zsh history options and variables
- Colorize output of commands like `ls`, `grep`, `diff`, and `man`
- Sensible line editor setup with vi/emacs keymap selection, cursor-style hints, and
  common terminal key fixes
- Useful zle widgets like `prepend-sudo`, `pound-toggle`, `edit-command-line`, paste
  magic, and quote magic
- Configure Zsh built-in completion system with cached `compinit` for fast startup
- Use built-in Zsh prompt system, with prompts found in your own `prompts/` directory
- Initialize Homebrew automatically when present
- Every decision is reversible: z1 only uses plain Zsh builtins, so anything it sets can
  be changed or undone after you source it. `unsetopt` an option, `unalias` an alias,
  rebind a key. Values you already exported win, and zstyles let you opt out ahead of
  time

## Installation

Clone `z1` and source it from your `.zshrc`:

```zsh
git clone https://github.com/mattmc3/z1 ${ZDOTDIR:-$HOME}/.z1
```

```zsh
# .zshrc
source ${ZDOTDIR:-$HOME}/.z1/z1.zsh
```

Or download the single `z1.zsh` file and make it your own.

```zsh
curl -fsSL https://raw.githubusercontent.com/mattmc3/z1/main/z1.zsh -o ${ZDOTDIR:-$HOME}/z1.zsh
```

```zsh
# .zshrc
source ${ZDOTDIR:-$HOME}/z1.zsh
```

Or use a Zsh plugin manager, which will load `z1.plugin.zsh` for you. With
[antidote][antidote]:

```zsh
# .zsh_plugins.txt
mattmc3/z1
```

Or, using dynamic plugins without a .zsh_plugins.txt file:

```zsh
# .zshrc
source <(antidote init)
antidote bundle mattmc3/z1
```

Since `z1` sets up the basics everything else builds on, list it first.

## Configuration

`z1` is configured with zstyles. Set them in `$ZDOTDIR/.zstyles`, which `z1` sources
before it reads any style of its own, so that one file is enough. `.zshrc` before the
`source` line works too, and is the only option for the handful of things noted below.

| Context                      | Style          | Default                                    | What it does                                                      |
| ---------------------------- | -------------- | ------------------------------------------ | ----------------------------------------------------------------- |
| `:z1:color`                  | `cache`        | off                                        | Cache `dircolors --sh` output rather than running it each startup |
| `:z1:compinit`               | `cache`        | off                                        | Cache the completion dumpfile and take `compinit`'s fast path     |
| `:z1:compinit`               | `dumpfile`     | `$ZSH_CACHE_DIR/ZSH_COMPDUMP-$ZSH_VERSION` | Where the completion dumpfile lives                               |
| `:z1:compinit`               | `skip`         | off                                        | Leave `compinit` and `compdef` alone. No wrappers, no auto-run    |
| `:z1:confd`                  | `directory`    | `$ZSH_CONFIG_DIR/conf.d`                   | Directory of config files to source at the end of your `.zshrc`   |
| `:z1:confd`                  | `skip`         | off                                        | Never source `conf.d`. `run_confd` still works when called        |
| `:z1:editor`                 | `expand-alias` | off                                        | Bind space and enter to expand the alias you just typed           |
| `:z1:editor`                 | `keymap`       | `emacs`                                    | Line editor keymap. Set it to `vi` for vi mode                    |
| `:z1:editor:default-command` | `command`      | none                                       | Run this when you press Enter on an empty line                    |
| `:z1:editor:default-command` | `git-command`  | none                                       | Same, but inside a git checkout                                   |
| `:z1:editor:default-command` | `jj-command`   | none                                       | Same, but inside a jj workspace                                   |
| `:z1:editor:emacs`           | `cursor`       | `line`                                     | Cursor shape in emacs mode                                        |
| `:z1:editor:expand-alias`    | `exclude`      | none                                       | Words `expand-alias` never expands                                |
| `:z1:editor:expand-alias`    | `include`      | none                                       | Words `expand-alias` always expands                               |
| `:z1:editor:vicmd`           | `cursor`       | `block`                                    | Cursor shape in vi command mode                                   |
| `:z1:editor:viins`           | `cursor`       | `line`                                     | Cursor shape in vi insert mode                                    |
| `:z1:history`                | `histfile`     | `$ZSH_DATA_DIR/zsh_history`                | Where history is written                                          |
| `:z1:history`                | `histsize`     | `50000`                                    | Events kept in the current session                                |
| `:z1:history`                | `savehist`     | `100000`                                   | Events kept in the history file                                   |
| `:z1:homebrew`               | `cache`        | off                                        | Cache `brew shellenv` output rather than running it each startup  |
| `:z1:homebrew`               | `skip`         | off                                        | Never run `brew shellenv`, for when you have run it yourself      |
| `:z1:path`                   | `prepath`      | `~/{s,}bin ~/.local/{s,}bin`               | Entries kept at the front of `$path`                              |
| `:z1:xdg-basedirs`           | `enable`       | on                                         | Put config, data, and cache in the XDG directories                |
| `:z1:zfunctions`             | `skip`         | off                                        | Leave `$ZFUNCDIR` off `fpath` and autoload nothing from it        |
| `:z1:zstyles`                | `loaded`       | off                                        | Set it yourself to stop `z1` sourcing your `.zstyles`             |
| `:z1:zstyles`                | `skip`         | off                                        | Never source your `.zstyles`, and don't mark them loaded          |

Of the `prepath` defaults, only the directories that exist are used. Cursor shapes are
`block`, `underscore`, and `line`, each also with a `-blink` suffix, and are only
emitted on terminals that understand DECSCUSR.

Similar to Fish abbreviations, with `expand-alias` on, space and enter replace the alias
you just typed with what it aliased, so the line shows the command that will run.
Alt-Space inserts a space without expanding. The `expand-alias-space` widget exists
either way, so you can bind it yourself instead.

Global aliases always expand. A plain alias only expands when its name isn't also a
command, so `ls='ls --color=auto'` stays readable. `include` overrides that for aliases
you do want expanded, like `vim='nvim'`, and `exclude` wins over both.

Enter on an empty line can run something for you, off until you name a command.
`git-command` and `jj-command` apply only inside a checkout and beat `command` there, jj
first so a colocated repo gets the jj one. The line is filled in with a leading space,
which `hist_ignore_space` keeps out of your history:

```zsh
# .zstyles
zstyle ':z1:editor:default-command' command 'ls'
zstyle ':z1:editor:default-command' git-command 'git status -sb'
```

Enter goes through a single wrapper widget that anything can hook, rather than each
feature replacing `accept-line` and clobbering whoever wrapped it first. Hooks run in
the order added, inside the widget, so `$BUFFER` and `$CURSOR` are yours to change. A
hook whose function has gone away is skipped, and `-d` takes one back off:

```zsh
function log-my-commands() { print -r -- "$BUFFER" >>~/.commands }
add-accept-line-hook log-my-commands
```

```zsh
# .zstyles
zstyle ':z1:history' savehist 500000
zstyle ':z1:confd' directory "$ZSH_CONFIG_DIR/rc.d"
```

Caching is off by default because a cache hides a change until it expires, after 20
hours. Every cache shares the style name `cache`, so one pattern turns them all on:

```zsh
zstyle ':z1:*' cache 'yes'
```

Use `cached-eval --clear` to empty the caches by hand, and `compinit`'s cache rebuilds
itself whenever `$fpath` changes.

Where `z1` wires itself into something that is properly yours, the style name is `skip`.
It covers the three places `z1` loads files for you (`.zstyles`, `$ZFUNCDIR`, and
`conf.d`), plus `compinit` and Homebrew, for when you would rather handle those
yourself:

```zsh
# .zstyles
zstyle ':z1:zfunctions' skip 'yes'
```

As with `cache`, one pattern covers all of them:

```zsh
zstyle ':z1:*' skip 'yes'
```

`:z1:zstyles` is the exception, since sourcing `.zstyles` is the thing it governs. That
one has to be in your `.zshrc` ahead of the `source` line, along with `$ZSTYLESFILE` if
you keep the file somewhere else:

```zsh
# .zshrc, before z1 loads
zstyle ':z1:zstyles' skip 'yes'
```

Everything else can live in `.zstyles`, since `z1` loads it before it reads a style of
its own. That includes `xdg-basedirs`, the one style that is on by default. Turn it off
and config, data, and cache all become `$ZDOTDIR`, or `$HOME` when you have no
`$ZDOTDIR`:

```zsh
# .zstyles
zstyle ':z1:xdg-basedirs' enable 'no'
```

Either way, a directory you set yourself is left alone, so you can move one without
moving the rest. That one has to be in your `.zshrc`, since it decides where things go:

```zsh
# .zshrc, before z1 loads
ZSH_CACHE_DIR=$HOME/.cache/zsh
```

The `debug` styles print to stderr as things run, for when a hook of yours isn't firing
and you want to see the order:

| Context                  | Style   | Default | What it does                             |
| ------------------------ | ------- | ------- | ---------------------------------------- |
| `:z1:editor:accept-line` | `debug` | off     | Print each `accept-line` hook as it runs |
| `:z1:post_zshrc`         | `debug` | off     | Print each `post_zshrc` hook as it runs  |

As with `cache` and `skip`, one pattern turns them all on:

```zsh
zstyle ':z1:*' debug 'yes'
```

### Prompt

`z1` adds `$ZSH_CONFIG_DIR/prompts` and its own `prompts/` directory to `fpath`, yours
first. Starting zsh's prompt system is left to you:

```zsh
# .zshrc
autoload -Uz promptinit && promptinit
prompt z1
```

The bundled `z1` prompt reads these:

| Context                | Style                                                          | Default           | What it does                                                              |
| ---------------------- | -------------------------------------------------------------- | ----------------- | ------------------------------------------------------------------------- |
| `:z1:prompt`           | `pwd-length`                                                   | short             | `full` for `$PWD`, `long` for a `~`-shortened path, otherwise abbreviated |
| `:z1:prompt`           | `transient`                                                    | off               | Collapse an accepted line to just the prompt character                    |
| `:z1:prompt:character` | `success` `error` `vicmd` `stash` `dirty` `ahead` `behind`     | `❱ ❱ ❰ ☰ • ⇡ ⇣`  | Symbols the prompt is built from                                          |
| `:z1:prompt:colors`    | `black` `red` `green` `yellow` `blue` `magenta` `cyan` `white` | 256-color palette | Color numbers the prompt is built from                                    |
| `:z1:prompt:unicode`   | `disable`                                                      | off               | Fall back to ASCII symbols                                                |

### Variables

A few things are plain variables, because they are read before any zstyle could be set,
or are conventional names from elsewhere.

| Variable         | Default                                 | What it does                                    |
| ---------------- | --------------------------------------- | ----------------------------------------------- |
| `ZFUNCDIR`       | `$ZSH_CONFIG_DIR/functions`             | Directory of functions to autoload              |
| `ZSH_BINDKEY`    | see `:z1:editor` `keymap`               | Wins over the zstyle when set before `z1` loads |
| `ZSTYLESFILE`    | `${ZDOTDIR:-$HOME}/.zstyles`            | The zstyles file `z1` sources on the way in     |
| `ZSH_COMPDUMP`   | see `:z1:compinit` `dumpfile`           | Wins over the zstyle when set before `z1` loads |
| `ZSH_CONFIG_DIR` | `$ZDOTDIR`, else `$XDG_CONFIG_HOME/zsh` | Where your config lives. Preset value wins      |
| `ZSH_DATA_DIR`   | `$XDG_DATA_HOME/zsh`                    | Where data that should persist lives            |
| `ZSH_CACHE_DIR`  | `$XDG_CACHE_HOME/zsh`                   | Where throwaway data lives                      |

### I don't like a setting

Nothing `z1` does is locked in. It uses plain Zsh builtins in one pass, so the last word
is always yours. Undo anything you disagree with after the `source` line in your
`.zshrc`, or from a file in `conf.d`, which runs later still.

`z1` turns off shared history, for instance, because most people want each terminal to
keep its own. If you want the other behavior, turn it back on:

```zsh
# .zshrc, after z1 loads
setopt share_history
```

That idea works for anything `z1` sets:

| You dislike        | Undo it with                                    |
| ------------------ | ----------------------------------------------- |
| An option          | `setopt` or `unsetopt` the option again         |
| An alias           | `unalias grep`, or redefine it                  |
| A key binding      | `bindkey` the sequence to a different widget    |
| A completion style | `zstyle` the same context again with your value |
| An environment var | `export PAGER=bat`                              |

Environment variables are a special case worth knowing: `z1` only fills in the ones you
have not already set, so exporting `EDITOR` or `LESS` before `z1` loads is enough. The
same is true of `ZSH_BINDKEY`, `ZSH_COMPDUMP`, and the directory variables in the table
above.

For settings with a zstyle, prefer the zstyle. It is read as `z1` loads, so the setting
is never applied in the first place rather than applied and then reversed.

If you find yourself undoing a lot, remember `z1` is one file. Copy it into your own
config and cut the parts you don't want. I tried to be very light on enforcing my
opinions and focused more on creating a better out-of-the-box Zsh starter config.

[antidote]: https://antidote.sh
[fish]: https://fishshell.com
[ohmyzsh]: https://github.com/ohmyzsh/ohmyzsh
[prezto]: https://github.com/sorin-ionescu/prezto
[grml-zshrc]: https://github.com/grml/grml-etc-core/blob/master/etc/zsh/zshrc
