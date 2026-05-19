#!/usr/bin/env bash
#
# browsers.sh — Browsers category.
#
# Apps in this module:
#   * Brave Browser            — official Brave APT repository
#   * Firefox Developer Edition — official Mozilla APT repository
#
# Both are installed from signed official repositories so every package is
# cryptographically verified by APT.

# ---------------------------------------------------------------------------
# Brave Browser
# ---------------------------------------------------------------------------
readonly BRAVE_PKG="brave-browser"
readonly BRAVE_KEY_URL="https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg"
readonly BRAVE_KEY_PATH="${SYSTEM_KEYRING_DIR}/brave-browser.gpg"
readonly BRAVE_SOURCE_PATH="/etc/apt/sources.list.d/brave-browser-release.list"

app_brave_install() {
  ui_step "Installing Brave Browser"
  if system_pkg_installed "$BRAVE_PKG"; then
    ui_warn "Brave is already installed (v$(system_pkg_version "$BRAVE_PKG"))."
    return 0
  fi
  system_require_sudo || return 1
  system_ensure_base_deps || return 1

  ui_info "Adding Brave's official signing key and repository..."
  system_download_keyring "$BRAVE_KEY_URL" "$BRAVE_KEY_PATH" || return 1
  system_write_apt_source "$BRAVE_SOURCE_PATH" \
    "deb [signed-by=${BRAVE_KEY_PATH}] https://brave-browser-apt-release.s3.brave.com/ stable main"

  system_apt_update || return 1
  if system_as_root apt-get install -y "$BRAVE_PKG"; then
    ui_success "Brave installed (v$(system_pkg_version "$BRAVE_PKG"))."
  else
    ui_error "Brave installation failed."
    return 1
  fi
}

app_brave_uninstall() {
  ui_step "Uninstalling Brave Browser"
  system_require_sudo || return 1

  if system_pkg_installed "$BRAVE_PKG"; then
    system_as_root apt-get purge -y "$BRAVE_PKG"
    system_as_root apt-get autoremove -y --purge
  else
    ui_warn "Brave package is not installed; cleaning up any leftovers."
  fi

  ui_info "Removing Brave repository and signing key..."
  system_as_root rm -f -- \
    "$BRAVE_SOURCE_PATH" "$BRAVE_KEY_PATH" \
    /usr/share/keyrings/brave-browser-archive-keyring.gpg

  system_purge_user_data "$HOME/.config/BraveSoftware" "$HOME/.cache/BraveSoftware"
  system_apt_update
  ui_success "Brave fully removed."
}

app_brave_update() {
  ui_step "Updating Brave Browser"
  if ! system_pkg_installed "$BRAVE_PKG"; then
    ui_warn "Brave is not installed; nothing to update."
    return 0
  fi
  system_require_sudo || return 1
  system_apt_update   || return 1

  local current candidate
  current="$(system_pkg_version "$BRAVE_PKG")"
  candidate="$(system_pkg_candidate "$BRAVE_PKG")"
  if [[ -n "$candidate" && "$candidate" != "$current" ]]; then
    ui_info "New version available: ${current} -> ${candidate}"
    system_as_root apt-get install -y --only-upgrade "$BRAVE_PKG" \
      && ui_success "Brave updated to v$(system_pkg_version "$BRAVE_PKG")."
  else
    ui_success "Brave is already up to date (v${current})."
  fi
}

# app_brave_status — print the status string; exit 0 if installed, 1 if not.
app_brave_status() {
  if system_pkg_installed "$BRAVE_PKG"; then
    printf '%s' "${C_GREEN}v$(system_pkg_version "$BRAVE_PKG")${C_RESET}"
    return 0
  fi
  printf '%s' "${C_DIM}not installed${C_RESET}"
  return 1
}

# app_brave_latest — print the latest version offered by the APT index.
app_brave_latest() {
  local candidate
  candidate="$(system_pkg_candidate "$BRAVE_PKG")"
  printf '%s' "${candidate:-unknown}"
}

# ---------------------------------------------------------------------------
# Firefox Developer Edition
# ---------------------------------------------------------------------------
readonly FXDEV_PKG="firefox-devedition"
readonly FXDEV_KEY_URL="https://packages.mozilla.org/apt/repo-signing-key.gpg"
readonly FXDEV_KEY_PATH="${SYSTEM_KEYRING_DIR}/packages.mozilla.org.asc"
readonly FXDEV_SOURCE_PATH="/etc/apt/sources.list.d/mozilla.list"
readonly FXDEV_PIN_PATH="/etc/apt/preferences.d/mozilla"

