# loomo — adopt — full-screen TUI
# sourced by bin/tell (not standalone). shell: bash

cmd_adopt() {  # TTY → 대체화면 전체화면 프로그램(_adopt_interactive) · non-TTY → legacy sequential
  command -v tmux >/dev/null 2>&1 || { warn "tmux missing"; exit 1; }
  mkdir -p "$CONFIG_DIR"
  if [ -t 0 ] && [ -t 1 ] && { : </dev/tty; } 2>/dev/null; then _adopt_interactive; return $?; fi
  _adopt_legacy
}

_adopt_interactive() { # conf(등록) 섹션 + 미분류. 대체화면 · 뷰포트 · Enter=토글/이동 · ↑↓ · Ctrl-C. 리드로우는 순수(서브프로세스 X)
  get_hub >/dev/null 2>&1 || true
  local NEWLABEL="＋ new session…" top=0 ROWS=24
  printf '\033[?1049h\033[?1000h\033[?1006h\033[?25l\033[?7l'          # 대체화면·마우스트래킹(SGR)·커서숨김·줄바꿈끔
  trap 'printf "\033[?1006l\033[?1000l\033[?7h\033[?25h\033[?1049l"; return 130' INT
  trap 'sz=$(stty size </dev/tty 2>/dev/null); ROWS=${sz%% *}; [ -n "$ROWS" ] || ROWS=24; declare -f _draw >/dev/null && printf "\033[2J" && _draw' WINCH   # 터미널 크기 변경 → 높이 갱신·재그림
  while :; do
    local sz; sz=$(stty size </dev/tty 2>/dev/null); ROWS=${sz%% *}; [ -n "$ROWS" ] || ROWS=24   # 재빌드 때 1회만
    local LSES=() LPID=() LTIT=() LDIR=() ls lp lt ld i
    while IFS='|' read -r ls lp lt ld; do
      [ -n "$ls" ] || continue
      LSES[${#LSES[@]}]="$ls"; LPID[${#LPID[@]}]="$lp"; LTIT[${#LTIT[@]}]="$lt"; LDIR[${#LDIR[@]}]="$ld"
    done < <(tmux list-panes -a -F '#{session_name}|#{pane_id}|#{pane_title}|#{pane_current_path}' 2>/dev/null)

    local IT_TYPE=() IT_SES=() IT_PID=() IT_TIT=() IT_DIR=() IT_AG=() IT_RUN=() CHK=()
    local reg s
    reg=$(_reg_sessions)
    while IFS= read -r s; do
      [ -n "$s" ] || continue
      local isrun=0; tmux has-session -t "=$s" 2>/dev/null && isrun=1     # 헤더당 1회(재빌드 때만)
      IT_TYPE[${#IT_TYPE[@]}]=H; IT_SES[${#IT_SES[@]}]="$s"; IT_PID[${#IT_PID[@]}]=""; IT_TIT[${#IT_TIT[@]}]=""; IT_DIR[${#IT_DIR[@]}]=""; IT_AG[${#IT_AG[@]}]=""; IT_RUN[${#IT_RUN[@]}]="$isrun"; CHK[${#CHK[@]}]=0
      local _cs crole cdir _crid cag pid
      while IFS='|' read -r _cs crole cdir _crid cag; do
        pid=""
        for ((i=0;i<${#LSES[@]};i++)); do
          if [ "${LSES[$i]}" = "$s" ] && [ "${LTIT[$i]}" = "$crole" ]; then pid="${LPID[$i]}"; break; fi
        done
        IT_TYPE[${#IT_TYPE[@]}]=P; IT_SES[${#IT_SES[@]}]="$s"; IT_PID[${#IT_PID[@]}]="$pid"; IT_TIT[${#IT_TIT[@]}]="$crole"; IT_DIR[${#IT_DIR[@]}]="$cdir"; IT_AG[${#IT_AG[@]}]="${cag:-$TELL_AGENT}"; IT_RUN[${#IT_RUN[@]}]=0; CHK[${#CHK[@]}]=0
      done < <(grep -vE '^[[:space:]]*(#|$)' "$WS_CONF" | LC_ALL=C awk -F'|' -v s="$s" '$1==s')
    done <<EOF
$reg
EOF
    IT_TYPE[${#IT_TYPE[@]}]=H; IT_SES[${#IT_SES[@]}]="__UNGROUPED__"; IT_PID[${#IT_PID[@]}]=""; IT_TIT[${#IT_TIT[@]}]=""; IT_DIR[${#IT_DIR[@]}]=""; IT_AG[${#IT_AG[@]}]=""; IT_RUN[${#IT_RUN[@]}]=0; CHK[${#CHK[@]}]=0
    for ((i=0;i<${#LSES[@]};i++)); do
      _is_reg "${LSES[$i]}" && continue
      [ -n "${HUB:-}" ] && [ "${LSES[$i]}" = "$HUB" ] && continue
      [ "${LPID[$i]}" = "${TMUX_PANE:-}" ] && continue
      IT_TYPE[${#IT_TYPE[@]}]=P; IT_SES[${#IT_SES[@]}]="${LSES[$i]}"; IT_PID[${#IT_PID[@]}]="${LPID[$i]}"; IT_TIT[${#IT_TIT[@]}]="${LTIT[$i]}"; IT_DIR[${#IT_DIR[@]}]="${LDIR[$i]}"; IT_AG[${#IT_AG[@]}]="$TELL_AGENT"; IT_RUN[${#IT_RUN[@]}]=0; CHK[${#CHK[@]}]=0
    done
    IT_TYPE[${#IT_TYPE[@]}]=H; IT_SES[${#IT_SES[@]}]="$NEWLABEL"; IT_PID[${#IT_PID[@]}]=""; IT_TIT[${#IT_TIT[@]}]=""; IT_DIR[${#IT_DIR[@]}]=""; IT_AG[${#IT_AG[@]}]=""; IT_RUN[${#IT_RUN[@]}]=0; CHK[${#CHK[@]}]=0

    local n=${#IT_TYPE[@]} sel=0 j key rest x mseq mc
    for ((j=0;j<n;j++)); do [ "${IT_TYPE[$j]}" = P ] && { sel=$j; break; }; done
    [ "$top" -ge "$n" ] && top=0

    _ensure_visible() {  # 선택이 화면 안에 오도록 top 조정 (방향키용)
      local avail=$(( ROWS - 5 )); [ "$avail" -lt 3 ] && avail=3
      [ "$sel" -lt "$top" ] && top=$sel
      [ "$sel" -ge $(( top + avail )) ] && top=$(( sel - avail + 1 ))
      [ "$top" -lt 0 ] && top=0
    }
    _draw() {  # 순수 함수: 서브프로세스 호출 없음. top은 뷰 스크롤값(선택과 독립)
      local head=4 avail=$(( ROWS - 5 )); [ "$avail" -lt 3 ] && avail=3
      local maxtop=$(( n - avail )); [ "$maxtop" -lt 0 ] && maxtop=0
      [ "$top" -gt "$maxtop" ] && top=$maxtop
      [ "$top" -lt 0 ] && top=0
      local last=$(( top + avail )); [ "$last" -gt "$n" ] && last=$n
      printf '\033[H'
      printf '%s%s  🔗 loomo — adopt%s   %s%d–%d / %d%s\033[0m\033[K\n' "${C_C}" "${C_B}" "${C_X}" "${C_D}" $(( top + 1 )) "$last" "$n" "${C_X}"
      if [ -n "${HUB:-}" ]; then printf '  hub: %s%s · %s%s\033[0m\033[K\n' "${C_B}" "$HUB" "$HUBR" "${C_X}"
      else printf '  %shub: none%s\033[0m\033[K\n' "${C_D}" "${C_X}"; fi
      printf '  %s↑↓ 이동 · Enter: 패널 체크 / ═세션═ 위 Enter=이동 · Ctrl-C 종료%s\033[0m\033[K\n' "${C_D}" "${C_X}"
      printf '\033[K\n'
      for ((j=top;j<last;j++)); do
        local mk="  "; [ "$j" -eq "$sel" ] && mk="${C_C}${C_B}❯${C_X} "
        if [ "${IT_TYPE[$j]}" = H ]; then
          case "${IT_SES[$j]}" in
            __UNGROUPED__) printf '%s%s──── ungrouped (미등록 패널) ────%s\033[0m\033[K\n' "$mk" "${C_Y}${C_B}" "${C_X}" ;;
            "$NEWLABEL")   printf '%s%s%s%s\033[0m\033[K\n' "$mk" "${C_Y}${C_B}" "$NEWLABEL" "${C_X}" ;;
            *) local rn="${C_D}○ stopped${C_X}"; [ "${IT_RUN[$j]}" = 1 ] && rn="${C_G}● running${C_X}"
               printf '%s%s══ %s ══%s %s\033[0m\033[K\n' "$mk" "${C_C}${C_B}" "${IT_SES[$j]}" "${C_X}" "$rn" ;;
          esac
        else
          local box="[ ]"; [ "${CHK[$j]}" = 1 ] && box="[x]"
          local live=""; [ -n "${IT_PID[$j]}" ] && live=" ${C_G}•live${C_X}"
          printf '%s   %s %-10s %s%s\033[0m\033[K\n' "$mk" "$box" "${IT_TIT[$j]}" "${IT_DIR[$j]}" "$live"
        fi
      done
      printf '\033[0J'
    }
    _draw

    local rebuilt=0
    while :; do
      IFS= read -rsn1 key </dev/tty || key=IGNORE
      if [ "$key" = $'\x1b' ]; then
        IFS= read -rsn2 -t 1 rest </dev/tty || rest=""
        case "$rest" in
          '[A') key=UP ;;
          '[B') key=DOWN ;;
          '[<') # SGR 마우스: 휠=뷰 스크롤(선택 커서는 안 움직임), 그 외(클릭 등)=무시
            local mseq=""
            while IFS= read -rsn1 -t 1 mc </dev/tty; do mseq="$mseq$mc"; case "$mc" in [Mm]) break ;; esac; done
            case "${mseq%%;*}" in 64) key=WUP ;; 65) key=WDOWN ;; *) key=IGNORE ;; esac ;;
          '[M') IFS= read -rsn3 -t 1 mc </dev/tty; key=IGNORE ;;   # 구형 X10 마우스 3바이트 삼킴
          *) key=IGNORE ;;
        esac
      fi
      case "$key" in
        UP)    sel=$(( (sel - 1 + n) % n )); _ensure_visible ;;
        DOWN)  sel=$(( (sel + 1) % n )); _ensure_visible ;;
        WUP)   top=$(( top - 3 )); [ "$top" -lt 0 ] && top=0 ;;   # 휠 위: 뷰만 스크롤
        WDOWN) top=$(( top + 3 )) ;;                              # 휠 아래(_draw가 상한 클램프)
        "")   if [ "${IT_TYPE[$sel]}" = P ]; then
                CHK[$sel]=$(( 1 - CHK[$sel] ))
              else
                local tgt="${IT_SES[$sel]}"
                [ "$tgt" = "__UNGROUPED__" ] && { _draw; continue; }
                local any=0; for ((x=0;x<n;x++)); do [ "${IT_TYPE[$x]}" = P ] && [ "${CHK[$x]}" = 1 ] && any=1; done
                [ "$any" = 0 ] && { _draw; continue; }
                if [ "$tgt" = "$NEWLABEL" ]; then
                  printf '\033[?1000l\033[?1006l\033[?25h\033[?7h\033[H\033[2J'   # 입력 동안 마우스 트래킹 끔
                  ask "  new session name (no spaces): "; read -r tgt </dev/tty
                  printf '\033[?25l\033[?7l\033[?1000h\033[?1006h'                # 복귀 시 다시 켬
                  case "$tgt" in ""|*" "*|*[=:.]*) rebuilt=1; break ;; esac
                fi
                [ -z "$tgt" ] && { _draw; continue; }
                for ((x=0;x<n;x++)); do
                  [ "${IT_TYPE[$x]}" = P ] || continue
                  [ "${CHK[$x]}" = 1 ] || continue
                  local sses="${IT_SES[$x]}" spid="${IT_PID[$x]}" stit="${IT_TIT[$x]}" sdir="${IT_DIR[$x]}" sag="${IT_AG[$x]}"
                  [ "$sses" = "$tgt" ] && continue
                  if [ -n "$spid" ]; then
                    tmux has-session -t "=$tgt" 2>/dev/null || tmux new-session -d -s "$tgt" -c "$sdir" 2>/dev/null
                    tmux join-pane -s "$spid" -t "=$tgt:" 2>/dev/null && tmux select-pane -t "$spid" -T "$stit" 2>/dev/null
                    tmux select-layout -t "=$tgt" tiled 2>/dev/null
                  fi
                  _conf_del "$sses" "$stit" "$sdir"
                  printf '%s|%s|%s||%s\n' "$tgt" "$stit" "$sdir" "${sag:-$TELL_AGENT}" >> "$WS_CONF"
                  append_role_template "$sdir" "$tgt" "$stit" "${HUB:-}" "${HUBR:-}"
                done
                rebuilt=1; break
              fi ;;
        *) continue ;;   # 무동작 키(휠·기타)에선 재그리기 안 함 → 스크롤 시 검정줄/잔상 방지
      esac
      _draw
    done
    [ "$rebuilt" = 1 ] && continue
  done
}

