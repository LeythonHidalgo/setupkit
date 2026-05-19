#!/usr/bin/env bash
#
# ui.sh — presentation layer: colors, banners and message helpers.
# Sourced by setup.sh; not meant to be executed directly.

# Enable colors only when stdout is an interactive terminal.
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RED=$'\033[0;31m'
  C_GREEN=$'\033[0;32m'
  C_YELLOW=$'\033[0;33m'
  C_BLUE=$'\033[0;34m'
  C_CYAN=$'\033[0;36m'
else
  C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_CYAN=''
fi

# ui_banner — print the SETUPKIT logo with a vertical cyan-to-blue gradient.
ui_banner() {
  local -a logo=(
'  ███████╗███████╗████████╗██╗   ██╗██████╗ ██╗  ██╗██╗████████╗'
'  ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗██║ ██╔╝██║╚══██╔══╝'
'  ███████╗█████╗     ██║   ██║   ██║██████╔╝█████╔╝ ██║   ██║   '
'  ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ ██╔═██╗ ██║   ██║   '
'  ███████║███████╗   ██║   ╚██████╔╝██║     ██║  ██╗██║   ██║   '
'  ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     ╚═╝  ╚═╝╚═╝   ╚═╝   '
  )
  # 256-color ramp: bright cyan at the top fading to deep blue.
  local -a shades=(51 45 39 33 27 21)
  local i
  printf '\n'
  for i in "${!logo[@]}"; do
    if [[ -n "$C_RESET" ]]; then
      printf '\033[1;38;5;%sm%s\033[0m\n' "${shades[$i]}" "${logo[$i]}"
    else
      printf '%s\n' "${logo[$i]}"
    fi
  done
  printf '\n'
  printf '%s\n' "  ${C_DIM}Professional Linux Workspace Installer · Debian / Ubuntu${C_RESET}"
}

# ui_header — clear the screen and redraw the persistent header.
ui_header() {
  clear
  ui_banner
  printf '%s\n' "  ${C_DIM}System:${C_RESET} ${C_BOLD}${DISTRO_NAME:-unknown}${C_RESET}"
  printf '\n'
}

# Leveled message helpers.
ui_info()    { printf '%s\n' "${C_BLUE}[i]${C_RESET} $*"; }
ui_success() { printf '%s\n' "${C_GREEN}[OK]${C_RESET} $*"; }
ui_warn()    { printf '%s\n' "${C_YELLOW}[!]${C_RESET} $*"; }
ui_error()   { printf '%s\n' "${C_RED}[x]${C_RESET} $*" >&2; }
ui_step()    { printf '%s\n' "${C_CYAN}==>${C_RESET} ${C_BOLD}$*${C_RESET}"; }

# ui_rule — horizontal separator.
ui_rule() {
  printf '%s\n' "${C_DIM}  ────────────────────────────────────────────────${C_RESET}"
}

# ui_pause — wait for the user before redrawing a menu.
ui_pause() {
  printf '\n'
  read -rp "  Press Enter to continue..." _ || true
}

# ui_confirm <prompt> — ask a yes/no question; returns 0 on yes.
ui_confirm() {
  local prompt="${1:-Are you sure?}" reply=''
  read -rp "${C_YELLOW}  ${prompt} [y/N]: ${C_RESET}" reply || true
  [[ "$reply" =~ ^[Yy]$ ]]
}
