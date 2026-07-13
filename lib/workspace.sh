# loomo — workspace/management commands
# sourced by bin/tell (not standalone). shell: bash

LAYOUT_PRESETS="tiled main-vertical main-horizontal even-horizontal even-vertical"

cmd_help() {
  local V; V=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$SELF_DIR/../package.json" 2>/dev/null | head -1)
  row() { printf "  ${C_C}%-12s${C_X} %s\n" "$1" "$2"; }
  banner "help${V:+ · v$V}"
  echo ""
  echo "  Weave your AI sessions (Claude Code / Codex) into a team that talks to each other."
  echo "  ${C_D}session = a project team · pane (role) = one resident AI on that team${C_X}"
  echo "  ${C_D}Sessions message each other automatically via the convention — just ask in plain language.${C_X}"
  echo ""
  echo "${C_Y}${C_B}Set up${C_X}"
  row "init"       "install prerequisites — tmux + Claude Code + Codex (skips present)"
  row "add"        "register a project — session, roles, dirs, model + convention"
  row "adopt"      "bring in AIs you already run — adopt live panes, resume conversations by ID"
  row "hub"        "register the manager (hub) session — only one system-wide"
  echo ""
  echo "${C_Y}${C_B}Operate${C_X}"
  row "up"         "start — up <session> (one) / up --all (all → attach hub, +--tabs) / up (list)"
  row "down"       "stop — loomo down <session> / down --all (config kept)"
  row "layout"     "panes — loomo layout [<session>] <preset> (tiled/main-vertical/..., no tmux.conf)"
  row "ws"         "start one and attach — loomo ws <session> (no arg: list)"
  row "list"       "address book — who you can talk to + convention/run status"
  row "rm"         "delete workspace — kill + config + convention block removed (project files untouched)"
  echo ""
  echo "${C_Y}${C_B}Diagnose${C_X}"
  row "doctor"     "environment check — tmux · agent CLI · config · hub · package resources"
  row "completion" "tab completion — add eval \"\$(loomo completion)\" to .zshrc"
  row "help"       "this help"
  echo ""
  echo "${C_Y}${C_B}Get started${C_X}"
  echo "  ${C_D}loomo init → loomo add → loomo up --all → ask any pane's AI: \"tell web the schema changed\"${C_X}"
  echo "  ${C_D}docs: https://github.com/namki1222/loomo${C_X}"
}

_ver() { "$1" --version 2>/dev/null | head -1; }

_tmux_install_desc() { # 이 OS에서 tmux를 어떻게 깔지 한 줄 설명
  case "$(uname)" in
    Darwin) echo "brew install tmux" ;;
    Linux)
      if   command -v apt-get >/dev/null 2>&1; then echo "sudo apt-get install -y tmux"
      elif command -v dnf     >/dev/null 2>&1; then echo "sudo dnf install -y tmux"
      elif command -v pacman  >/dev/null 2>&1; then echo "sudo pacman -S --noconfirm tmux"
      elif command -v apk     >/dev/null 2>&1; then echo "sudo apk add tmux"
      else echo "your package manager (manual)"; fi ;;
    *) echo "manual install" ;;
  esac
}

_install_tmux() { # 반환 0=성공
  case "$(uname)" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then brew install tmux
      else warn "Homebrew not found — install from https://brew.sh, then: brew install tmux"; return 1; fi ;;
    Linux)
      if   command -v apt-get >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y tmux
      elif command -v dnf     >/dev/null 2>&1; then sudo dnf install -y tmux
      elif command -v pacman  >/dev/null 2>&1; then sudo pacman -S --noconfirm tmux
      elif command -v apk     >/dev/null 2>&1; then sudo apk add tmux
      else warn "no known package manager — install tmux manually"; return 1; fi ;;
    *) warn "unsupported OS for auto-install — install tmux manually"; return 1 ;;
  esac
}

