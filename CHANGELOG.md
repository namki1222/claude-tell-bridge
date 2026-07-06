# Changelog

All notable changes to this project are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/); this project follows [SemVer](https://semver.org/).

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
