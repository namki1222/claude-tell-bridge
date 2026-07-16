# loomo — interactive pickers & terminal helpers
# sourced by bin/tell (not standalone). shell: bash

_applescript_escape() { # shell command on stdin-like arg -> APPLESCRIPT_TEXT
  APPLESCRIPT_TEXT=${1//\\/\\\\}
  APPLESCRIPT_TEXT=${APPLESCRIPT_TEXT//\"/\\\"}
}

_dark_terminal_command() { # $1=shell command -> DARK_COMMAND (pass-through)
  # No longer forces the window's colors to dark — a session window opened from
  # the dashboard now follows the user's own light/dark terminal theme (matching
  # the dashboard), so light-theme users don't get a black window with unreadable
  # text. Kept as a thin wrapper so the callers stay unchanged.
  DARK_COMMAND="$1"
}

open_terminal_tab() { # $1=세션 — macOS 터미널 앱에 그 세션으로 접속하는 탭/창을 연다
  # 작은따옴표: AppleScript 문자열(큰따옴표)과 충돌하지 않게
  local cmd
  if [ "$LOOMO_TMUX_MODE" = dedicated ]; then printf -v cmd "%q -L %q -f %q attach -t '=%s'" "$TMUX_BIN" "$LOOMO_TMUX_SOCKET" "$LOOMO_TMUX_CONF" "$1"
  else printf -v cmd "%q attach -t '=%s'" "$TMUX_BIN" "$1"; fi
  _dark_terminal_command "$cmd"; cmd="$DARK_COMMAND"
  _applescript_escape "$cmd"; local apple_cmd="$APPLESCRIPT_TEXT"
  [ "$(uname)" = "Darwin" ] || { warn "--tabs is macOS-only"; return 1; }
  if [ "${TERM_PROGRAM:-}" = "iTerm.app" ] || osascript -e 'application "iTerm2" is running' 2>/dev/null | grep -q true; then
    osascript >/dev/null <<EOF
tell application "iTerm2"
  activate
  if (count of windows) = 0 then
    create window with default profile
  else
    tell current window to create tab with default profile
  end if
  tell current session of current window to write text "$apple_cmd"
end tell
EOF
  else
    # Terminal.app: 새 탭은 System Events Cmd+T가 유일한 방법이라 '손쉬운 사용' 권한 필요.
    # 권한이 없으면 Cmd+T가 씹혀 새 탭이 안 생기는데, 그대로 do script 하면 명령이
    # 현재 탭(대시보드)에 타이핑돼 버린다 → 탭 개수가 '실제로' 늘었을 때만 do script.
    if osascript >/dev/null 2>&1 <<EOF
tell application "Terminal" to activate
delay 0.25
tell application "Terminal"
  if (count of windows) is 0 then
    do script "$apple_cmd"
  else
    set beforeCount to (count of tabs of front window)
    tell application "System Events" to tell process "Terminal" to keystroke "t" using command down
    delay 0.6
    if (count of tabs of front window) > beforeCount then
      do script "$apple_cmd" in selected tab of front window
    else
      error "loomo: new tab was not created (Accessibility permission?)"
    end if
  end if
end tell
EOF
    then :; else
      if [ "${TERMTAB_WARNED:-0}" = "0" ]; then
        TERMTAB_WARNED=1
        warn "새 탭 실패 → 새 창으로 엽니다. 탭으로 열려면 방금 뜬 설정에서 '손쉬운 사용'에 Terminal(터미널)을 허용하세요"
        # 손쉬운 사용 설정 화면을 바로 열어준다 (권한 부여 자체는 사용자만 가능)
        open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null
      fi
      osascript >/dev/null <<EOF
tell application "Terminal"
  activate
  do script "$apple_cmd"
end tell
EOF
    fi
  fi
}

open_terminal_window() { # $1=session — open a dedicated terminal window attached to it
  local cmd output rc terminal
  if [ "$LOOMO_TMUX_MODE" = dedicated ]; then printf -v cmd "%q -L %q -f %q attach -t '=%s'" "$TMUX_BIN" "$LOOMO_TMUX_SOCKET" "$LOOMO_TMUX_CONF" "$1"
  else printf -v cmd "%q attach -t '=%s'" "$TMUX_BIN" "$1"; fi
  _dark_terminal_command "$cmd"; cmd="$DARK_COMMAND"
  _applescript_escape "$cmd"; local apple_cmd="$APPLESCRIPT_TEXT"
  loomo_log INFO terminal.open.begin "session=$1" "mode=$LOOMO_TMUX_MODE" "command=$cmd"
  if [ "$(uname)" = "Darwin" ]; then
    if [ "${TERM_PROGRAM:-}" = "iTerm.app" ] || osascript -e 'application "iTerm2" is running' 2>/dev/null | grep -q true; then
      terminal=iTerm2
      output=$(osascript 2>&1 <<EOF
tell application "iTerm2"
  activate
  set newWindow to (create window with default profile)
  tell current session of newWindow to write text "$apple_cmd"
end tell
EOF
      ); rc=$?
    else
      terminal=Terminal
      output=$(osascript 2>&1 <<EOF
tell application "Terminal"
  activate
  do script "$apple_cmd"
end tell
EOF
      ); rc=$?
    fi
  elif command -v x-terminal-emulator >/dev/null 2>&1; then
    terminal=x-terminal-emulator
    x-terminal-emulator -e sh -lc "$cmd" >/dev/null 2>&1 &
    rc=$?
  else
    loomo_log ERROR terminal.open.unsupported "session=$1" "os=$(uname)"
    return 1
  fi
  if [ "${rc:-1}" -eq 0 ]; then
    loomo_log INFO terminal.open.ok "session=$1" "terminal=$terminal"
  else
    loomo_log ERROR terminal.open.failed "session=$1" "terminal=$terminal" "rc=${rc:-1}" "error=${output:-unknown}"
  fi
  return "${rc:-1}"
}

open_terminal_command() { # $1=fixed command — open it in a dedicated terminal window
  local cmd="$1"
  _dark_terminal_command "$cmd"; cmd="$DARK_COMMAND"
  _applescript_escape "$cmd"; local apple_cmd="$APPLESCRIPT_TEXT"
  if [ "$(uname)" = "Darwin" ]; then
    if [ "${TERM_PROGRAM:-}" = "iTerm.app" ] || osascript -e 'application "iTerm2" is running' 2>/dev/null | grep -q true; then
      osascript >/dev/null <<EOF
tell application "iTerm2"
  activate
  set newWindow to (create window with default profile)
  tell current session of newWindow to write text "$apple_cmd"
end tell
EOF
    else
      osascript >/dev/null <<EOF
tell application "Terminal"
  activate
  do script "$apple_cmd"
end tell
EOF
    fi
  elif command -v x-terminal-emulator >/dev/null 2>&1; then
    x-terminal-emulator -e sh -lc "$cmd" >/dev/null 2>&1 &
  else return 1; fi
}

pick_menu() { # $1=옵션들(개행 구분) → PICKED / PICK_IDX 설정. ↑↓ 이동·Enter 선택·Ctrl-C 취소(→130). TTY 전용
  PICKED=""; PICK_IDX=-1
  local opts=() line n sel=0 key rest j
  while IFS= read -r line; do [ -n "$line" ] && opts[${#opts[@]}]="$line"; done   # 빈 줄(끝 개행 등) 스킵
  n=${#opts[@]}; [ "$n" -eq 0 ] && return 1
  printf '\033[?25l'
  trap 'printf "\033[?25h\n"; return 130' INT
  _dm() { for ((j=0;j<n;j++)); do printf '\033[2K'
    if [ "$j" -eq "$sel" ]; then printf '  %b❯ %s%b\n' "${C_C}${C_B}" "${opts[$j]}" "${C_X}"
    else printf '    %s\n' "${opts[$j]}"; fi; done; }
  _dm
  while :; do
    IFS= read -rsn1 key </dev/tty || { sel=-1; break; }
    if [ "$key" = $'\x1b' ]; then IFS= read -rsn2 -t 1 rest </dev/tty || rest=""; case "$rest" in '[A') key=UP ;; '[B') key=DOWN ;; *) key=IGNORE ;; esac; fi
    case "$key" in
      UP)      sel=$(( (sel - 1 + n) % n )) ;;
      DOWN)    sel=$(( (sel + 1) % n )) ;;
      "")      break ;;                       # Enter = 선택
      *)       : ;;                           # ← → 등 기타 키 무시 · 종료는 Ctrl-C
    esac
    printf '\033[%dA' "$n"; _dm
  done
  printf '\033[?25h'; trap - INT
  [ "$sel" -lt 0 ] && return 130
  PICKED="${opts[$sel]}"; PICK_IDX=$sel; return 0
}