cmd_init() { # 사전 요구사항 설치: tmux · Claude Code · Codex (이미 있으면 건너뜀)
  local YES=0 a
  for a in "$@"; do case "$a" in -y|--yes) YES=1 ;; esac; done
  banner "init · install prerequisites"
  echo ""
  note "loomo needs tmux (panes) + at least one AI CLI (Claude Code / Codex)."
  echo ""

  local need_tmux=0 need_claude=0 need_codex=0
  command -v tmux   >/dev/null 2>&1 && ok "tmux   $(tmux -V | awk '{print $2}')" || { note "tmux   — not installed"; need_tmux=1; }
  command -v claude >/dev/null 2>&1 && ok "claude $(_ver claude)"                 || { note "claude — not installed"; need_claude=1; }
  command -v codex  >/dev/null 2>&1 && ok "codex  $(_ver codex)"                  || { note "codex  — not installed"; need_codex=1; }

  if [ $((need_tmux + need_claude + need_codex)) -eq 0 ]; then
    echo ""; ok "all prerequisites present — next: ${C_B}loomo add${C_X}"; return 0
  fi

  echo ""
  step "will install"
  [ "$need_tmux"   = 1 ] && note "· tmux    ($(_tmux_install_desc))"
  [ "$need_claude" = 1 ] && note "· claude  (npm install -g @anthropic-ai/claude-code)"
  [ "$need_codex"  = 1 ] && note "· codex   (npm install -g @openai/codex)"
  echo ""

  if [ "$YES" = 0 ]; then
    local A; choose A "proceed?" Yes No
    [ "$A" = "Yes" ] || { skip "cancelled — nothing installed"; return 0; }
  fi

  local fail=0
  [ "$need_tmux" = 1 ] && { step "installing tmux"; _install_tmux || fail=1; }

  if [ "$need_claude" = 1 ] || [ "$need_codex" = 1 ]; then
    if command -v npm >/dev/null 2>&1; then
      [ "$need_claude" = 1 ] && { step "installing Claude Code"; npm install -g @anthropic-ai/claude-code || fail=1; }
      [ "$need_codex"  = 1 ] && { step "installing Codex";       npm install -g @openai/codex          || fail=1; }
    else
      warn "npm not found — install Node.js (https://nodejs.org), then re-run: loomo init"; fail=1
    fi
  fi

  echo ""
  banner "init · result"
  command -v tmux   >/dev/null 2>&1 && ok "tmux   $(tmux -V | awk '{print $2}')" || warn "tmux still missing"
  command -v claude >/dev/null 2>&1 && ok "claude $(_ver claude)"                || note "claude not installed (ok if you use codex)"
  command -v codex  >/dev/null 2>&1 && ok "codex  $(_ver codex)"                 || note "codex not installed (ok if you use claude)"
  echo ""
  if [ "$fail" = 0 ]; then ok "done — next: ${C_B}loomo add${C_X}"
  else warn "some steps failed — see messages above, then re-run: loomo init"; fi
  return "$fail"
}

cmd_doctor() {
  local ok=0
  banner "doctor · environment check"
  if command -v tmux >/dev/null 2>&1; then echo "✅ tmux $(tmux -V | awk '{print $2}')"; else echo "❌ tmux missing — brew install tmux"; ok=1; fi
  if command -v "$AGENT_CMD" >/dev/null 2>&1; then echo "✅ $AGENT_CMD $("$AGENT_CMD" --version 2>/dev/null | awk '{print $1}')"; else echo "⚠️  $AGENT_CMD CLI missing — messaging works but there is no AI to answer"; fi
  if [ -n "${TMUX:-}" ]; then echo "✅ running inside tmux (sender header auto-detected)"; else echo "ℹ️  outside tmux — messages go out without a from header"; fi
  if [ -f "$WS_CONF" ]; then echo "✅ workspace config: $WS_CONF ($(grep -cvE '^[[:space:]]*(#|$)' "$WS_CONF" 2>/dev/null || echo 0) lines)"; else echo "ℹ️  no workspace config yet — create with 'loomo add' or 'loomo adopt'"; fi
  if get_hub; then echo "✅ hub: $HUB · $HUBR (only one hub)"; else echo "ℹ️  no hub — register with 'loomo hub' (optional)"; fi
  [ -f "$TEMPLATE_DIR/CLAUDE-section-role.md" ] && echo "✅ package resources OK" || echo "⚠️  package broken — reinstall: npm i -g @namki1222/loomo"
  return $ok
}

append_role_template() { # $1=dir  $2=session  $3=roles(공백구분)  $4=hub_session  $5=hub_role
  local dir="$1" session="$2" roles="$3" hub_s="$4" hub_r="$5"
  local f="$dir/$AGENT_CONV" t="$TEMPLATE_DIR/CLAUDE-section-role.en.md"
  [ "$LOOMO_LANG" = "ko" ] && t="$TEMPLATE_DIR/CLAUDE-section-role.md"
  [ -f "$t" ] || { warn "install broken — reinstall: npm i -g @namki1222/loomo"; return 1; }
  if [ -f "$f" ] && grep -qE '세션 요청 - KEY|session request - KEY' "$f" 2>/dev/null; then
    return 0   # already wired — pass silently
  fi
  mkdir -p "$dir"
  { [ -f "$f" ] && echo ""; sed -e "s/{{SESSION}}/$session/g" -e "s/{{ROLES}}/$roles/g" \
        -e "s/{{HUB_SESSION}}/$hub_s/g" -e "s/{{HUB_ROLE}}/$hub_r/g" "$t" \
    | sed -e 's# (보통 발신자는 허브 `/`)##' -e 's# (usually the hub `/`)##'; } >> "$f"   # strip hub phrasing when no hub
  return 0
}