app_firefox_dev_install() {
  ui_step "Installing Firefox Developer Edition"
  if system_pkg_installed "$FXDEV_PKG"; then
    ui_warn "Firefox Developer Edition is already installed (v$(system_pkg_version "$FXDEV_PKG"))."
    return 0
  fi
  system_require_sudo || return 1
  system_ensure_base_deps || return 1

  ui_info "Adding Mozilla's official signing key and repository..."
  system_download_keyring "$FXDEV_KEY_URL" "$FXDEV_KEY_PATH" || return 1
  system_write_apt_source "$FXDEV_SOURCE_PATH" \
    "deb [signed-by=${FXDEV_KEY_PATH}] https://packages.mozilla.org/apt mozilla main"

  # Pin so Mozilla's builds take priority over the distribution's Firefox.
  ui_info "Pinning the Mozilla repository for priority..."
  printf '%s\n' \
    "Package: *" \
    "Pin: origin packages.mozilla.org" \
    "Pin-Priority: 1000" | system_as_root tee "$FXDEV_PIN_PATH" >/dev/null

  system_apt_update || return 1
  if system_as_root apt-get install -y "$FXDEV_PKG"; then
    ui_success "Firefox Developer Edition installed (v$(system_pkg_version "$FXDEV_PKG"))."
  else
    ui_error "Firefox Developer Edition installation failed."
    return 1
  fi
}

app_firefox_dev_uninstall() {
  ui_step "Uninstalling Firefox Developer Edition"
  system_require_sudo || return 1

  if system_pkg_installed "$FXDEV_PKG"; then
    system_as_root apt-get purge -y "$FXDEV_PKG"
    system_as_root apt-get autoremove -y --purge
  else
    ui_warn "Firefox Developer Edition package is not installed; cleaning up any leftovers."
  fi

  ui_info "Removing Mozilla repository, signing key and pin..."
  system_as_root rm -f -- "$FXDEV_SOURCE_PATH" "$FXDEV_KEY_PATH" "$FXDEV_PIN_PATH"

  # Profiles live under ~/.mozilla/firefox, a directory shared with regular
  # Firefox installs, so it is intentionally NOT deleted automatically.
  if [[ -d "$HOME/.mozilla/firefox" ]]; then
    ui_info "Browser profiles kept at ~/.mozilla/firefox (shared with other Firefox installs)."
    ui_info "Remove it manually if you also want to wipe Developer Edition profiles."
  fi
  system_apt_update
  ui_success "Firefox Developer Edition fully removed."
}

app_firefox_dev_update() {
  ui_step "Updating Firefox Developer Edition"
  if ! system_pkg_installed "$FXDEV_PKG"; then
    ui_warn "Firefox Developer Edition is not installed; nothing to update."
    return 0
  fi
  system_require_sudo || return 1
  system_apt_update   || return 1

  local current candidate
  current="$(system_pkg_version "$FXDEV_PKG")"
  candidate="$(system_pkg_candidate "$FXDEV_PKG")"
  if [[ -n "$candidate" && "$candidate" != "$current" ]]; then
    ui_info "New version available: ${current} -> ${candidate}"
    system_as_root apt-get install -y --only-upgrade "$FXDEV_PKG" \
      && ui_success "Firefox Developer Edition updated to v$(system_pkg_version "$FXDEV_PKG")."
  else
    ui_success "Firefox Developer Edition is already up to date (v${current})."
  fi
}

# app_firefox_dev_status — print the status string; exit 0 if installed, 1 if not.
app_firefox_dev_status() {
  if system_pkg_installed "$FXDEV_PKG"; then
    printf '%s' "${C_GREEN}v$(system_pkg_version "$FXDEV_PKG")${C_RESET}"
    return 0
  fi
  printf '%s' "${C_DIM}not installed${C_RESET}"
  return 1
}

# app_firefox_dev_latest — print the latest version offered by the APT index.
app_firefox_dev_latest() {
  local candidate
  candidate="$(system_pkg_candidate "$FXDEV_PKG")"
  printf '%s' "${candidate:-unknown}"
}

# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------
registry_add_category "browsers" "Browsers"
registry_add_app "brave"       "browsers" "Brave Browser"
registry_add_app "firefox_dev" "browsers" "Firefox Developer Edition"
