#!/usr/bin/env bash
#
# system_network.sh — System & Network category.
#
# Apps in this module:
#   * WireGuard      — official Debian/Ubuntu repositories
#   * Proton VPN     — official Proton VPN APT repository
#   * Mission Center — official Flatpak from Flathub
#
# Every app is installed from an official, verified source.

# ---------------------------------------------------------------------------
# WireGuard  (ships in the official Debian/Ubuntu repositories)
# ---------------------------------------------------------------------------
readonly WIREGUARD_PKG="wireguard"

app_wireguard_install() {
  ui_step "Installing WireGuard"
  if system_pkg_installed "$WIREGUARD_PKG"; then
    ui_warn "WireGuard is already installed (v$(system_pkg_version "$WIREGUARD_PKG"))."
    return 0
  fi
  system_require_sudo || return 1
  system_apt_update   || return 1
  if system_as_root apt-get install -y "$WIREGUARD_PKG"; then
    ui_success "WireGuard installed (v$(system_pkg_version "$WIREGUARD_PKG"))."
    ui_info "Drop a tunnel config at /etc/wireguard/<name>.conf and start it with 'sudo wg-quick up <name>'."
  else
    ui_error "WireGuard installation failed."
    return 1
  fi
}

app_wireguard_uninstall() {
  ui_step "Uninstalling WireGuard"
  if ! system_pkg_installed "$WIREGUARD_PKG"; then
    ui_warn "WireGuard is not installed."
  else
    system_require_sudo || return 1
    if command -v wg >/dev/null 2>&1; then
      local iface
      for iface in $(system_as_root wg show interfaces 2>/dev/null); do
        ui_info "Bringing down tunnel ${iface}..."
        system_as_root wg-quick down "$iface" 2>/dev/null || true
      done
    fi
    system_as_root apt-get purge -y "$WIREGUARD_PKG" wireguard-tools
    system_as_root apt-get autoremove -y --purge
  fi

  if [[ -d /etc/wireguard ]] && ui_confirm "Remove /etc/wireguard (tunnel configs) permanently?"; then
    system_as_root rm -rf -- /etc/wireguard
    ui_success "Tunnel configurations removed."
  fi
  ui_success "WireGuard fully removed."
}

app_wireguard_update() {
  ui_step "Updating WireGuard"
  if ! system_pkg_installed "$WIREGUARD_PKG"; then
    ui_warn "WireGuard is not installed; nothing to update."
    return 0
  fi
  system_require_sudo || return 1
  system_apt_update   || return 1

  local current candidate
  current="$(system_pkg_version "$WIREGUARD_PKG")"
  candidate="$(system_pkg_candidate "$WIREGUARD_PKG")"
  if [[ -n "$candidate" && "$candidate" != "$current" ]]; then
    ui_info "New version available: ${current} -> ${candidate}"
    system_as_root apt-get install -y --only-upgrade "$WIREGUARD_PKG" wireguard-tools \
      && ui_success "WireGuard updated to v$(system_pkg_version "$WIREGUARD_PKG")."
  else
    ui_success "WireGuard is already up to date (v${current})."
  fi
}

# app_wireguard_status — print the status string; exit 0 if installed, 1 if not.
app_wireguard_status() {
  if system_pkg_installed "$WIREGUARD_PKG"; then
    printf '%s' "${C_GREEN}v$(system_pkg_version "$WIREGUARD_PKG")${C_RESET}"
    return 0
  fi
  printf '%s' "${C_DIM}not installed${C_RESET}"
  return 1
}

# app_wireguard_latest — print the latest version offered by the APT index.
app_wireguard_latest() {
  local candidate
  candidate="$(system_pkg_candidate "$WIREGUARD_PKG")"
  printf '%s' "${candidate:-unknown}"
}

# ---------------------------------------------------------------------------
# Proton VPN
# ---------------------------------------------------------------------------
readonly PROTONVPN_PKG="proton-vpn-gnome-desktop"
readonly PROTONVPN_SETUP_PKG="protonvpn-stable-release"
readonly PROTONVPN_PACKAGES_URL="https://repo.protonvpn.com/debian/dists/stable/main/binary-all/Packages"
readonly PROTONVPN_REPO_BASE="https://repo.protonvpn.com/debian"

