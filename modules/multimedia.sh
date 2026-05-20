#!/usr/bin/env bash
#
# multimedia.sh — Multimedia category.
#
# Apps in this module:
#   * OBS Studio — official Flathub release (com.obsproject.Studio)
#   * VLC        — official Debian/Ubuntu repositories
#
# The OBS Project recommends Flatpak as the cross-distribution official
# channel for Linux; VideoLAN ships VLC through the regular distro repos.

# ---------------------------------------------------------------------------
# OBS Studio  (official Flathub release)
# ---------------------------------------------------------------------------
readonly OBS_FLATPAK_ID="com.obsproject.Studio"
_OBS_LATEST_CACHE=""

# obs_installed_version / obs_remote_version — read versions from flatpak.
# LC_ALL=C keeps field labels in English so the awk match is locale-stable.
obs_installed_version() {
  LC_ALL=C flatpak info "$OBS_FLATPAK_ID" 2>/dev/null \
    | awk -F': +' '/^[[:space:]]+Version:/ {print $2; exit}'
}

# Cached per session to avoid hitting Flathub on every menu redraw.
obs_remote_version() {
  if [[ -z "$_OBS_LATEST_CACHE" ]]; then
    _OBS_LATEST_CACHE="$(
      LC_ALL=C flatpak remote-info flathub "$OBS_FLATPAK_ID" 2>/dev/null \
        | awk -F': +' '/^[[:space:]]+Version:/ {print $2; exit}'
    )"
  fi
  printf '%s' "$_OBS_LATEST_CACHE"
}

app_obs_install() {
  ui_step "Installing OBS Studio"
  if flatpak info "$OBS_FLATPAK_ID" >/dev/null 2>&1; then
    ui_warn "OBS Studio is already installed (v$(obs_installed_version))."
    return 0
  fi
  system_require_sudo || return 1
  system_ensure_flatpak || return 1

  ui_info "Installing OBS Studio from Flathub..."
  if system_as_root flatpak install -y flathub "$OBS_FLATPAK_ID"; then
    ui_success "OBS Studio installed (v$(obs_installed_version))."
  else
    ui_error "OBS Studio installation failed."
    return 1
  fi
}

app_obs_uninstall() {
  ui_step "Uninstalling OBS Studio"
  if flatpak info "$OBS_FLATPAK_ID" >/dev/null 2>&1; then
    system_require_sudo || return 1
    system_as_root flatpak uninstall -y --delete-data "$OBS_FLATPAK_ID"
  else
    ui_warn "OBS Studio is not installed."
  fi
  system_purge_user_data "$HOME/.var/app/${OBS_FLATPAK_ID}"
  system_flatpak_deep_clean
  ui_success "OBS Studio fully removed."
}

app_obs_update() {
  ui_step "Updating OBS Studio"
  if ! flatpak info "$OBS_FLATPAK_ID" >/dev/null 2>&1; then
    ui_warn "OBS Studio is not installed; nothing to update."
    return 0
  fi
  system_require_sudo || return 1

  local current latest
  current="$(obs_installed_version)"
  latest="$(obs_remote_version)"
  if [[ -n "$latest" && "$latest" == "$current" ]]; then
    ui_success "OBS Studio is already up to date (v${current})."
    return 0
  fi
  ui_info "Updating OBS Studio..."
  if system_as_root flatpak update -y "$OBS_FLATPAK_ID"; then
    ui_success "OBS Studio updated to v$(obs_installed_version)."
  else
    ui_error "OBS Studio update failed."
    return 1
  fi
}

# app_obs_status — print the status string; exit 0 if installed, 1 if not.
app_obs_status() {
  if flatpak info "$OBS_FLATPAK_ID" >/dev/null 2>&1; then
    local v; v="$(obs_installed_version)"
    printf '%s' "${C_GREEN}${v:+v}${v:-installed}${C_RESET}"
    return 0
  fi
  printf '%s' "${C_DIM}not installed${C_RESET}"
  return 1
}

# app_obs_latest — print the latest version published on Flathub.
app_obs_latest() {
  local v
  v="$(obs_remote_version)"
  printf '%s' "${v:-unknown}"
}

# ---------------------------------------------------------------------------
# VLC  (ships in the official Debian/Ubuntu repositories)
# ---------------------------------------------------------------------------
readonly VLC_PKG="vlc"

app_vlc_install() {
  ui_step "Installing VLC"
  if system_pkg_installed "$VLC_PKG"; then
    ui_warn "VLC is already installed (v$(system_pkg_version "$VLC_PKG"))."
    return 0
  fi
  system_require_sudo || return 1
  system_apt_update   || return 1
  if system_as_root apt-get install -y "$VLC_PKG"; then
    ui_success "VLC installed (v$(system_pkg_version "$VLC_PKG"))."
  else
    ui_error "VLC installation failed."
    return 1
  fi
}

app_vlc_uninstall() {
  ui_step "Uninstalling VLC"
  if ! system_pkg_installed "$VLC_PKG"; then
    ui_warn "VLC is not installed."
  else
    system_require_sudo || return 1
    system_as_root apt-get purge -y "$VLC_PKG"
    system_as_root apt-get autoremove -y --purge
  fi
  system_purge_user_data "$HOME/.config/vlc"
  rm -rf -- "$HOME/.cache/vlc" "$HOME/.local/share/vlc"
  ui_success "VLC fully removed."
}

app_vlc_update() {
  ui_step "Updating VLC"
  if ! system_pkg_installed "$VLC_PKG"; then
    ui_warn "VLC is not installed; nothing to update."
    return 0
  fi
  system_require_sudo || return 1
  system_apt_update   || return 1

  local current candidate
  current="$(system_pkg_version "$VLC_PKG")"
  candidate="$(system_pkg_candidate "$VLC_PKG")"
  if [[ -n "$candidate" && "$candidate" != "$current" ]]; then
    ui_info "New version available: ${current} -> ${candidate}"
    system_as_root apt-get install -y --only-upgrade "$VLC_PKG" \
      && ui_success "VLC updated to v$(system_pkg_version "$VLC_PKG")."
  else
    ui_success "VLC is already up to date (v${current})."
  fi
}

# app_vlc_status — print the status string; exit 0 if installed, 1 if not.
app_vlc_status() {
  if system_pkg_installed "$VLC_PKG"; then
    printf '%s' "${C_GREEN}v$(system_pkg_version "$VLC_PKG")${C_RESET}"
    return 0
  fi
  printf '%s' "${C_DIM}not installed${C_RESET}"
  return 1
}

# app_vlc_latest — print the latest version offered by the APT index.
app_vlc_latest() {
  local candidate
  candidate="$(system_pkg_candidate "$VLC_PKG")"
  printf '%s' "${candidate:-unknown}"
}

# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------
registry_add_category "multimedia" "Multimedia"
registry_add_app "obs" "multimedia" "OBS Studio"
registry_add_app "vlc" "multimedia" "VLC"
