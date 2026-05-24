<h1>
  <img src=".github/logo.webp" alt="" height="100" align="center">
  mash
</h1>

[![Lint status][badge-lint-status]][badge-lint-status-url]

> A Git-based CLI addon manager for old WoW clients

mash (`m`anage `a`ddons via Ba`sh`) is a CLI addon manager targeting older WoW
clients where addons are primarily distributed via Git repositories. Existing
addon managers are either cumbersome to install on some systems (a
language-specific package manager or runtime just for a single program is
bloat, and on atomic distros like SteamOS or Bazzite often not easily feasible)
or lacking features I need. Bash runs everywhere I care about out-of-the-box.[^1]

mash offers a range of features that simplify managing WoW addons:

- __Multiple independent profiles:__ manage multiple client installations side
  by side (for example, Vanilla and TBC), each with its own configuration and
  installed addons.
- __Support for all common repository layouts:__ a single addon at the root,
  addons in subdirectories, or multiple `.toc` per directory; see the
  _[Core concepts](#core-concepts)_ section for details.
- __Preview updates before applying:__ see which tracked repositories have
  updates available upstream without touching the working state.
- __Pinning:__ freeze a repository at a specific commit so updates skip it,
  useful for sticking to a known-good version when an addon's latest commit is
  broken or when newer commits target different interface versions.
- __Batch installation:__ add many repositories at once from a list file or
  from stdin (for piping from `curl` and similar).

## Table of contents

- [Install](#install)
  - [Dependencies](#dependencies)
  - [Via Homebrew (recommended)](#via-homebrew-recommended)
  - [Manual](#manual)
- [Usage](#usage)
  - [Core concepts](#core-concepts)
  - [Initial setup](#initial-setup)
  - [Profiles](#profiles)
  - [Adding addon repositories](#adding-addon-repositories)
    - [Batch add from a list file](#batch-add-from-a-list-file)
  - [Pinning and unpinning addon repositories](#pinning-and-unpinning-addon-repositories)
  - [Checking for addon repository updates](#checking-for-addon-repository-updates)
  - [Updating addon repositories](#updating-addon-repositories)
  - [Re-detecting addons in existing clones](#re-detecting-addons-in-existing-clones)
  - [Listing addon repositories](#listing-addon-repositories)
  - [Removing addon repositories](#removing-addon-repositories)
  - [Global flags](#global-flags)
- [Configuration](#configuration)
- [Maintainer](#maintainer)
- [Contribute](#contribute)
- [Licenses](#licenses)

## Install

### Dependencies

- Bash 3.2 or later (chosen for out-of-the-box macOS compatibility; no need to
  `brew install bash`)
- Git
- Standard Unix utilities (present on every system that ships Bash)

### Via Homebrew (recommended)

A HEAD-only Homebrew formula is included in this repository. Tap it first, then
install the formula:

```sh
brew tap mserajnik/mash https://github.com/mserajnik/mash
brew install --HEAD mash
```

To update later:

```sh
brew upgrade --fetch-HEAD mash
```

### Manual

Clone the repository and symlink the script into a directory on your `$PATH`
(`~/.local/bin` is a common choice; substitute another directory if it is not
on your `$PATH`):

```sh
git clone https://github.com/mserajnik/mash ~/mash
ln -s ~/mash/bin/mash ~/.local/bin/mash
```

To update later:

```sh
git -C ~/mash pull
```

## Usage

### Core concepts

A WoW _addon_ is a directory under `Interface/AddOns` that contains a `.toc`
("table of contents") file alongside the addon's Lua code and XML files. The
`.toc` file name matches the directory name, and its `## Interface:` directive
declares which client version the addon targets.

Any Git repository that contains one or more such directories is, in mash's
terminology, an _addon repository_. mash clones the repository, finds the
`.toc` files whose interface version matches your configured one, and symlinks
the matching addon directories into `Interface/AddOns`.

In flag names and messages you will see `.toc` referenced explicitly (for
example, `--toc`, "multiple matching `.toc` files") because that is what mash
scans on disk. Each installed `.toc` corresponds to one addon directory, so for
end users the two terms are effectively interchangeable.

Most server emulators run the latest patch of an expansion, so the interface
version is usually fixed by your expansion choice (Vanilla 1.12.1 is `11200`,
TBC 2.4.3 is `20400`, WotLK 3.3.5a is `30300`). In those cases, picking the
expansion and picking the interface version describe the same decision.

mash only supports addons distributed via Git and cannot install addons hosted
on other platforms.

The most common repository structures are covered:

- Single `.toc` file in repository root (the simplest case)
- Single or multiple `.toc` files in subdirectories (the actual addon is in a
  subdirectory or the repository contains multiple addons)
- Multiple `.toc` files in the same directory are resolved automatically via
  interface version where possible (e.g., [`shagu/pfQuest`][addon-pfquest]);
  where not possible, mash prompts for selection

### Initial setup

```sh
mash init <client-directory> # Path to the client directory.
```

`mash init` validates the client directory, creates `Interface/AddOns` if it
does not already exist, prompts for the TOC interface version your client
expects (defaults are listed; you can also type a custom version or shortcut),
and creates a configuration profile set as active.

By default the new profile is named `default`. To pick a different name, pass
`--profile <name>` (see [Profiles](#profiles) for the management commands).

For non-interactive usage, both inputs can be passed as flags:

```sh
mash init <client-directory> --profile tbc --interface tbc
```

> [!TIP]
> `--interface` accepts the shortcuts `vanilla` / `tbc` / `wotlk` (resolving to
> `11200` / `20400` / `30300` respectively) or any 1-6 digit integer.

### Profiles

mash supports multiple independent setups via named profiles, each with its own
client directory, interface version, and tracked repositories. This is useful
when running more than one expansion in parallel (for example a Vanilla client
and a TBC client).

```sh
mash profile # List profiles (active marked with *).
mash use <name> # Switch to an existing profile.
mash drop <name> # Delete a profile and the addons it manages.
```

All other commands (everything except `init`, `use`, `drop`, and `profile`)
operate on the active profile. Switch with `mash use <name>` to work on a
different one.

New profiles are created by passing `--profile <name>` to `mash init`:

```sh
mash init /path/to/wotlk-client --profile wotlk --interface wotlk
```

`mash drop` refuses to delete the active profile (switch first) or the only
remaining profile (create another one first).

### Adding addon repositories

```sh
mash add shagu/pfQuest
mash add The-Kludge-Bureau/Bagshui 1.5.16
mash add DennisWG/BetterAlign 8840ee2dad218d73e5ae8b23979f552f3c2c56cd
```

The second argument is optional. If omitted, mash tracks the repository's
default branch. A 7-40 character lower-case hex string is treated as a commit
hash and pins the repository. Anything else is probed at the remote as a branch
first, then a tag.

GitHub repositories can be referenced as `owner/repository`; other hosts need
the full URL. The shorthand always expands to the HTTPS URL
(`https://github.com/owner/repository.git`); if you need SSH (for example to
clone private repositories), pass the full
`git@github.com:owner/repository.git` form instead.

`mash add` accepts an optional `--toc <name>` flag to disambiguate the case
where an addon directory contains more than one matching `.toc` file (rare,
because the interface version filter usually resolves to a single match). When
this happens during an interactive run, mash prompts for the chosen name; for
non-interactive runs, pass `--toc <name>` to make the choice explicit.

#### Batch add from a list file

```sh
mash add --file addons.txt # Read entries from a file.
curl -sSL https://example.com/addons.txt | mash add --file - # Read from stdin.
```

`mash add --file <file>` reads one entry per line, each with the same shape as
positional `mash add` arguments. Blank lines and lines starting with `#` are
ignored. Repositories that are already added are skipped; other failures are
reported and the batch continues. A summary line at the end tallies how many
were added, skipped, and failed.

Example list file:

```
# 1.12.1 addons
shagu/pfQuest
The-Kludge-Bureau/Bagshui 1.5.16
DennisWG/BetterAlign 8840ee2dad218d73e5ae8b23979f552f3c2c56cd
```

> [!TIP]
> Pass `-` as the file to read from stdin (useful for piping from `curl`,
> `cat`, or other tools).

### Pinning and unpinning addon repositories

```sh
mash pin shagu/pfQuest # Pin at the clone's current HEAD.
mash pin DennisWG/BetterAlign 8840ee2 # Pin at a specific commit.
mash unpin DennisWG/BetterAlign # Unpin and switch to the origin's default branch.
mash unpin shagu/pfQuest master # Unpin and switch to a specific branch or tag.
```

`mash pin` freezes a repository at a specific commit so subsequent
`mash update` runs skip it. With no commit argument, it freezes at the clone's
current `HEAD`; with a commit argument, it checks out that commit first
(fetching from upstream if it is not in the local clone yet) and then freezes.
A repeat pin against the same already-pinned commit is a no-op success.

`mash unpin` reverses this: it switches the repository back to a branch or tag
and clears the pinned flag. With no ref argument, it switches to the origin's
default branch; with a ref argument, it treats the value as a branch first,
then as a tag (same probing as `mash add`).

### Checking for addon repository updates

```sh
mash status # Check every tracked repository.
mash status shagu/pfQuest # Check one repository.
```

`mash status` fetches each tracked repository and reports whether updates are
available upstream, without touching the working state. Pinned repositories are
skipped with a message; missing clones emit a warning. When `mash status` runs
against more than one repository, it emits a summary line at the end.

Apply available updates with `mash update`.

### Updating addon repositories

```sh
mash update # Update every tracked repository.
mash update shagu/pfQuest # Update one repository.
```

`mash update` fetches and resets the working tree to the recorded ref for
branches and tags, and skips pinned commits with a message. If the upstream
layout has changed in a way that breaks a recorded addon, mash refuses and
tells you to run `mash refresh` to re-detect the addons.

### Re-detecting addons in existing clones

```sh
mash refresh shagu/pfQuest
mash refresh shagu/pfQuest --toc pfQuest-tbc # Pick a .toc when multiple match.
```

`mash refresh` re-runs addon detection against the existing clone and
reconciles the installed symlinks to match. It does not fetch, checkout, or
reset the clone; pair it with `mash update` if you also need to advance the Git
state.

The typical use case is the layout drift that `mash update` refuses to handle
(a `.toc` was added, removed, renamed, or moved upstream).

### Listing addon repositories

```sh
mash list
```

`mash list` prints each tracked repository with its tracked ref, current
commit, and its addons. Pinned repositories show `pinned: <commit-hash>` in
place of the ref:

```
shagu/pfQuest (branch: master, abc1234).
  pfQuest -> ~/.local/share/mash/default/clones/shagu/pfQuest
DennisWG/BetterAlign (pinned: 8840ee2).
  BetterAlign -> ~/.local/share/mash/default/clones/DennisWG/BetterAlign
```

### Removing addon repositories

```sh
mash remove shagu/pfQuest
```

`mash remove` removes the repository and deletes the symlinks mash created for
its addons. Addons that are not managed by mash are left alone.

### Global flags

```
-v, --verbose # Stream Git output.
-q, --quiet # Suppress non-error output.
-h, --help # Show usage.
```

`mash --help` shows the top-level summary; append `--help` to any subcommand
(for example, `mash add --help`) for per-command details.

## Configuration

Each profile's configuration lives at
`${XDG_CONFIG_HOME:-~/.config}/mash/<profile>/config.ini` and is in INI format:

```ini
[main]
client_dir=/path/to/wow-client
interface_version=11200

[repo:shagu/pfQuest]
url=https://github.com/shagu/pfQuest.git
ref=master
ref_kind=branch
pinned=false
addons=pfQuest:.

[repo:DennisWG/BetterAlign]
url=https://github.com/DennisWG/BetterAlign.git
ref=8840ee2dad218d73e5ae8b23979f552f3c2c56cd
ref_kind=commit
pinned=true
addons=BetterAlign:.
```

`ref_kind` is one of `branch`, `tag`, or `commit`. `addons` is a
comma-separated list of `<name>:<reldir>` pairs, where `<name>` is the addon
directory name (the chosen `.toc` basename) and `<reldir>` is the addon's
directory inside the clone (`.` for the repository root).

mash rewrites the file on every `init`, `add`, `pin`, `unpin`, `update`,
`refresh`, and `remove`. You can edit it by hand for one-off changes (e.g.,
switch a repository to track a different branch), but the easier path is
usually to use `mash remove` and re-add.

The persistent clone cache for each profile lives at
`${XDG_DATA_HOME:-~/.local/share}/mash/<profile>/clones`.

The active profile is tracked in a single-line state file at
`${XDG_CONFIG_HOME:-~/.config}/mash/active` containing the profile's name.
`mash use` and `mash init` write this file atomically.

## Maintainer

[Michael Serajnik][maintainer]

## Contribute

You are welcome to help out!

[Open an issue][issues] or [make a pull request][pull-requests].

## Licenses

- [`AGPL-3.0-or-later`][license-agpl-3.0-or-later] (Code)
- [`CC-BY-SA-4.0`][license-cc-by-sa-4.0] (Documentation and graphic assets)
- [`CC0-1.0`][license-cc0-1.0] (Configuration files)

This project follows the [REUSE specification][reuse-spec].

[^1]: Would this be faster in a proper language like Go, with parallel Git
    fetches and prebuilt binaries shipped via GitHub Actions? Probably. But if
    Bash is good enough for [`pass`][pass], it is certainly good enough for an
    addon manager for a 20+ year-old game.

[addon-pfquest]: https://github.com/shagu/pfquest
[badge-lint-status]: https://github.com/mserajnik/mash/actions/workflows/lint.yaml/badge.svg
[badge-lint-status-url]: https://github.com/mserajnik/mash/actions/workflows/lint.yaml
[issues]: https://github.com/mserajnik/mash/issues
[license-agpl-3.0-or-later]: LICENSES/AGPL-3.0-or-later.txt
[license-cc-by-sa-4.0]: LICENSES/CC-BY-SA-4.0.txt
[license-cc0-1.0]: LICENSES/CC0-1.0.txt
[maintainer]: https://github.com/mserajnik
[pass]: https://www.passwordstore.org/
[pull-requests]: https://github.com/mserajnik/mash/pulls
[reuse-spec]: https://reuse.software/spec/
