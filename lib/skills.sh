# loomo — Markdown skills managed from the tmux pane context menu
# sourced by bin/tell (not standalone). shell: bash

SKILL_DIR="${LOOMO_SKILL_DIR:-$CONFIG_DIR/skills}"

_skill_slug() {
  local name="$1"
  name=${name%.md}; name=${name%.MD}
  printf '%s' "$name" | LC_ALL=C tr '[:upper:] ' '[:lower:]-' | sed 's/[^a-z0-9._-]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

_skill_drop_path() { # parse one shell-escaped path pasted by Terminal drag-and-drop
  python3 - "$1" <<'PY' 2>/dev/null
import os,shlex,sys,urllib.parse
raw=sys.argv[1].strip()
if os.path.exists(os.path.expanduser(raw)):
    print(os.path.abspath(os.path.expanduser(raw))); raise SystemExit
try: parts=shlex.split(raw)
except ValueError: parts=[sys.argv[1].strip()]
if not parts: raise SystemExit(1)
p=parts[0]
if p.startswith('file://'): p=urllib.parse.unquote(urllib.parse.urlparse(p).path)
print(os.path.abspath(os.path.expanduser(p)))
PY
}

cmd_skill_add() {
  local raw="${1:-}" src name slug dest
  mkdir -p "$SKILL_DIR" || return 1
  if [ -z "$raw" ]; then
    printf '\033[36m\033[1mAdd Markdown Skill\033[0m\n\n'
    printf 'Drag a .md file into this popup, then press Enter.\n'
    printf 'You can also type or paste its path.\n\n> '
    IFS= read -r raw </dev/tty || return 1
  fi
  src=$(_skill_drop_path "$raw") || { echo "Invalid file path."; return 1; }
  [ -f "$src" ] || { echo "File not found: $src"; return 1; }
  case "$src" in *.md|*.MD) ;; *) echo "Only Markdown (.md) files can be added."; return 1 ;; esac
  name=$(basename "$src"); slug=$(_skill_slug "$name")
  [ -n "$slug" ] || { echo "Could not create a skill name from: $name"; return 1; }
  dest="$SKILL_DIR/$slug"
  mkdir -p "$dest" || return 1
  cp "$src" "$dest/SKILL.md" || return 1
  printf '%s\n' "$name" > "$dest/name"
  echo ""
  echo "Added skill: $name"
  echo "Saved to: $dest/SKILL.md"
  echo ""
  echo "Right-click an AI pane to use it."
  cmd_skill_refresh_menu >/dev/null 2>&1 || true
  [ -t 0 ] && [ "${LOOMO_SKILL_NO_PAUSE:-0}" != 1 ] && { printf '\nPress Enter to close.'; IFS= read -r _ </dev/tty || true; }
  return 0
}

cmd_skill_use() { # pane base64(skill path)
  local pane="$1" encoded="$2" path name prompt
  path=$(_b64decode "$encoded") || return 2
  [ -f "$path" ] || { loomo_log ERROR skill.use.missing "pane=$pane" "path=$path"; return 1; }
  name=$(basename "$(dirname "$path")")
  prompt="Load and use the loomo skill '$name' from '$path'. Read its Markdown instructions completely, follow them for this conversation, and confirm when the skill is active."
  tmux send-keys -t "$pane" -l "$prompt" || return 1
  tmux send-keys -t "$pane" Enter
  loomo_log INFO skill.use "pane=$pane" "skill=$name" "path=$path"
}

cmd_skill_delete() { # slug
  local slug="$1" dir
  case "$slug" in ''|*[!a-zA-Z0-9._-]*) echo "Invalid skill name: $slug"; return 2 ;; esac
  dir="$SKILL_DIR/$slug"
  [ -d "$dir" ] || { echo "Skill not found: $slug"; return 1; }
  rm -f "$dir/SKILL.md" "$dir/name" || return 1
  rmdir "$dir" 2>/dev/null || { echo "Skill directory contains additional files and was kept: $dir"; return 1; }
  cmd_skill_refresh_menu >/dev/null 2>&1 || true
  echo "Deleted skill: $slug"
}