list_agent_sessions() { # $1=dir — 그 디렉터리에서 쓰던 대화 목록(최근 5개). 있으면 0
  local lines="" f id
  if [ "$TELL_AGENT" = "codex" ]; then
    # codex: 날짜폴더 전체에서 cwd가 $1인 세션 파일을 찾음 (파일명 uuid = 세션ID)
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      grep -qF "\"cwd\":\"$1\"" "$f" 2>/dev/null || continue
      id=$(basename "$f" .jsonl | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)
      lines="$lines    $id  ${C_D}(last used: $(date -r "$f" '+%m/%d %H:%M' 2>/dev/null))${C_X}
"
      [ "$(printf '%s' "$lines" | grep -c '.')" -ge 5 ] && break
    done <<EOF
$(ls -t "$AGENT_SESSIONS"/*/*/*/*.jsonl 2>/dev/null | head -60)
EOF
  else
    # claude: 디렉터리 슬러그 폴더의 jsonl (파일명 = 세션ID)
    local proj="$AGENT_SESSIONS/$(printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g')"
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      lines="$lines    $(basename "$f" .jsonl)  ${C_D}(last used: $(date -r "$f" '+%m/%d %H:%M' 2>/dev/null))${C_X}
"
    done <<EOF
$(ls -t "$proj"/*.jsonl 2>/dev/null | head -5)
EOF
  fi
  [ -n "$lines" ] || return 1
  note "recent $TELL_AGENT conversations in this directory:"
  printf '%s' "$lines"
  return 0
}

ask_resume_id() { # $1=dir — 이어받을 대화 세션ID를 물어봄. 결과는 전역 RID (빈 값 = 새 대화)
  RID=""
  list_agent_sessions "$1" || return 0
  # /dev/tty 고정: adopt의 파이프 루프 안에서도 사용자 입력을 받기 위함 (마법사는 대화형 전용)
  ask "  session ID to resume (Enter = start fresh): "; read -r RID </dev/tty
}

dir_from_session_id() { # $1=세션ID → 대화 기록(jsonl)의 cwd에서 담당 디렉터리 역추적. 성공 시 stdout
  local f
  if [ "$TELL_AGENT" = "codex" ]; then
    f=$(ls "$AGENT_SESSIONS"/*/*/*/*"$1"*.jsonl 2>/dev/null | head -1)   # 날짜폴더 + 파일명에 uuid
  else
    f=$(ls "$AGENT_SESSIONS"/*/"$1".jsonl 2>/dev/null | head -1)          # 슬러그폴더 + 파일명=uuid
  fi
  [ -n "$f" ] || return 1
  grep -o '"cwd":"[^"]*"' "$f" 2>/dev/null | head -1 | sed 's/^"cwd":"//; s/"$//'
}

get_hub() { # 등록된 허브 로드 → HUB/HUBR 설정. 없으면 1
  HUB=""; HUBR=""
  [ -f "$HUB_FILE" ] || return 1
  IFS='|' read -r HUB HUBR < "$HUB_FILE"
  [ -n "$HUB" ] || return 1
  HUBR=${HUBR:-$HUB}
  return 0
}

make_hub() { # 허브 세션 등록 + 허브 CLAUDE.md 생성. 성공 시 HUB/HUBR 설정됨 (허브는 단일 패널 → 이름=역할)
  if get_hub; then # 허브는 하나만 — 이미 있으면 새로 만들지 않는다
    warn "only one hub allowed — '$HUB · $HUBR' is already the hub (replace: loomo rm $HUB, then loomo hub)"
    return 1
  fi
  ask "  hub name [hub]: "; read -r HUB; HUB=${HUB:-hub}; HUBR="$HUB"
  # read -e: 경로 입력 중 탭(파일명) 완성
  ask "  hub working directory [~/loomo-hub]: "; read -e -r HUBD; HUBD=$(abspath "${HUBD:-$HOME/loomo-hub}")
  ask_resume_id "$HUBD"
  echo "$HUB|$HUBR|$HUBD|$RID" >> "$WS_CONF"; mkdir -p "$HUBD"
  echo "$HUB|$HUBR" > "$HUB_FILE"
  local ht="$TEMPLATE_DIR/CLAUDE-section-hub.en.md"
  [ "$LOOMO_LANG" = "ko" ] && ht="$TEMPLATE_DIR/CLAUDE-section-hub.md"
  if [ -f "$ht" ] && ! grep -qE '허브\(비서\)|hub \(secretary\)' "$HUBD/$AGENT_CONV" 2>/dev/null; then
    { [ -f "$HUBD/$AGENT_CONV" ] && echo ""; sed -e "s/{{HUB_SESSION}}/$HUB/g" -e "s/{{HUB_ROLE}}/$HUBR/g" "$ht"; } >> "$HUBD/$AGENT_CONV"
  fi
  ok "hub ready — ${C_B}$HUB · $HUBR${C_X}"
}