choose() { # $1=결과변수 $2=프롬프트 $3...=옵션 → TTY면 화살표 피커, 아니면 read(엔터=첫 옵션). 취소 시 CHOOSE_CANCELLED=1
  CHOOSE_CANCELLED=0
  local __v="$1" prompt="$2"; shift 2
  if [ -t 1 ] && { : </dev/tty; } 2>/dev/null; then   # stdout=터미널 + /dev/tty 열림 → 파이프 안(adopt)에서도 동작, 에이전트(제어터미널 없음)는 폴백
    note "$prompt ${C_D}(↑↓ · Enter select · q cancel)${C_X}"
    pick_menu <<EOF
$(printf '%s\n' "$@")
EOF
    [ $? -eq 130 ] && { CHOOSE_CANCELLED=1; printf -v "$__v" '%s' ""; return 1; }
    printf -v "$__v" '%s' "$PICKED"
  else
    local _a; ask "$prompt [$*, Enter=$1]: "; read -r _a
    printf -v "$__v" '%s' "${_a:-$1}"
  fi
  return 0
}

pick_multi() { # stdin=옵션(개행) → PICK_SEL="선택된 0-based 인덱스들"(공백구분). space=토글·a=전체·Enter=확정·q/ESC=취소(130). TTY 전용
  PICK_SEL=""
  local opts=() on=() line n sel=0 key rest j
  while IFS= read -r line; do [ -n "$line" ] && opts[${#opts[@]}]="$line"; done
  n=${#opts[@]}; [ "$n" -eq 0 ] && return 1
  for ((j=0;j<n;j++)); do on[$j]=0; done
  note "space=toggle · a=all · Enter=assign · q=done"
  printf '\033[?25l'
  trap 'printf "\033[?25h\n"; return 130' INT
  _dmm() { for ((j=0;j<n;j++)); do printf '\033[2K'
    local box="[ ]"; [ "${on[$j]}" = 1 ] && box="[x]"
    if [ "$j" -eq "$sel" ]; then printf '  %b❯ %s %s%b\n' "${C_C}${C_B}" "$box" "${opts[$j]}" "${C_X}"
    else printf '    %s %s\n' "$box" "${opts[$j]}"; fi; done; }
  _dmm
  while :; do
    IFS= read -rsn1 key </dev/tty || { sel=-1; break; }
    if [ "$key" = $'\x1b' ]; then IFS= read -rsn2 -t 1 rest </dev/tty || rest=""; case "$rest" in '[A') key=UP ;; '[B') key=DOWN ;; *) key=ESC ;; esac; fi
    case "$key" in
      UP|k)    sel=$(( (sel - 1 + n) % n )) ;;
      DOWN|j)  sel=$(( (sel + 1) % n )) ;;
      " ")     on[$sel]=$(( 1 - on[$sel] )) ;;
      a|A)     local allon=1; for ((j=0;j<n;j++)); do [ "${on[$j]}" = 0 ] && allon=0; done
               for ((j=0;j<n;j++)); do on[$j]=$(( 1 - allon )); done ;;
      "")      break ;;                       # Enter → 확정
      q|Q|ESC) sel=-1; break ;;
    esac
    printf '\033[%dA' "$n"; _dmm
  done
  printf '\033[?25h'; trap - INT
  [ "$sel" -lt 0 ] && return 130
  local out=""; for ((j=0;j<n;j++)); do [ "${on[$j]}" = 1 ] && out="$out $j"; done
  PICK_SEL="${out# }"; return 0
}

