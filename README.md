# z1

[![MIT License](https://img.shields.io/badge/license-MIT-007EC7.svg)](/LICENSE)
![version](https://img.shields.io/badge/version-v2.0.0-orange)

> First things first - start your .zshrc off right

## Description

`z1` is designed to be a portable, lightweight, ultra-fast, Zsh configuration in a
single file. Equally useful on your desktop machine or on a remote server, z1
enables much of the useful functionality already built into Zsh without the need for
frameworks. And, it's ridiculously fast!

`z1`'s goal of giving you a great starter DIY Zsh experience in a single file
stands in contrast to other full Zsh Frameworks like [Oh-My-Zsh][ohmyzsh] and
[Prezto][prezto]. Those frameworks are nice if you want everything-and-the-kitchen-sink,
but you pay a performance and complexity penalty for using these frameworks.

Many prefer to build their own Zsh config from scratch, but that can be a lot of work
and often requires you to pull together functionality already baked into the Zsh
frameworks you leave behind.

`z1` is simpler. Similar to [Grml's .zshrc][grml-zshrc], `z1` gives you
everything you need for a full-featured Zsh config, but contained in one simple to grok
Zsh include that will grow with you as you use Zsh. It is heavily inspired by the [Fish
shell][fish].

Feel free to use it as-is, build off it, or fork it and make it entirely your own.

## Features

- Set common Zsh environment variables
- Enable better Zsh options than the defaults
- Set better Zsh history options and variables
- Colorize output of commands like `ls`, `grep`, `diff`, and `man`
- Sensible line editor setup with vi/emacs keymap selection, cursor-style hints, and common terminal key fixes
- Useful zle widgets like `prepend-sudo`, `pound-toggle`, `edit-command-line`, paste magic, and quote magic
- Configure Zsh built-in completion system with cached `compinit` for fast startup
- Use built-in Zsh prompt system, with prompts loaded from a `prompts/` directory
- Initialize Homebrew automatically when present

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

[antidote]: https://antidote.sh
[fish]: https://fishshell.com
[ohmyzsh]: https://github.com/ohmyzsh/ohmyzsh
[prezto]: https://github.com/sorin-ionescu/prezto
[grml-zshrc]: https://github.com/grml/grml-etc-core/blob/master/etc/zsh/zshrc