cmd_add() {
  banner "add · register a project"
  note "concept: session = a project / pane (role) = one resident AI on it"
  note "Ctrl+C anytime — everything entered so far is saved."
  mkdir -p "$CONFIG_DIR"
  trap 'echo ""; ok "saved so far: $WS_CONF   (continue: loomo add / check: loomo list)"; exit 0' INT
  step "Default AI model"
  note "the AI you mostly use here. You can override it per pane (mix claude & codex)."
  choose DEFAG "default AI model" claude codex
  case "$DEFAG" in codex) DEFAG=codex ;; *) DEFAG=claude ;; esac
  ok "default model: ${C_B}$DEFAG${C_X}"
  get_hub >/dev/null 2>&1 || true   # 기존 허브가 있으면 프로젝트를 거기에 링크. 허브 생성/지정은 init 밖에서 — loomo hub / loomo adopt
  step "Your project"
  note "A ${C_B}project${C_D} is one workspace = one tmux session (e.g. 'myapp')."
  note "Inside it you add ${C_B}roles${C_D} — one AI per role (server / web / app...)."
  note "(To add more projects, run 'loomo add' again later.)"
  echo ""
  local S
  while :; do
    ask "project name (no spaces): "; read -r S
    [ -z "$S" ] && { warn "project name is required"; exit 2; }
    case "$S" in
      *" "*)    warn "no spaces in a project name — use - or _ (e.g. my-app)"; continue ;;
      *[=:.]* ) warn "'=', ':', '.' are not allowed in a session name"; continue ;;
    esac
    if tmux has-session -t "=$S" 2>/dev/null; then warn "'$S' is already a running session — pick another name"; continue; fi
    if [ -f "$WS_CONF" ] && LC_ALL=C awk -F'|' -v s="$S" '$1==s{f=1} END{exit !f}' "$WS_CONF"; then
      warn "'$S' is already registered — pick another name (or remove it: loomo rm $S)"; continue
    fi
    break
  done
  local NROLE=0
  note "roles are the AIs in this project — one per role (e.g. server / web / app)"
  while :; do
    echo ""
    ask "  add a role (empty = done): "; read -r R; [ -z "$R" ] && break
    case "$R" in *" "*) warn "no spaces in a role name — use - or _"; continue ;; esac
    if [ -f "$WS_CONF" ] && LC_ALL=C awk -F'|' -v s="$S" -v r="$R" '$1==s && $2==r{f=1} END{exit !f}' "$WS_CONF"; then
      warn "role '$R' already exists in '$S' — pick another"; continue
    fi
    if [ -t 0 ] && [ -t 1 ] && { : </dev/tty; } 2>/dev/null; then   # 사람 터미널 → 화살표 디렉터리 브라우저
      _pick_dir "${LAST_DIR:-$PWD}"
      D="$PICKED_DIR"
      [ -z "$D" ] && { ask "  directory for '$R' (직접 입력, Tab 자동완성): "; read -e -r D; D=$(abspath "$D"); }
    else
      ask "  directory for '$R': "; read -e -r D; D=$(abspath "$D")
    fi
    [ -z "$D" ] && { warn "directory is required"; continue; }
    LAST_DIR=$(dirname "$D")   # 다음 역할은 이 근처에서 브라우징 시작 (형제 프로젝트 빠르게)
    if [ ! -d "$D" ]; then                       # 오타/미존재 방지 — 없으면 만들지 물어봄
      warn "no such directory: $D"
      choose CR "create it?" Yes No
      if [ "$CR" = "Yes" ]; then mkdir -p "$D" && ok "created: $D"; else skip "not created — make it before you start"; fi
    fi
    if [ "$DEFAG" = "codex" ]; then choose AG "model for '$R'" codex claude
    else choose AG "model for '$R'" claude codex; fi
    case "$AG" in codex) AG=codex ;; *) AG=claude ;; esac
    load_agent_profile "$AG"   # convention file (CLAUDE.md/AGENTS.md) & session lookup follow this model
    ask_resume_id "$D"
    echo "$S|$R|$D|$RID|$AG" >> "$WS_CONF"
    append_role_template "$D" "$S" "$R" "$HUB" "$HUBR"
    ok "  + role '$R' ${C_D}($AG)${C_X}"
    NROLE=$((NROLE + 1))
  done
  [ "$NROLE" -eq 0 ] && { warn "no roles added — nothing to start (run 'loomo add' again)"; exit 0; }
  banner "done"
  ok "project '${C_B}$S${C_X}${C_G}' configured — $NROLE role(s), saved to $WS_CONF"
  echo ""
  if [ -t 0 ] && [ -t 1 ]; then          # 사람 터미널 → 방금 만든 이 프로젝트만 켤지 물어봄
    choose GO "Start '$S' now?" Yes No
    if [ "$GO" = "Yes" ]; then cmd_up "$S"; return $?; else note "start later: ${C_C}loomo up $S${C_X}"; fi
  else
    echo "  ${C_C}loomo up $S${C_X}    # start this project"
    echo "  ${C_C}loomo list${C_X}     # who you can talk to"
  fi
}

_reg_sessions() { # workspaces.conf 에 등록된(=이미 묶인) 세션명들
  [ -f "$WS_CONF" ] && grep -vE '^[[:space:]]*(#|$)' "$WS_CONF" | awk -F'|' '{print $1}' | awk '!seen[$0]++'
}

_is_reg() { # $1=세션 → 등록돼 있으면 0
  [ -f "$WS_CONF" ] && grep -vE '^[[:space:]]*(#|$)' "$WS_CONF" | LC_ALL=C awk -F'|' -v s="$1" '$1==s{f=1} END{exit !f}'
}