_pick_dir() { # 대화형 디렉터리 브라우저 → 전역 PICKED_DIR (취소 시 빈값). $1=시작 경로
  PICKED_DIR=""
  local cur; cur=$(cd "${1:-$PWD}" 2>/dev/null && pwd) || cur="$HOME"
  while :; do
    printf '\033[2J\033[H'
    banner "add · 디렉터리 선택"
    note "현재: ${C_B}$cur${C_X}"
    note "↑↓ 이동 · Enter 열기/선택 · q 취소"
    echo ""
    local subs=() opts=() d
    for d in "$cur"/*/; do [ -d "$d" ] || continue; d=${d%/}; subs[${#subs[@]}]="${d##*/}"; done
    opts=("✓ 여기를 선택  →  $cur" "⬆  상위 폴더로" "✎  경로 직접 입력 (Tab 자동완성)")
    if [ "${#subs[@]}" -gt 0 ]; then
      for d in "${subs[@]}"; do opts[${#opts[@]}]="📁 $d/"; done
    fi
    pick_menu <<EOF
$(printf '%s\n' "${opts[@]}")
EOF
    [ $? -eq 130 ] && return 1
    case "$PICK_IDX" in
      0) PICKED_DIR="$cur"; return 0 ;;
      1) cur=$(dirname "$cur") ;;
      2) printf '\033[?25h'; local typed; ask "  경로 입력: "; read -e -r typed </dev/tty
         [ -n "$typed" ] && { PICKED_DIR=$(abspath "$typed"); return 0; } ;;
      *) cur="$cur/${subs[$((PICK_IDX - 3))]}" ;;
    esac
  done
}

