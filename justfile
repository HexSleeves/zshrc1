#!/usr/bin/env just --justfile
# z1 project tasks. Run `just` to see them.

# List the available recipes.
default:
    @just --list

# Run the bats test suite.
test *files:
    ./tests/run {{ files }}

prettier := "npx --yes prettier@3 --prose-wrap always --print-width 88"

# Wrap markdown prose at 88 columns. Tables and code blocks are left alone.
format path='.':
    find {{ path }} -name '*.md' -print0 | xargs -0 {{ prettier }} --write

# Check markdown formatting without writing anything.
format-check path='.':
    find {{ path }} -name '*.md' -print0 | xargs -0 {{ prettier }} --check

# Show the current z1 version.
version:
    @grep '^current_version' .bumpversion.cfg | cut -d' ' -f3-

# Bump the version, commit, and tag. part: major | minor | patch
bump part='patch':
    bump2version {{ part }}

# Show what a bump would change without touching anything.
bump-dry part='patch':
    bump2version --dry-run --verbose --allow-dirty {{ part }}