_conf_del() { # $1=session $2=role $3=dir → workspaces.conf 에서 해당 줄 제거
  [ -f "$WS_CONF" ] || return 0
  local tmp; tmp=$(mktemp)
  LC_ALL=C awk -F'|' -v s="$1" -v r="$2" -v d="$3" '!($1==s && $2==r && $3==d)' "$WS_CONF" > "$tmp" && mv "$tmp" "$WS_CONF"
}

cmd_hub() {
  banner "hub · register the manager session"
  note "a hub is a 'secretary' session that directs your projects for you."
  note "e.g. \"add an API on the server and a button on the web\" → it dispatches & reports."
  echo ""
  mkdir -p "$CONFIG_DIR"
  make_hub || exit 1
  echo ""
  echo "${C_B}next:${C_X} ${C_C}loomo ws $HUB${C_X}   ${C_D}(projects registered from now on will link to this hub)${C_X}"
}

cmd_list() {
  command -v tmux >/dev/null 2>&1 || { warn "tmux missing"; exit 1; }
  tmux ls >/dev/null 2>&1 || { echo "no live tmux sessions — start one with 'loomo ws <session>'"; exit 0; }
  banner "list · address book"
  note "sessions message each other automatically — this is who is reachable"
  echo ""
  printf "${C_B}%-16s %-16s %-6s %-8s %s${C_X}\n" "SESSION" "ROLE" "CONV" "RUN" "DIRECTORY"
  tmux list-panes -a -F '#{session_name}|#{pane_title}|#{pane_current_path}|#{pane_current_command}' \
  | while IFS='|' read -r S T D C; do
      # 규약 체크: Claude Code는 상위 폴더 CLAUDE.md도 상속하므로 조상 디렉터리까지 올라가며 확인
      conv="❌"; dir="$D"
      while [ -n "$dir" ] && [ "$dir" != "/" ]; do
        if [ -f "$dir/$AGENT_CONV" ] && grep -qE '세션 요청 - KEY|session request - KEY' "$dir/$AGENT_CONV" 2>/dev/null; then conv="✅"; break; fi
        dir=$(dirname "$dir")
      done
      case "$C" in claude|codex|node|[0-9]*.[0-9]*) run="$AGENT_CMD" ;; *) run="$C" ;; esac   # 에이전트 CLI는 버전 문자열로 보고되기도 함
      printf '%-16s %-16s %-6s %-8s %s\n' "$S" "$T" "$conv" "$run" "$D"
    done
  echo ""
  note "CONV ❌ = pane not wired into the bridge yet → adopt it with 'loomo adopt' to get replies."
}

remove_bridge_section() { # $1=dir — 규약 파일에서 자동 삽입된 규약 블록만 제거 (백업 .bak, 그 외 내용 보존)
  local f="$1/$AGENT_CONV"
  [ -f "$f" ] || return 1
  grep -q '<!-- claude-tell-bridge' "$f" || return 1
  cp "$f" "$f.bak"
  awk '/<!-- claude-tell-bridge/{skip=1} !skip{print} /<!-- \/claude-tell-bridge -->/{skip=0}' "$f.bak" > "$f"
  grep -q '[^[:space:]]' "$f" || rm -f "$f"   # 우리 블록뿐이었다면 빈 파일 정리
  return 0
}