cmd_skill_refresh_menu() {
  local d path name encoded key=1
  local -a menu
  # Keep tmux's native pane context menu intact and insert loomo skills at the
  # top. This is an extension of the familiar menu, not a replacement for it.
  menu=()
  if [ -d "$SKILL_DIR" ]; then
    for d in "$SKILL_DIR"/*; do
      [ -f "$d/SKILL.md" ] || continue
      path="$d/SKILL.md"; name=$(cat "$d/name" 2>/dev/null || basename "$d")
      encoded=$(printf '%s' "$path" | base64 | tr -d '\r\n')
      menu+=("Use: $name" "$key" "run-shell -b 'loomo skill use \"#{pane_id}\" $encoded'")
      key=$((key+1)); [ "$key" -le 9 ] || key=0
    done
  fi
  [ "${#menu[@]}" -gt 0 ] && menu+=("")
  menu+=(
    "#{?#{m/r:(copy|view)-mode,#{pane_mode}},Go To Top,}" '<' "send-keys -X history-top"
    "#{?#{m/r:(copy|view)-mode,#{pane_mode}},Go To Bottom,}" '>' "send-keys -X history-bottom"
    ""
    "#{?mouse_word,Search For #[underscore]#{=/9/...:mouse_word},}" C-r "if-shell -F '#{?#{m/r:(copy|view)-mode,#{pane_mode}},0,1}' 'copy-mode -t=' ; send-keys -X -t = search-backward -- '#{q:mouse_word}'"
    "#{?mouse_word,Type #[underscore]#{=/9/...:mouse_word},}" C-y "copy-mode -q ; send-keys -l '#{q:mouse_word}'"
    "#{?mouse_word,Copy #[underscore]#{=/9/...:mouse_word},}" c "copy-mode -q ; set-buffer '#{q:mouse_word}'"
    "#{?mouse_line,Copy Line,}" l "copy-mode -q ; set-buffer '#{q:mouse_line}'"
    ""
    "#{?mouse_hyperlink,Type #[underscore]#{=/9/...:mouse_hyperlink},}" C-h "copy-mode -q ; send-keys -l '#{q:mouse_hyperlink}'"
    "#{?mouse_hyperlink,Copy #[underscore]#{=/9/...:mouse_hyperlink},}" h "copy-mode -q ; set-buffer '#{q:mouse_hyperlink}'"
    ""
    "Horizontal Split" h "split-window -h -c '#{pane_current_path}'"
    "Vertical Split" v "split-window -v -c '#{pane_current_path}'"
    ""
    "#{?#{>:#{window_panes},1},,-}Swap Up" u "swap-pane -U"
    "#{?#{>:#{window_panes},1},,-}Swap Down" d "swap-pane -D"
    "#{?pane_marked_set,,-}Swap Marked" s "swap-pane"
    ""
    "Kill" X "kill-pane"
    "Respawn" R "respawn-pane -k"
    "#{?pane_marked,Unmark,Mark}" m "select-pane -m"
    "#{?#{>:#{window_panes},1},,-}#{?window_zoomed_flag,Unzoom,Zoom}" z "resize-pane -Z"
  )
  # -O keeps the menu open after the opening right button is released. Items
  # are then selected with a normal click instead of click-drag-release.
  tmux unbind-key -T root MouseUp3Pane 2>/dev/null || true
  tmux bind-key -T root MouseDown3Pane display-menu -O \
    -T '#[align=centre]Loomo · #{@loomo_role}' -t = -x M -y M "${menu[@]}"
}

cmd_skill() {
  local action="${1:-list}"; shift 2>/dev/null || true
  case "$action" in
    add) cmd_skill_add "$@" ;;
    delete) cmd_skill_delete "$@" ;;
    use) cmd_skill_use "$@" ;;
    menu|refresh-menu) cmd_skill_refresh_menu ;;
    list)
      [ -d "$SKILL_DIR" ] || return 0
      find "$SKILL_DIR" -mindepth 2 -maxdepth 2 -name SKILL.md -print | sort ;;
    *) echo "usage: loomo skill [add [file.md]|delete <name>|list]"; return 2 ;;
  esac
}
