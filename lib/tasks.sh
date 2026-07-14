# loomo — task lifecycle shared by messaging, doctor, and the dashboard
# sourced by bin/tell (not standalone). shell: bash

TASK_FILE="${TASK_FILE:-$CONFIG_DIR/tasks.tsv}"

_task_clean() { # one safe TSV field; keep the dashboard compact
  printf '%s' "$*" | tr '\t\r\n' '   ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' | cut -c1-160
}

task_event() { # key state target_session target_role sender_session sender_role summary
  local key="$1" state="$2" target_s="${3:-}" target_r="${4:-}" sender_s="${5:-}" sender_r="${6:-}" summary="${7:-}"
  mkdir -p "$CONFIG_DIR" || return 1
  touch "$TASK_FILE" || return 1
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(date +%s)" "$key" "$state" "$(_task_clean "$target_s")" "$(_task_clean "$target_r")" \
    "$(_task_clean "$sender_s")" "$(_task_clean "$sender_r")" "$(_task_clean "$summary")" >> "$TASK_FILE"
}

task_latest() { # latest event for every KEY, newest first
  [ -f "$TASK_FILE" ] || return 0
  LC_ALL=C awk -F'\t' 'NF>=3 { row[$2]=$0; ts[$2]=$1 } END { for (k in row) print ts[k] "\t" row[k] }' "$TASK_FILE" \
    | sort -t $'\t' -k1,1nr | cut -f2-
}

_task_known() { # load latest routing fields for a KEY
  local key="$1" row
  row=$(task_latest | LC_ALL=C awk -F'\t' -v k="$key" '$2==k{print; exit}')
  [ -n "$row" ] || return 1
  IFS=$'\t' read -r TASK_TS TASK_KEY TASK_STATE TASK_TARGET_SESSION TASK_TARGET_ROLE TASK_SENDER_SESSION TASK_SENDER_ROLE TASK_SUMMARY <<EOF
$row
EOF
}

cmd_task() {
  local action="${1:-list}" key="${2:-}" state note
  case "$action" in
    ack)
      [ -n "$key" ] || { echo "usage: loomo task ack <KEY> [message]"; return 2; }
      _task_known "$key" || { warn "unknown task: $key"; return 1; }
      shift 2 2>/dev/null || true; note="${*:-request received}"
      if task_event "$key" working "$TASK_TARGET_SESSION" "$TASK_TARGET_ROLE" "$TASK_SENDER_SESSION" "$TASK_SENDER_ROLE" "$note"; then
        echo "[loomo] task $key · working"
      else
        warn "could not save task state: $TASK_FILE"; return 1
      fi
      ;;
    status)
      [ -n "$key" ] || { echo "usage: loomo task status <KEY> <working|needs_approval|failed|cancelled> [message]"; return 2; }
      state="${3:-}"; case "$state" in working|needs_approval|failed|cancelled) ;; *) echo "invalid task state: $state"; return 2 ;; esac
      _task_known "$key" || { warn "unknown task: $key"; return 1; }
      shift 3 2>/dev/null || true; note="${*:-$state}"
      if task_event "$key" "$state" "$TASK_TARGET_SESSION" "$TASK_TARGET_ROLE" "$TASK_SENDER_SESSION" "$TASK_SENDER_ROLE" "$note"; then
        echo "[loomo] task $key · $state"
      else
        warn "could not save task state: $TASK_FILE"; return 1
      fi
      ;;
    list)
      printf '%-8s  %-16s  %-20s  %s\n' KEY STATUS TARGET SUMMARY
      task_latest | while IFS=$'\t' read -r _ k st ts tr _ _ summary; do
        printf '%-8s  %-16s  %-20s  %s\n' "$k" "$st" "$ts${tr:+/$tr}" "$summary"
      done
      ;;
    *) echo "usage: loomo task [list|ack <KEY>|status <KEY> <state>]"; return 2 ;;
  esac
}
