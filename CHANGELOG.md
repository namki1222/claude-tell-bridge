# Changelog

All notable changes to this project are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/); this project follows [SemVer](https://semver.org/).

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
