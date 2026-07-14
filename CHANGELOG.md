# Changelog

All notable changes to this project are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/); this project follows [SemVer](https://semver.org/).

## [2.0.3] - 2026-07-14

### Added
- **`loomo update` self-update command.** Checks the latest npm release, skips work when already current, and installs the new version using the existing global prefix or the permission-free `~/.local` fallback. It also supports a one-time `npx` migration for legacy system-owned installations, while source checkouts are detected and left untouched.

## [2.0.2] - 2026-07-13

### Fixed
- **First-run dependency installation no longer fails with npm `EACCES`.** When the global npm prefix is not writable, bare `loomo` installs Claude Code and Codex under `~/.local`, adds `~/.local/bin` to the current `PATH`, and persists it in the user's shell profile. No `sudo`, password handling, or npm permission knowledge is required.
- **Running bare `loomo` now owns the complete startup flow.** It checks and installs Homebrew, tmux, Claude Code, and Codex in that order, then opens the dashboard. The separate `loomo init` and `loomo setup` commands were removed.
- **macOS bootstrap now installs Homebrew when needed.** Loomo runs Homebrew's official interactive installer, detects the Apple Silicon or Intel prefix, persists `brew shellenv`, and then continues with tmux installation. Any one-time macOS administrator approval remains entirely inside the official Homebrew installer.

## [1.4.0] - 2026-07-13

### Added
- **`loomo init` — one-command prerequisites.** Installs the three things loomo needs and skips whatever is already present: **tmux** (via your OS package manager — `brew` on macOS, `apt`/`dnf`/`pacman`/`apk` on Linux) and the AI CLIs **Claude Code** (`@anthropic-ai/claude-code`) and **Codex** (`@openai/codex`) via npm. Idempotent, shows a plan and asks before installing (skip the prompt with `-y`), and prints the next step (`loomo add`).
- **`loomo add` — arrow-key directory browser.** When registering a project's roles you no longer type full paths: an ↑↓ browser lets you drill into folders and pick with Enter (or `✎` to type a path with Tab-completion), and the next role starts browsing near the last one. Falls back to plain input for non-interactive runs.
- **`loomo adopt` — a real full-screen TUI.** Opens as its own program on the **alternate screen** (restores your terminal on exit, in or out of tmux). Projects are shown as sections from your config — running (`● `) or stopped (`○ `) — plus an `ungrouped` pool of live panes; ↑↓ to move, Enter on a pane to check it and on a `═session═` header to move the checked panes there (real `join-pane` + registration + convention, dirs auto-detected). **Mouse tracking** keeps scroll inside the view (your scrollback stays hidden), the **wheel scrolls the viewport** without moving the selection, and it **pages + reflows on terminal resize** (SIGWINCH). Flicker-free rendering (alt-screen + viewport + write-then-clear-EOL).

### Changed
- **Command rename (with aliases): `init` now means install, project setup is `add`.** The prerequisites installer is `loomo init` (was `loomo setup`), and registering a project is `loomo add` (was `loomo init`) — matching the mental model where `init` is the one-time initial setup and `add` is the repeatable per-project step. New flow: **`loomo init → loomo add → loomo up`**. The old names `setup` and the old `init` behaviour keep working as aliases where sensible, but note `loomo init` now installs prerequisites rather than starting the project wizard.
- **`loomo add` no longer prompts for a hub.** Registering a project is now just session/roles/dirs/model + convention. Set up a hub (secretary) separately with `loomo hub` (create one) or `loomo adopt` (designate an existing session) — removing the redundant inline step.
- **Internal: split the single script into modules.** `bin/tell` now holds only the session-to-session messaging core and command dispatch; commands, UI, pickers, and the adopt TUI live in `lib/` (`common`, `ui`, `workspace`, `adopt`, `completion`), sourced at startup. No behaviour change — purely maintainability.

## [1.2.0] - 2026-07-06

### Added
- **Arrow-key selection everywhere.** Every interactive choice — `init` (default model, hub yes/no, create-directory, per-role model, "start now?"), `adopt` (connection test), and `rm` / `down` (pick the target session + confirmations) — is now an ↑↓ picker on a terminal. Non-TTY runs (agents, scripts, pipes) keep the old static prompts with safe defaults, so nothing automated breaks.
- **Session-scoped teardown.** Closing any pane (quitting its agent) now stops the whole project session, instead of leaving a half-running team. Implemented with per-session tmux hooks (`pane-exited` / `pane-died` + `remain-on-exit`) set only on loomo-created sessions — your global tmux config is never touched.

### Changed
- Cleaner `init` role prompt: the `server / web / app` example moved to a one-line note above, so the prompt itself stays short.

## [1.1.0] - 2026-07-06

### Changed
- **Full English CLI.** All output, wizards, and docs strings are English. Protocol headers default to English: `[session request - KEY from ...]` / `[session reply - KEY ...]`.

### Added
- `LOOMO_LANG=ko` keeps the original Korean protocol headers & convention templates (auto-enabled when `$LANG` is `ko*`) — existing Korean setups keep working untouched.
- English convention templates (role + hub). `init`/`adopt` insert the template matching your language; convention detection accepts both.

## [1.0.0] - 2026-07-06 — loomo

The project is now **loomo**, published under a new npm name.

### Changed
- **Rebranded to loomo.** The command is `loomo` (with `tell` kept as an alias, so existing setups keep working). Banner, help, and package name all say loomo.

### Added
- **Codex support.** loomo now drives both Claude Code and Codex sessions — and they message each other across models (a Claude hub can command a Codex project, and vice versa). Pick the model per session in `loomo init`, or via the 5th field of `workspaces.conf`.
- `loomo layout <preset>` — rearrange panes without editing `tmux.conf`.
- Panes clean up on exit (via `exec`); `loomo up` lists what's registered instead of starting everything (use `--all` to start all).

### Docs
- README rewritten, slimmed, and split into English / Korean / Chinese.

## [0.6.0] - 2026-07-06

### Added
- `tell layout [<session>] <preset>` — rearrange panes with a preset (`tiled`, `main-vertical`, `main-horizontal`, `even-horizontal`, `even-vertical`) without editing `tmux.conf`. Tab-completion included.

### Changed
- Sessions now launch Claude with `exec claude` instead of running it on top of a shell. When Claude exits, the pane is now cleaned up automatically instead of dropping back to a lingering shell.

## [0.5.0] - 2026-07-06

### Changed
- README split into three languages (`README.md` English / `README.ko.md` Korean / `README.zh-CN.md` Chinese) and restructured around the core idea — "let your sessions talk to each other." The `tell` messaging syntax moved out of the main flow into a "How it works" appendix, since agents run it, not people.

## [0.4.0] - 2026-07-02

### Added
- Lifecycle commands: `tell up` (start all / one / `--tabs`), `tell down`, `tell rm` (removes config **and** the inserted CLAUDE.md convention block; project files untouched).
- Resume prior conversations: a 4th config field (session ID) launches a pane with `claude --resume`; `adopt` can bring in a terminal-tab conversation by ID (directory auto-detected).
- Single-hub guarantee, `tell up --tabs` (per-session terminal tabs on macOS), shell tab-completion, `tell help`.

## [0.2.0] - 2026-07-02

### Added
- Onboarding redesign; `tell hub` / `tell list` / `tell rm`.

## [0.1.0] - 2026-07-02

### Added
- First public release: session-to-session messaging over tmux with correlation keys, plus the CLAUDE.md convention templates.