_adopt_legacy() {
  banner "adopt · bring in AIs you already run (no restart)"
  command -v tmux >/dev/null 2>&1 || { warn "tmux missing"; exit 1; }
  note "Ctrl+C anytime — progress so far is saved."
  mkdir -p "$CONFIG_DIR"
  trap 'echo ""; ok "saved so far: $WS_CONF   (check: loomo list)"; exit 0' INT
  local HAVE_TMUX=0; tmux ls >/dev/null 2>&1 && HAVE_TMUX=1
  step "[1/3] Manager (hub) session — optional"
  if get_hub; then # 허브는 하나만 — 이미 있으면 묻지 않는다
    ok "using existing hub: ${C_B}$HUB · $HUBR${C_X}  (only one hub is kept)"
  else
    note "a hub is a 'secretary' session that dispatches work and aggregates replies."
    note "if one of your sessions already acts as hub, name it as 'session role' (e.g. hub hub)."
    ask "designate a hub [Enter = skip]: "; read -r HUB HUBR _junk
    HUBR=${HUBR:-$HUB}
    if [ -n "$HUB" ]; then
      echo "$HUB|$HUBR" > "$HUB_FILE"
      ok "hub registered: ${C_B}$HUB · $HUBR${C_X}"
    else
      skip "skipped (add later: loomo hub)"
    fi
  fi
  step "[2/3] Adopt live panes — give each pane (AI) its address (role)"
  if [ "$HAVE_TMUX" = "1" ]; then
    tmux list-panes -a -F '#{session_name}|#{pane_id}|#{pane_title}|#{pane_current_path}' | while IFS='|' read -r S P T D; do
      echo ""
      echo "${C_B}▸ project (session) '$S' · pane \"$T\"${C_X}"
      note "  directory: $D"
      ask "  role name for this AI? [Enter=keep \"$T\" / type new / s=skip]: "; read -r ANS </dev/tty
      [ "$ANS" = "s" ] && { skip "skipped"; continue; }
      ROLE=${ANS:-$T}
      [ "$ROLE" != "$T" ] && tmux select-pane -t "$P" -T "$ROLE"
      echo "$S|$ROLE|$D" >> "$WS_CONF"
      append_role_template "$D" "$S" "$ROLE" "$HUB" "$HUBR"
      ok "pane adopted — ${C_B}$S · $ROLE${C_X}"
      choose GO "  run a connection test (ping) with this pane now?" No Yes
      if [ "$GO" = "Yes" ]; then
        "$0" "$S" "$ROLE" "Connection check. Re-read your convention file, then reply via the reply command with the KEY you received — one line: pong ok."
      fi
      note "────────────────────────────────────────"
    done
  else
    skip "no live sessions — skipped"
  fi
  step "[3/3] Bring in conversations from plain terminal tabs — optional"
  note "resume an AI conversation you were having outside the split screen."
  note "a session ID is all you need — its directory is auto-detected from the log."
  while :; do
    echo ""
    ask "project name = session name (empty = done): "; read -r S; [ -z "$S" ] && break
    ask "  role (pane) name for this AI: "; read -r R; [ -z "$R" ] && { warn "role is required"; continue; }
    ask "  session ID to resume (Enter if unknown — I will search by directory): "; read -r RID
    if [ -n "$RID" ]; then
      D=$(dir_from_session_id "$RID") || D=""
      if [ -n "$D" ]; then
        ok "directory auto-detected: $D"
      else
        warn "no conversation log for session ID '$RID' — check the ID or enter the directory"
        ask "  directory: "; read -e -r D; D=$(abspath "$D")
        [ -z "$D" ] && { warn "directory is required"; continue; }
      fi
    else
      ask "  directory (where that conversation lived): "; read -e -r D; D=$(abspath "$D")
      [ -z "$D" ] && { warn "directory is required"; continue; }
      ask_resume_id "$D"
      [ -z "$RID" ] && note "(nothing to resume — registered as a fresh conversation)"
    fi
    echo "$S|$R|$D|$RID" >> "$WS_CONF"
    append_role_template "$D" "$S" "$R" "$HUB" "$HUBR"
    ok "imported — ${C_B}$S · $R${C_X}${RID:+  (resuming $RID)}"
  done
  banner "done"
  ok "check: ${C_C}loomo list${C_X}   ·   start: ${C_C}loomo ws <project>${C_X}"
}