cmd_rm() { # 워크스페이스 삭제 — 종료 + 설정 제거 + 규약 블록 제거 (프로젝트 파일은 무손상)
  local NAME="${1:-}"
  if [ -z "$NAME" ]; then
    banner "rm · delete workspace"
    local NAMES=""
    [ -f "$WS_CONF" ] && NAMES=$(grep -vE '^[[:space:]]*(#|$)' "$WS_CONF" | awk -F'|' '{print $1}' | awk '!seen[$0]++')
    if [ -z "$NAMES" ]; then warn "no registered workspaces"; exit 2; fi
    if [ -t 1 ] && { : </dev/tty; } 2>/dev/null; then    # TTY → 어느 워크스페이스를 지울지 화살표로 고르기
      note "which workspace to delete? ${C_D}(↑↓ · Enter select · q cancel)${C_X}"
      pick_menu <<EOF
$NAMES
EOF
      [ $? -eq 130 ] && { skip "cancelled"; exit 0; }
      NAME="$PICKED"
    else
      echo "usage: ${C_B}loomo rm <session>${C_X}   ${C_D}(to just stop it: loomo down <session>)${C_X}"
      step "registered workspaces"; printf '%s\n' "$NAMES"
      exit 2
    fi
  fi
  banner "rm · delete workspace '$NAME'"
  local IN_CONF=0 RUNNING=0
  [ -f "$WS_CONF" ] && LC_ALL=C awk -F'|' -v s="$NAME" '$1==s{f=1} END{exit !f}' "$WS_CONF" && IN_CONF=1
  tmux has-session -t "=$NAME" 2>/dev/null && RUNNING=1
  if [ "$IN_CONF" = 0 ] && [ "$RUNNING" = 0 ]; then warn "'$NAME' — not in config and not running"; exit 1; fi
  note "this will remove:"
  [ "$RUNNING" = 1 ] && note "  · the running session (open conversations close)"
  [ "$IN_CONF" = 1 ] && note "  · its entries in workspaces.conf"
  [ "$IN_CONF" = 1 ] && note "  · the bridge convention block in its convention file"
  get_hub && [ "$HUB" = "$NAME" ] && note "  · the hub designation"
  note "  ${C_B}your project files & code are untouched${C_X}"
  choose A "proceed with delete?" No Yes
  [ "$A" = "Yes" ] || { skip "cancelled"; exit 0; }
  [ "$RUNNING" = 1 ] && tmux kill-session -t "=$NAME" && ok "session killed"
  if [ "$IN_CONF" = 1 ]; then
    local DIRS D
    DIRS=$(grep -vE '^[[:space:]]*(#|$)' "$WS_CONF" | LC_ALL=C awk -F'|' -v s="$NAME" '$1==s{print $3}' | sort -u)
    cp "$WS_CONF" "$WS_CONF.bak"
    LC_ALL=C awk -F'|' -v s="$NAME" '$1!=s' "$WS_CONF.bak" > "$WS_CONF"
    ok "removed from config ${C_D}(backup: $WS_CONF.bak)${C_X}"
    while IFS= read -r D; do
      [ -n "$D" ] || continue
      D=${D/#\~/$HOME}
      if grep -vE '^[[:space:]]*(#|$)' "$WS_CONF" | LC_ALL=C awk -F'|' -v d="$D" '$3==d{f=1} END{exit !f}'; then
        skip "convention kept: $D (another session uses this directory)"
      elif remove_bridge_section "$D"; then
        ok "convention removed: $D/$AGENT_CONV ${C_D}(backup .bak)${C_X}"
      fi
    done <<EOF
$DIRS
EOF
  fi
  if get_hub && [ "$HUB" = "$NAME" ]; then
    rm -f "$HUB_FILE"
    ok "hub released — register a new one: ${C_C}loomo hub${C_X}"
  fi
  return 0
}

cmd_down() { # 끄기 — tmux 세션 종료만, 설정은 유지 (반대: tell up)
  local T="${1:-}"
  banner "down · stop"
  if [ -z "$T" ]; then
    local RUNNING="" S
    if [ -f "$WS_CONF" ]; then
      while IFS= read -r S; do
        [ -n "$S" ] && tmux has-session -t "=$S" 2>/dev/null && RUNNING="$RUNNING$S
"
      done <<EOF
$(grep -vE '^[[:space:]]*(#|$)' "$WS_CONF" | awk -F'|' '{print $1}' | awk '!seen[$0]++')
EOF
    fi
    if [ -z "$RUNNING" ]; then note "no registered sessions are running"; exit 0; fi
    if [ -t 1 ] && { : </dev/tty; } 2>/dev/null; then    # TTY → 어느 세션을 끌지 화살표로 (맨 위=전부)
      note "which session to stop? ${C_D}(↑↓ · Enter select · q cancel)${C_X}"
      pick_menu <<EOF
— all of them —
$RUNNING
EOF
      [ $? -eq 130 ] && { skip "cancelled"; exit 0; }
      if [ "$PICK_IDX" = 0 ]; then T="--all"; else T="$PICKED"; fi
    else
      echo "usage: ${C_B}loomo down <session>${C_X} or ${C_B}loomo down --all${C_X}   ${C_D}(config kept — full delete: loomo rm)${C_X}"
      step "running sessions"; printf '%s' "$RUNNING" | sed 's/^/  · /'
      exit 2
    fi
  fi
  case "$T" in
    --all|-all|all)
      if [ ! -f "$WS_CONF" ]; then warn "no config: $WS_CONF"; exit 1; fi
      local NAMES S RUN=""
      NAMES=$(grep -vE '^[[:space:]]*(#|$)' "$WS_CONF" | awk -F'|' '{print $1}' | awk '!seen[$0]++')
      while IFS= read -r S; do
        [ -n "$S" ] && tmux has-session -t "=$S" 2>/dev/null && RUN="$RUN$S
"
      done <<EOF
$NAMES
EOF
      if [ -z "$RUN" ]; then note "no registered sessions are running"; exit 0; fi
      echo "will stop (registered sessions only — other tmux sessions untouched):"
      printf '%s' "$RUN" | sed 's/^/  · /'
      choose A "stop them all? open conversations will close" No Yes
      [ "$A" = "Yes" ] || { skip "cancelled"; exit 0; }
      while IFS= read -r S; do
        [ -n "$S" ] && tmux kill-session -t "=$S" 2>/dev/null && ok "$S stopped"
      done <<EOF
$RUN
EOF
      note "start again: ${C_C}loomo up --all${C_X}"
      ;;
    *)
      tmux has-session -t "=$T" 2>/dev/null || { warn "not running: $T"; exit 1; }
      local n; n=$(tmux list-panes -t "=$T" 2>/dev/null | wc -l | tr -d ' ')
      choose A "stop '$T' ($n panes)? open conversations will close" No Yes
      if [ "$A" = "Yes" ]; then
        tmux kill-session -t "=$T" && ok "$T stopped — start again: ${C_C}loomo up $T${C_X}"
      else
        skip "cancelled"
      fi
      ;;
  esac
}

