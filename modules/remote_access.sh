#!/usr/bin/env bash
#
# remote_access.sh — Remote Access category.
#
# Apps in this module:
#   * AnyDesk  — official AnyDesk APT repository (deb.anydesk.com)
#   * RustDesk — official .deb from rustdesk/rustdesk releases (GitHub)
#
# Every app is installed from an official, verified source.

# ---------------------------------------------------------------------------
# AnyDesk
# ---------------------------------------------------------------------------
readonly ANYDESK_PKG="anydesk"
readonly ANYDESK_KEY_URL="https://keys.anydesk.com/repos/DEB-GPG-KEY"
readonly ANYDESK_KEY_PATH="${SYSTEM_KEYRING_DIR}/anydesk.asc"
readonly ANYDESK_SOURCE_PATH="/etc/apt/sources.list.d/anydesk-stable.list"

app_anydesk_install() {
  ui_step "Installing AnyDesk"
  if system_pkg_installed "$ANYDESK_PKG"; then
    ui_warn "AnyDesk is already installed (v$(system_pkg_version "$ANYDESK_PKG"))."
    return 0
  fi
  system_require_sudo || return 1
  system_ensure_base_deps || return 1

  ui_info "Adding AnyDesk's official signing key and repository..."
  system_download_keyring "$ANYDESK_KEY_URL" "$ANYDESK_KEY_PATH" || return 1
  system_write_apt_source "$ANYDESK_SOURCE_PATH" \
    "deb [signed-by=${ANYDESK_KEY_PATH}] http://deb.anydesk.com/ all main"

  system_apt_update || return 1
  if system_as_root apt-get install -y "$ANYDESK_PKG"; then
    ui_success "AnyDesk installed (v$(system_pkg_version "$ANYDESK_PKG"))."
  else
    ui_error "AnyDesk installation failed."
    return 1
  fi
}

app_anydesk_uninstall() {
  ui_step "Uninstalling AnyDesk"
  system_require_sudo || return 1

  if system_pkg_installed "$ANYDESK_PKG"; then
    system_as_root apt-get purge -y "$ANYDESK_PKG"
    system_as_root apt-get autoremove -y --purge
  else
    ui_warn "AnyDesk package is not installed; cleaning up any leftovers."
  fi

  ui_info "Removing AnyDesk repository and signing key..."
  system_as_root rm -f -- "$ANYDESK_SOURCE_PATH" "$ANYDESK_KEY_PATH"

  system_purge_user_data "$HOME/.anydesk"
  system_apt_update
  ui_success "AnyDesk fully removed."
}

app_anydesk_update() {
  ui_step "Updating AnyDesk"
  if ! system_pkg_installed "$ANYDESK_PKG"; then
    ui_warn "AnyDesk is not installed; nothing to update."
    return 0
  fi
  system_require_sudo || return 1
  system_apt_update   || return 1

  local current candidate
  current="$(system_pkg_version "$ANYDESK_PKG")"
  candidate="$(system_pkg_candidate "$ANYDESK_PKG")"
  if [[ -n "$candidate" && "$candidate" != "$current" ]]; then
    ui_info "New version available: ${current} -> ${candidate}"
    system_as_root apt-get install -y --only-upgrade "$ANYDESK_PKG" \
      && ui_success "AnyDesk updated to v$(system_pkg_version "$ANYDESK_PKG")."
  else
    ui_success "AnyDesk is already up to date (v${current})."
  fi
}

# app_anydesk_status — print the status string; exit 0 if installed, 1 if not.
app_anydesk_status() {
  if system_pkg_installed "$ANYDESK_PKG"; then
    printf '%s' "${C_GREEN}v$(system_pkg_version "$ANYDESK_PKG")${C_RESET}"
    return 0
  fi
  printf '%s' "${C_DIM}not installed${C_RESET}"
  return 1
}

# app_anydesk_latest — print the latest version offered by the APT index.
app_anydesk_latest() {
  local candidate
  candidate="$(system_pkg_candidate "$ANYDESK_PKG")"
  printf '%s' "${candidate:-unknown}"
}

# ---------------------------------------------------------------------------
# RustDesk
# ---------------------------------------------------------------------------
readonly RUSTDESK_PKG="rustdesk"
readonly RUSTDESK_API="https://api.github.com/repos/rustdesk/rustdesk/releases/latest"
_RUSTDESK_LATEST=""