# protonvpn_setup_deb_url — resolve the URL of the latest release package
# by reading the repository's Packages metadata.
protonvpn_setup_deb_url() {
  local meta filename
  meta="$(curl -fsSL "$PROTONVPN_PACKAGES_URL" 2>/dev/null)" || return 1
  filename="$(printf '%s\n' "$meta" | awk -v pkg="$PROTONVPN_SETUP_PKG" '
    /^Package: / { current=$2; next }
    current==pkg && /^Filename: / { print $2; exit }
  ')"
  [[ -z "$filename" ]] && return 1
  printf '%s/%s' "$PROTONVPN_REPO_BASE" "$filename"
}

app_protonvpn_install() {
  ui_step "Installing Proton VPN"
  if system_pkg_installed "$PROTONVPN_PKG"; then
    ui_warn "Proton VPN is already installed (v$(system_pkg_version "$PROTONVPN_PKG"))."
    return 0
  fi
  system_require_sudo || return 1
  system_ensure_base_deps || return 1

  ui_info "Resolving Proton VPN's release package URL..."
  local url archive
  if ! url="$(protonvpn_setup_deb_url)" || [[ -z "$url" ]]; then
    ui_error "Could not resolve Proton VPN's release package URL."
    return 1
  fi

  archive="$(mktemp --suffix=.deb)"
  ui_info "Downloading Proton VPN's repository configuration..."
  if ! curl -fsSL "$url" -o "$archive"; then
    ui_error "Failed to download ${url}"
    rm -f -- "$archive"
    return 1
  fi
  system_as_root apt-get install -y "$archive"
  rm -f -- "$archive"

  system_apt_update || return 1
  if system_as_root apt-get install -y "$PROTONVPN_PKG"; then
    ui_success "Proton VPN installed (v$(system_pkg_version "$PROTONVPN_PKG"))."
  else
    ui_error "Proton VPN installation failed."
    return 1
  fi
}

app_protonvpn_uninstall() {
  ui_step "Uninstalling Proton VPN"
  system_require_sudo || return 1
  if system_pkg_installed "$PROTONVPN_PKG"; then
    system_as_root apt-get purge -y "$PROTONVPN_PKG" "$PROTONVPN_SETUP_PKG"
    system_as_root apt-get autoremove -y --purge
  else
    ui_warn "Proton VPN is not installed; cleaning up any leftovers."
  fi

  ui_info "Removing Proton VPN repository config and signing key..."
  system_as_root rm -f -- \
    /etc/apt/sources.list.d/protonvpn-stable.list \
    /etc/apt/trusted.gpg.d/protonvpn-stable-release.gpg

  system_purge_user_data "$HOME/.config/Proton" "$HOME/.cache/Proton" \
    "$HOME/.config/protonvpn"
  system_apt_update
  ui_success "Proton VPN fully removed."
}

app_protonvpn_update() {
  ui_step "Updating Proton VPN"
  if ! system_pkg_installed "$PROTONVPN_PKG"; then
    ui_warn "Proton VPN is not installed; nothing to update."
    return 0
  fi
  system_require_sudo || return 1
  system_apt_update   || return 1

  local current candidate
  current="$(system_pkg_version "$PROTONVPN_PKG")"
  candidate="$(system_pkg_candidate "$PROTONVPN_PKG")"
  if [[ -n "$candidate" && "$candidate" != "$current" ]]; then
    ui_info "New version available: ${current} -> ${candidate}"
    system_as_root apt-get install -y --only-upgrade "$PROTONVPN_PKG" \
      && ui_success "Proton VPN updated to v$(system_pkg_version "$PROTONVPN_PKG")."
  else
    ui_success "Proton VPN is already up to date (v${current})."
  fi
}

# app_protonvpn_status — print the status string; exit 0 if installed, 1 if not.
app_protonvpn_status() {
  if system_pkg_installed "$PROTONVPN_PKG"; then
    printf '%s' "${C_GREEN}v$(system_pkg_version "$PROTONVPN_PKG")${C_RESET}"
    return 0
  fi
  printf '%s' "${C_DIM}not installed${C_RESET}"
  return 1
}

# app_protonvpn_latest — print the latest version offered by the APT index.
app_protonvpn_latest() {
  local candidate
  candidate="$(system_pkg_candidate "$PROTONVPN_PKG")"
  printf '%s' "${candidate:-unknown}"
}

# ---------------------------------------------------------------------------
# Mission Center  (official Flathub release)
# ---------------------------------------------------------------------------
readonly MC_FLATPAK_ID="io.missioncenter.MissionCenter"
_MC_LATEST_CACHE=""