ws_boot() { # $1=세션 — 설정대로 부트스트랩(패널 분할·제목·claude 실행). 이미 떠 있으면 그대로 0
  local NAME="$1" p=""
  tmux has-session -t "=$NAME" 2>/dev/null && return 0
  # 주의: 루프 안 tmux 호출에 </dev/null — stdin(설정 라인)을 삼켜 다음 패널을 건너뛰는 버그 방지
  grep -vE '^[[:space:]]*(#|$)' "$WS_CONF" | LC_ALL=C awk -F'|' -v s="$NAME" '$1==s' | while IFS='|' read -r S R D RID AG; do
    D=${D/#\~/$HOME}
    if [ ! -d "$D" ]; then echo "⚠️ directory missing: $D (skipped)"; continue; fi
    if ! tmux has-session -t "=$NAME" 2>/dev/null; then
      p=$(tmux new-session -d -P -F '#{pane_id}' -s "$NAME" -c "$D" </dev/null)
    else
      # split 타깃은 세션명이 아니라 패널이어야 함 → 직전 패널 id 사용
      p=$(tmux split-window -h -P -F '#{pane_id}' -t "$p" -c "$D" </dev/null)
    fi
    tmux select-pane -t "$p" -T "$R" </dev/null
    tmux set-option -p -t "$p" remain-on-exit on </dev/null 2>/dev/null   # 구버전 tmux(pane-died) 캐스케이드용 — 패널 프로세스 죽어도 남겨두면 pane-died 훅이 세션을 kill
    # 4번째=대화 세션ID(이어받기) · 5번째=에이전트(패널별 claude/codex). exec로 셸 대체(종료 시 패널 정리)
    tmux send-keys -t "$p" "$(agent_launch "${AG:-$TELL_AGENT}" "${RID:-}")" Enter </dev/null
  done
  tmux has-session -t "=$NAME" 2>/dev/null || return 1
  tmux select-layout -t "=$NAME" tiled 2>/dev/null
  # 패널 하나라도 닫히면(에이전트 종료/Ctrl-C 등) 세션(프로젝트) 통째로 종료 — 개별 패널만 닫는 걸 막음.
  # loomo가 만든 이 세션에만 걸리는 훅이라 tmux 전역 설정은 안 건드림. (remain-on-exit는 위 루프에서 패널별로 설정)
  # pane-exited: 신버전 tmux(≥3.2) / pane-died: 구버전(remain-on-exit와 짝). 없는 훅 이름은 조용히 무시됨.
  tmux set-hook -t "$NAME" pane-exited "kill-session -t '=$NAME'" 2>/dev/null
  tmux set-hook -t "$NAME" pane-died   "kill-session -t '=$NAME'" 2>/dev/null
  return 0
}

cmd_layout() { # 패널 배치 변경 — tmux.conf 편집 없이 프리셋으로. tell layout [<세션>] <프리셋>
  local a1="${1:-}" a2="${2:-}" NAME PRESET
  if [ -z "$a1" ]; then
    banner "layout · pane layout"
    echo "usage: ${C_B}loomo layout [<session>] <preset>${C_X}"
    note "presets: $LAYOUT_PRESETS"
    note "omit the session to target the current one (when run inside a pane)"
    exit 2
  fi
  if [ -n "$a2" ]; then NAME="$a1"; PRESET="$a2"
  else
    PRESET="$a1"   # 세션 생략 → 현재 세션 자동 감지
    [ -n "${TMUX_PANE:-}" ] && NAME=$(tmux display-message -p -t "$TMUX_PANE" '#{session_name}' 2>/dev/null)
    [ -z "${NAME:-}" ] && { warn "specify a session: loomo layout <session> <preset>"; exit 2; }
  fi
  case " $LAYOUT_PRESETS " in *" $PRESET "*) ;; *) warn "unknown preset: $PRESET"; note "available: $LAYOUT_PRESETS"; exit 2 ;; esac
  tmux has-session -t "=$NAME" 2>/dev/null || { warn "session not running: $NAME"; exit 1; }
  # select-layout -t는 target-window라 '=세션:'처럼 콜론으로 윈도우를 명시해야 함('=세션'만 주면 pane으로 오해)
  tmux select-layout -t "=$NAME:" "$PRESET" >/dev/null 2>&1 && ok "$NAME → ${C_B}$PRESET${C_X}" || { warn "failed to apply layout"; exit 1; }
}

cmd_ws() {
  local NAME="${1:-}"
  if [ ! -f "$WS_CONF" ]; then echo "no config: $WS_CONF — run 'loomo add' first"; exit 1; fi
  if [ -z "$NAME" ]; then
    echo "── running ──"; tmux ls 2>/dev/null || echo "(none)"
    echo "── registered workspaces ──"
    grep -vE '^[[:space:]]*(#|$)' "$WS_CONF" | awk -F'|' '{print $1}' | sort -u
    exit 0
  fi
  ws_boot "$NAME" || { echo "unknown workspace: $NAME"; exit 1; }
  if [ -n "${TMUX:-}" ]; then tmux switch-client -t "=$NAME"; else tmux attach -t "=$NAME"; fi
}

