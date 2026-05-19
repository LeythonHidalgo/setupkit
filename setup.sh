#!/usr/bin/env bash
#
# setupkit — Linux workspace provisioning tool.
#
# Automates installation, deep removal and updates of common applications
# from their official repositories on Debian / Ubuntu based systems.
#
# Usage: ./setup.sh
#
set -uo pipefail

# Resolve this script's directory so it runs correctly from any location.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# --- Load libraries ---------------------------------------------------------
# shellcheck source=lib/ui.sh
. "${SCRIPT_DIR}/lib/ui.sh"
# shellcheck source=lib/system.sh
. "${SCRIPT_DIR}/lib/system.sh"
# shellcheck source=lib/registry.sh
. "${SCRIPT_DIR}/lib/registry.sh"

# --- Load modules -----------------------------------------------------------
# Each module under modules/ self-registers its category and apps.
for _module in "${SCRIPT_DIR}"/modules/*.sh; do
  [[ -e "$_module" ]] || continue
  # shellcheck source=/dev/null
  . "$_module"
done
unset _module

trap 'printf "\n"; ui_info "Interrupted."; exit 130' INT

# --- Menus ------------------------------------------------------------------

# app_menu <app_id> — per-app actions, shown contextually: "Install" when
# absent, or "Update" and "Uninstall" when installed.
app_menu() {
  local app="$1" choice status_text installed
  while true; do
    ui_header
    status_text="$(registry_dispatch "$app" status)"
    installed=$?
    printf '  %s   %s\n' "${C_BOLD}${REGISTRY_APP_NAME[$app]}${C_RESET}" "$status_text"
    ui_rule
    if (( installed == 0 )); then
      printf '  %s1%s) Update       %slatest available: %s%s\n' \
        "$C_CYAN" "$C_RESET" "$C_DIM" "$(registry_dispatch "$app" latest)" "$C_RESET"
      printf '  %s2%s) Uninstall (deep clean)\n' "$C_CYAN" "$C_RESET"
    else
      printf '  %s1%s) Install\n' "$C_CYAN" "$C_RESET"
    fi
    printf '  %sb%s) Back\n' "$C_CYAN" "$C_RESET"
    ui_rule
    read -rp "  Select an action: " choice || exit 0
    if (( installed == 0 )); then
      case "$choice" in
        1) registry_dispatch "$app" update;    ui_pause ;;
        2) registry_dispatch "$app" uninstall; ui_pause ;;
        b|B) return ;;
        '') ;;
        *) ui_error "Invalid option."; ui_pause ;;
      esac
    else
      case "$choice" in
        1) registry_dispatch "$app" install; ui_pause ;;
        b|B) return ;;
        '') ;;
        *) ui_error "Invalid option."; ui_pause ;;
      esac
    fi
  done
}

# category_menu <category_id> — list apps of a category with their status.
category_menu() {
  local cat="$1" choice i app
  local -a apps
  read -ra apps <<< "${REGISTRY_CATEGORY_APPS[$cat]:-}"
  while true; do
    ui_header
    printf '  %s\n' "${C_BOLD}${REGISTRY_CATEGORY_LABEL[$cat]}${C_RESET}"
    ui_rule
    i=1
    for app in "${apps[@]}"; do
      printf '  %s%2d%s) %-30s %s\n' "$C_CYAN" "$i" "$C_RESET" \
        "${REGISTRY_APP_NAME[$app]}" "$(registry_dispatch "$app" status)"
      ((i++))
    done
    ui_rule
    printf '  %s a%s) Install every app in this category\n' "$C_CYAN" "$C_RESET"
    printf '  %s b%s) Back\n'                               "$C_CYAN" "$C_RESET"
    ui_rule
    read -rp "  Select an app: " choice || exit 0
    case "$choice" in
      a|A)
        for app in "${apps[@]}"; do
          registry_dispatch "$app" install
        done
        ui_pause
        ;;
      b|B) return ;;
      '') ;;
      *)
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#apps[@]} )); then
          app_menu "${apps[$((choice - 1))]}"
        else
          ui_error "Invalid option."; ui_pause
        fi
        ;;
    esac
  done
}

# main_menu — top level category selection.
main_menu() {
  local choice i cat
  while true; do
    ui_header
    printf '  %s\n' "${C_BOLD}Main menu${C_RESET} ${C_DIM}— choose a category${C_RESET}"
    ui_rule
    i=1
    for cat in "${REGISTRY_CATEGORIES[@]}"; do
      printf '  %s%2d%s) %s\n' "$C_CYAN" "$i" "$C_RESET" "${REGISTRY_CATEGORY_LABEL[$cat]}"
      ((i++))
    done
    ui_rule
    printf '  %s q%s) Quit\n' "$C_CYAN" "$C_RESET"
    ui_rule
    read -rp "  Select a category: " choice || exit 0
    case "$choice" in
      q|Q) ui_info "Goodbye."; exit 0 ;;
      '') ;;
      *)
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#REGISTRY_CATEGORIES[@]} )); then
          category_menu "${REGISTRY_CATEGORIES[$((choice - 1))]}"
        else
          ui_error "Invalid option."; ui_pause
        fi
        ;;
    esac
  done
}

# --- Entry point ------------------------------------------------------------
main() {
  if [[ ${EUID} -eq 0 ]]; then
    ui_error "Do not run setupkit as root."
    ui_info  "Run it as your normal user; sudo is requested only when needed."
    exit 1
  fi

  system_detect_distro       || exit 1
  system_require_debian_based || exit 1

  if (( ${#REGISTRY_CATEGORIES[@]} == 0 )); then
    ui_error "No modules found under ${SCRIPT_DIR}/modules/"
    exit 1
  fi

  main_menu
}

main "$@"