# mc_installed_version / mc_remote_version — read the version from flatpak's
# own output. LC_ALL=C keeps field labels in English so the awk match is
# locale-independent (Flatpak translates "Version:" otherwise).
mc_installed_version() {
  LC_ALL=C flatpak info "$MC_FLATPAK_ID" 2>/dev/null \
    | awk -F': +' '/^[[:space:]]+Version:/ {print $2; exit}'
}

# Cached per session to avoid hitting Flathub on every menu redraw.
mc_remote_version() {
  if [[ -z "$_MC_LATEST_CACHE" ]]; then
    _MC_LATEST_CACHE="$(
      LC_ALL=C flatpak remote-info flathub "$MC_FLATPAK_ID" 2>/dev/null \
        | awk -F': +' '/^[[:space:]]+Version:/ {print $2; exit}'
    )"
  fi
  printf '%s' "$_MC_LATEST_CACHE"
}

app_mission_center_install() {
  ui_step "Installing Mission Center"
  if flatpak info "$MC_FLATPAK_ID" >/dev/null 2>&1; then
    ui_warn "Mission Center is already installed (v$(mc_installed_version))."
    return 0
  fi
  system_require_sudo || return 1
  system_ensure_flatpak || return 1

  ui_info "Installing Mission Center from Flathub..."
  if system_as_root flatpak install -y flathub "$MC_FLATPAK_ID"; then
    ui_success "Mission Center installed (v$(mc_installed_version))."
  else
    ui_error "Mission Center installation failed."
    return 1
  fi
}

app_mission_center_uninstall() {
  ui_step "Uninstalling Mission Center"
  if flatpak info "$MC_FLATPAK_ID" >/dev/null 2>&1; then
    system_require_sudo || return 1
    system_as_root flatpak uninstall -y --delete-data "$MC_FLATPAK_ID"
  else
    ui_warn "Mission Center is not installed."
  fi
  system_purge_user_data "$HOME/.var/app/${MC_FLATPAK_ID}"

  # Flatpak runtimes may be shared with other apps, so we ask before removing.
  if command -v flatpak >/dev/null 2>&1 \
     && ui_confirm "Remove unused Flatpak runtimes too? (can free hundreds of MB)"; then
    system_as_root flatpak uninstall --unused -y 2>/dev/null || true
  fi

  # If no Flatpak apps remain at all, offer to drop flatpak itself.
  if command -v flatpak >/dev/null 2>&1 \
     && [[ -z "$(flatpak list --app 2>/dev/null)" ]] \
     && ui_confirm "No Flatpak apps remain — also remove flatpak and the Flathub remote?"; then
    system_as_root flatpak remote-delete --force flathub 2>/dev/null || true
    system_as_root apt-get purge -y flatpak
    system_as_root apt-get autoremove -y --purge
  fi

  ui_success "Mission Center fully removed."
}

app_mission_center_update() {
  ui_step "Updating Mission Center"
  if ! flatpak info "$MC_FLATPAK_ID" >/dev/null 2>&1; then
    ui_warn "Mission Center is not installed; nothing to update."
    return 0
  fi
  system_require_sudo || return 1

  local current latest
  current="$(mc_installed_version)"
  latest="$(mc_remote_version)"
  if [[ -n "$latest" && "$latest" == "$current" ]]; then
    ui_success "Mission Center is already up to date (v${current})."
    return 0
  fi
  ui_info "Updating Mission Center..."
  if system_as_root flatpak update -y "$MC_FLATPAK_ID"; then
    ui_success "Mission Center updated to v$(mc_installed_version)."
  else
    ui_error "Mission Center update failed."
    return 1
  fi
}

# app_mission_center_status — print the status string; exit 0 if installed, 1 if not.
app_mission_center_status() {
  if flatpak info "$MC_FLATPAK_ID" >/dev/null 2>&1; then
    local v; v="$(mc_installed_version)"
    printf '%s' "${C_GREEN}${v:+v}${v:-installed}${C_RESET}"
    return 0
  fi
  printf '%s' "${C_DIM}not installed${C_RESET}"
  return 1
}

# app_mission_center_latest — print the latest version published on Flathub.
app_mission_center_latest() {
  local v
  v="$(mc_remote_version)"
  printf '%s' "${v:-unknown}"
}

# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------
registry_add_category "system_network" "System & Network"
registry_add_app "wireguard"      "system_network" "WireGuard"
registry_add_app "protonvpn"      "system_network" "Proton VPN"
registry_add_app "mission_center" "system_network" "Mission Center"