# rustdesk_latest_version — read the latest tag from GitHub, cached per session.
rustdesk_latest_version() {
  if [[ -z "$_RUSTDESK_LATEST" ]]; then
    _RUSTDESK_LATEST="$(
      curl -fsSL -H 'Accept: application/vnd.github+json' "$RUSTDESK_API" 2>/dev/null \
        | grep -oE '"tag_name":[[:space:]]*"[0-9][^"]*"' \
        | head -n1 \
        | sed -E 's/.*"([^"]+)".*/\1/'
    )"
  fi
  printf '%s' "$_RUSTDESK_LATEST"
}

# rustdesk_asset_arch — map dpkg architecture to RustDesk's asset suffix.
rustdesk_asset_arch() {
  case "$(dpkg --print-architecture)" in
    amd64) printf 'x86_64' ;;
    arm64) printf 'aarch64' ;;
    *) return 1 ;;
  esac
}

# rustdesk_install_deb <version> — download and install the official .deb.
rustdesk_install_deb() {
  local version="$1" arch url archive
  if ! arch="$(rustdesk_asset_arch)"; then
    ui_error "Unsupported architecture for RustDesk: $(dpkg --print-architecture)."
    return 1
  fi
  url="https://github.com/rustdesk/rustdesk/releases/download/${version}/rustdesk-${version}-${arch}.deb"
  archive="$(mktemp --suffix=.deb)"

  ui_info "Downloading RustDesk ${version} (${arch})..."
  if ! curl -fsSL "$url" -o "$archive"; then
    ui_error "Failed to download RustDesk (${url})."
    rm -f -- "$archive"
    return 1
  fi
  system_as_root apt-get install -y "$archive"
  rm -f -- "$archive"
}

app_rustdesk_install() {
  ui_step "Installing RustDesk"
  if system_pkg_installed "$RUSTDESK_PKG"; then
    ui_warn "RustDesk is already installed (v$(system_pkg_version "$RUSTDESK_PKG"))."
    return 0
  fi
  system_require_sudo || return 1
  system_ensure_base_deps || return 1

  local version
  ui_info "Looking up the latest RustDesk release..."
  version="$(rustdesk_latest_version)"
  if [[ -z "$version" ]]; then
    ui_error "Could not determine the latest RustDesk release."
    return 1
  fi

  rustdesk_install_deb "$version" || return 1
  if system_pkg_installed "$RUSTDESK_PKG"; then
    ui_success "RustDesk installed (v$(system_pkg_version "$RUSTDESK_PKG"))."
  else
    ui_error "RustDesk installation failed."
    return 1
  fi
}

app_rustdesk_uninstall() {
  ui_step "Uninstalling RustDesk"
  system_require_sudo || return 1
  if system_pkg_installed "$RUSTDESK_PKG"; then
    system_as_root apt-get purge -y "$RUSTDESK_PKG"
    system_as_root apt-get autoremove -y --purge
  else
    ui_warn "RustDesk is not installed."
  fi
  system_purge_user_data "$HOME/.config/rustdesk"
  rm -rf -- "$HOME/.cache/rustdesk" "$HOME/.local/share/rustdesk"
  ui_success "RustDesk fully removed."
}

app_rustdesk_update() {
  ui_step "Updating RustDesk"
  if ! system_pkg_installed "$RUSTDESK_PKG"; then
    ui_warn "RustDesk is not installed; nothing to update."
    return 0
  fi
  system_require_sudo || return 1

  local current latest
  current="$(system_pkg_version "$RUSTDESK_PKG")"
  latest="$(rustdesk_latest_version)"
  if [[ -z "$latest" ]]; then
    ui_error "Could not determine the latest RustDesk release."
    return 1
  fi
  if [[ "$latest" == "$current" ]]; then
    ui_success "RustDesk is already up to date (v${current})."
    return 0
  fi
  ui_info "New version available: ${current} -> ${latest}"
  rustdesk_install_deb "$latest" || return 1
  ui_success "RustDesk updated to v$(system_pkg_version "$RUSTDESK_PKG")."
}

# app_rustdesk_status — print the status string; exit 0 if installed, 1 if not.
app_rustdesk_status() {
  if system_pkg_installed "$RUSTDESK_PKG"; then
    printf '%s' "${C_GREEN}v$(system_pkg_version "$RUSTDESK_PKG")${C_RESET}"
    return 0
  fi
  printf '%s' "${C_DIM}not installed${C_RESET}"
  return 1
}

# app_rustdesk_latest — print the latest GitHub release version.
app_rustdesk_latest() {
  local v
  v="$(rustdesk_latest_version)"
  printf '%s' "${v:-unknown}"
}

# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------
registry_add_category "remote_access" "Remote Access"
registry_add_app "anydesk"  "remote_access" "AnyDesk"
registry_add_app "rustdesk" "remote_access" "RustDesk"
