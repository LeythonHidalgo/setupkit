#!/usr/bin/env bash
#
# system.sh — system layer: distro detection, privilege handling and
# reusable APT / repository helpers. Sourced by setup.sh.

# Standard location for repository signing keys on modern Debian/Ubuntu.
readonly SYSTEM_KEYRING_DIR="/etc/apt/keyrings"

# system_detect_distro — read /etc/os-release into DISTRO_* variables.
system_detect_distro() {
  if [[ ! -r /etc/os-release ]]; then
    ui_error "Cannot read /etc/os-release; unsupported system."
    return 1
  fi
  # shellcheck disable=SC1091
  . /etc/os-release
  DISTRO_ID="${ID:-unknown}"
  DISTRO_LIKE="${ID_LIKE:-}"
  DISTRO_NAME="${PRETTY_NAME:-$DISTRO_ID}"
  DISTRO_CODENAME="${VERSION_CODENAME:-}"
  DISTRO_UBUNTU_CODENAME="${UBUNTU_CODENAME:-}"
}

# system_require_debian_based — abort on non Debian/Ubuntu systems.
system_require_debian_based() {
  case " ${DISTRO_ID} ${DISTRO_LIKE} " in
    *" debian "*|*" ubuntu "*) return 0 ;;
  esac
  ui_error "Unsupported distribution: ${DISTRO_NAME}."
  ui_info  "This tool targets Debian and Ubuntu based systems."
  return 1
}

# system_as_root <cmd...> — run a command with root privileges.
system_as_root() {
  if [[ ${EUID} -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

# system_require_sudo — make sure privilege escalation is possible.
system_require_sudo() {
  [[ ${EUID} -eq 0 ]] && return 0
  if ! command -v sudo >/dev/null 2>&1; then
    ui_error "sudo is not installed and you are not root."
    return 1
  fi
  ui_info "Administrator privileges are required; you may be prompted for your password."
  if ! sudo -v; then
    ui_error "Could not obtain sudo privileges."
    return 1
  fi
}

# system_pkg_installed <pkg> — true if a dpkg package is installed.
system_pkg_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

# system_pkg_version <pkg> — installed version (empty if absent).
system_pkg_version() {
  dpkg-query -W -f='${Version}' "$1" 2>/dev/null || true
}

# system_pkg_candidate <pkg> — latest version available from APT.
# LC_ALL=C forces English labels so the awk match is locale-independent.
system_pkg_candidate() {
  LC_ALL=C apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2}'
}

# system_apt_update — refresh the APT package index.
system_apt_update() {
  ui_info "Refreshing package index..."
  system_as_root apt-get update -qq
}

# system_ensure_base_deps — install tools needed to add repositories.
system_ensure_base_deps() {
  local deps=(curl ca-certificates) missing=() d
  for d in "${deps[@]}"; do
    system_pkg_installed "$d" || missing+=("$d")
  done
  if (( ${#missing[@]} )); then
    ui_info "Installing base dependencies: ${missing[*]}"
    system_as_root apt-get update -qq
    system_as_root apt-get install -y "${missing[@]}"
  fi
}

# system_ensure_flatpak — install flatpak and configure the Flathub remote.
system_ensure_flatpak() {
  if ! system_pkg_installed flatpak; then
    ui_info "Installing flatpak..."
    system_as_root apt-get update -qq
    system_as_root apt-get install -y flatpak
  fi
  if ! flatpak remotes 2>/dev/null | awk '{print $1}' | grep -qx flathub; then
    ui_info "Adding the Flathub remote..."
    system_as_root flatpak remote-add --if-not-exists flathub \
      https://dl.flathub.org/repo/flathub.flatpakrepo
  fi
}

# system_download_keyring <url> <dest_path> — fetch a repo signing key.
system_download_keyring() {
  local url="$1" dest="$2"
  system_as_root install -d -m 0755 "$(dirname "$dest")"
  if ! curl -fsSL "$url" | system_as_root tee "$dest" >/dev/null; then
    ui_error "Failed to download signing key from ${url}"
    return 1
  fi
  system_as_root chmod 0644 "$dest"
}

# system_write_apt_source <dest_path> <content> — write a sources list file.
system_write_apt_source() {
  printf '%s\n' "$2" | system_as_root tee "$1" >/dev/null
}

# system_purge_user_data <paths...> — delete leftover user dirs after confirmation.
system_purge_user_data() {
  local existing=() p
  for p in "$@"; do
    [[ -e "$p" ]] && existing+=("$p")
  done
  (( ${#existing[@]} == 0 )) && return 0

  ui_warn "Personal data directories found:"
  for p in "${existing[@]}"; do
    printf '      %s\n' "$p"
  done
  if ui_confirm "Delete these directories permanently?"; then
    rm -rf -- "${existing[@]}"
    ui_success "Personal data removed."
  else
    ui_info "Personal data kept."
  fi
}