cmd_up() { # 켜기 — <세션>: 켜고 접속 / --all: 전부 켜고 허브 접속 / 인자 없음: 피커(TTY) 또는 목록(비TTY)
  local TABS=0 ONLY="" ALL=0 a
  for a in "$@"; do
    case "$a" in
      -t|--tabs) TABS=1 ;;
      --all|-all|all) ALL=1 ;;
      *) ONLY="$a" ;;
    esac
  done
  if [ ! -f "$WS_CONF" ]; then echo "no config: $WS_CONF — run 'loomo add' first"; exit 1; fi
  if [ -z "$ONLY" ] && [ "$ALL" = "0" ]; then # 인자 없음
    local PICKLIST; PICKLIST=$(grep -vE '^[[:space:]]*(#|$)' "$WS_CONF" | awk -F'|' '{print $1}' | awk '!seen[$0]++')
    [ -n "$PICKLIST" ] || { warn "nothing registered — run 'loomo add' first"; exit 1; }
    banner "up · what to start"
    if [ -t 0 ] && [ -t 1 ]; then # 사람 터미널 → 화살표 피커
      echo ""
      note "↑↓ move · Enter start & attach · a start all · q quit"
      echo ""
      pick_project <<EOF
$PICKLIST
EOF
      case "$PICK_ACT" in
        enter) ONLY="$PICKED" ;;   # 아래 단일 켜기+접속으로 진행
        all)   ALL=1 ;;            # 아래 전체 켜기로 진행
        *)     exit 0 ;;
      esac
    else # 비TTY(에이전트/스크립트) → 파싱 가능한 정적 목록 유지
      step "registered projects"
      printf '%s\n' "$PICKLIST" | while IFS= read -r s; do
        [ -n "$s" ] || continue
        if tmux has-session -t "=$s" 2>/dev/null; then echo "  ${C_G}● $s${C_X} ${C_D}(running)${C_X}"; else echo "  ${C_D}○ $s${C_X}"; fi
      done
      echo ""
      note "start one:  ${C_C}${BRAND} up <project>${C_X}"
      note "start all:  ${C_C}${BRAND} up --all${C_X}   ${C_D}(+ --tabs for a terminal tab per session)${C_X}"
      exit 0
    fi
  fi
  if [ -n "$ONLY" ]; then # 하나 켜기 → TTY면 접속까지
    banner "up · start '$ONLY'"
    if tmux has-session -t "=$ONLY" 2>/dev/null; then
      skip "$ONLY — already running"
    elif ws_boot "$ONLY"; then
      ok "$ONLY started"
    else
      warn "unknown workspace: $ONLY (list: loomo ws)"; exit 1
    fi
    if [ "$TABS" = "1" ]; then open_terminal_tab "$ONLY" && ok "opened: $ONLY"; exit 0; fi
    if [ -t 0 ] && [ -t 1 ]; then # 사람 → 바로 접속
      if [ -n "${TMUX:-}" ]; then tmux switch-client -t "=$ONLY"; else tmux attach -t "=$ONLY"; fi
    else
      note "attach: loomo ws $ONLY"   # 에이전트/스크립트는 attach 불가 — 안내만
    fi
    exit 0
  fi
  banner "up · start all"
  local NAMES; NAMES=$(grep -vE '^[[:space:]]*(#|$)' "$WS_CONF" | awk -F'|' '{print $1}' | awk '!seen[$0]++')
  [ -n "$NAMES" ] || { warn "nothing registered — run 'loomo add' first"; exit 1; }
  local S
  while IFS= read -r S; do
    if tmux has-session -t "=$S" 2>/dev/null; then
      skip "$S — already running"
    elif ws_boot "$S"; then
      ok "$S started"
    else
      warn "$S failed to boot (check directories: loomo ws $S)"
    fi
  done <<EOF
$NAMES
EOF
  local TARGET=""
  get_hub && tmux has-session -t "=$HUB" 2>/dev/null && TARGET="$HUB"
  [ -z "$TARGET" ] && TARGET=$(printf '%s\n' "$NAMES" | head -1)
  echo ""
  if [ "$TABS" = "1" ]; then # 세션마다 터미널 탭 — 허브는 마지막(=포커스)에
    while IFS= read -r S; do
      [ "$S" = "$TARGET" ] && continue
      tmux has-session -t "=$S" 2>/dev/null || continue
      open_terminal_tab "$S" && ok "opened: $S"
    done <<EOF
$NAMES
EOF
    open_terminal_tab "$TARGET" && { if [ "$TARGET" = "${HUB:-}" ]; then ok "opened: $TARGET (hub · focused)"; else ok "opened: $TARGET (focused)"; fi; }
    exit 0
  fi
  if [ "$TARGET" = "${HUB:-}" ]; then ok "attaching: $TARGET (hub)"; else ok "attaching: $TARGET"; fi
  if [ -n "${TMUX:-}" ]; then tmux switch-client -t "=$TARGET"; else tmux attach -t "=$TARGET"; fi
}