pick_project() { # stdin=프로젝트 목록 → PICKED / PICK_ACT(enter|all|quit) 설정. TTY 전용 인터랙티브 피커
  PICKED=""; PICK_ACT="quit"
  local items marks line n sel=0 i j key rest
  items=(); marks=()
  while IFS= read -r line; do [ -n "$line" ] && items[${#items[@]}]="$line"; done
  n=${#items[@]}; [ "$n" -eq 0 ] && return 1
  for ((i=0;i<n;i++)); do
    if tmux has-session -t "=${items[$i]}" 2>/dev/null; then marks[$i]="●"; else marks[$i]="○"; fi
  done
  printf '\033[?25l'                              # 커서 숨김
  trap 'printf "\033[?25h\n"; exit 130' INT       # Ctrl-C 시 커서 복구
  _draw() {
    for ((j=0;j<n;j++)); do
      printf '\033[2K'
      if [ "$j" -eq "$sel" ]; then printf '  %b❯ %s %s%b\n' "${C_C}${C_B}" "${marks[$j]}" "${items[$j]}" "${C_X}"
      else printf '    %s %s\n' "${marks[$j]}" "${items[$j]}"; fi
    done
  }
  _draw
  while :; do
    IFS= read -rsn1 key </dev/tty || { PICK_ACT="quit"; break; }
    if [ "$key" = $'\x1b' ]; then
      IFS= read -rsn2 -t 1 rest </dev/tty || rest=""
      case "$rest" in '[A') key="UP" ;; '[B') key="DOWN" ;; *) key="ESC" ;; esac
    fi
    case "$key" in
      UP|k)    sel=$(( (sel - 1 + n) % n )) ;;
      DOWN|j)  sel=$(( (sel + 1) % n )) ;;
      "")      PICK_ACT="enter"; PICKED="${items[$sel]}"; break ;;   # Enter
      a|A)     PICK_ACT="all"; break ;;
      q|Q|ESC) PICK_ACT="quit"; break ;;
    esac
    printf '\033[%dA' "$n"
    _draw
  done
  printf '\033[?25h'
  trap - INT
  return 0
}
