# loomo — shared helpers (colors, banner/note/ok/warn, abspath)
# sourced by bin/tell (not standalone). shell: bash

banner() {
  echo ""
  echo "${C_C}${C_B}════════════════════════════════════════════════════${C_X}"
  echo "${C_C}${C_B}   🔗 $BRAND — $1${C_X}"
  echo "${C_C}${C_B}════════════════════════════════════════════════════${C_X}"
}

step() { echo ""; echo "${C_Y}${C_B}▶ $1${C_X}"; }
note() { echo "${C_D}  $1${C_X}"; }
ok()   { echo "${C_G}  ✔ $1${C_X}"; }
skip() { echo "${C_D}  ⤼ $1${C_X}"; }
warn() { echo "${C_R}  ⚠ $1${C_X}"; }
ask()  { printf "%s" "${C_B}$1${C_X}"; }
abspath() { # ~ 확장 + 상대경로 → 절대경로 (실행 위치가 달라도 설정이 항상 유효하도록)
  local d="$1"; d=${d/#\~/$HOME}
  case "$d" in ""|/*) ;; *) d="$PWD/$d" ;; esac
  printf '%s' "$d"
}
