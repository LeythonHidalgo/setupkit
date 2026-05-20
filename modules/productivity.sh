#!/usr/bin/env bash
#
# productivity.sh — Productivity category.
#
# Apps in this module:
#   * Notion    — official web app launched as a Chromium PWA
#   * Obsidian  — official .deb from obsidianmd/obsidian-releases (GitHub)
#   * Bitwarden — official .deb from vault.bitwarden.com
#
# Notion does not ship a native Linux app; installing the official web app
# as a PWA keeps the code path on Notion's own servers without resorting to
# unofficial community ports.

# ---------------------------------------------------------------------------
# Notion  (Progressive Web App)
# ---------------------------------------------------------------------------
readonly NOTION_URL="https://www.notion.so/"
readonly NOTION_ICON_URL="https://www.notion.so/apple-touch-icon.png"
readonly NOTION_BIN="/usr/local/bin/notion"
readonly NOTION_DESKTOP="/usr/share/applications/notion.desktop"
readonly NOTION_ICON_PATH="/usr/share/icons/notion.png"
readonly -a NOTION_BROWSERS=(
  brave-browser google-chrome google-chrome-stable
  chromium chromium-browser microsoft-edge microsoft-edge-stable
)

# notion_detect_browser — print the first Chromium-based browser found.
notion_detect_browser() {
  local b
  for b in "${NOTION_BROWSERS[@]}"; do
    command -v "$b" >/dev/null 2>&1 && { printf '%s' "$b"; return 0; }
  done
  return 1
}

# notion_deploy — (re)create the launcher script, icon and .desktop entry.
notion_deploy() {
  local browser
  if ! browser="$(notion_detect_browser)"; then
    ui_error "No Chromium-based browser was found (Brave, Chrome, Chromium, Edge)."
    ui_info  "Install one first — the Browsers category includes Brave."
    return 1
  fi
  ui_info "Using ${browser} as the PWA host."

  local icon_line=""
  ui_info "Downloading the Notion icon..."
  local tmp_icon
  tmp_icon="$(mktemp --suffix=.png)"
  if curl -fsSL "$NOTION_ICON_URL" -o "$tmp_icon"; then
    system_as_root install -D -m 0644 "$tmp_icon" "$NOTION_ICON_PATH"
    icon_line="Icon=${NOTION_ICON_PATH}"
  else
    ui_warn "Could not fetch the Notion icon; the launcher will use a default one."
  fi
  rm -f -- "$tmp_icon"

  ui_info "Creating launcher script and .desktop entry..."
  printf '%s\n' \
    "#!/usr/bin/env bash" \
    "exec ${browser} --app=${NOTION_URL} \"\$@\"" \
    | system_as_root tee "$NOTION_BIN" >/dev/null
  system_as_root chmod 0755 "$NOTION_BIN"

  printf '%s\n' \
    "[Desktop Entry]" \
    "Type=Application" \
    "Name=Notion" \
    "GenericName=Workspace" \
    "${icon_line}" \
    "Exec=${NOTION_BIN} %U" \
    "Comment=Notion official web app, run as a PWA" \
    "Categories=Office;Productivity;" \
    "Terminal=false" \
    | system_as_root tee "$NOTION_DESKTOP" >/dev/null
}

app_notion_install() {
  ui_step "Installing Notion (PWA)"
  if [[ -x "$NOTION_BIN" ]]; then
    ui_warn "Notion launcher already exists at ${NOTION_BIN}."
    return 0
  fi
  system_require_sudo || return 1
  system_ensure_base_deps || return 1
  notion_deploy || return 1
  ui_success "Notion installed (PWA launcher ready)."
}

app_notion_uninstall() {
  ui_step "Uninstalling Notion (PWA)"
  system_require_sudo || return 1
  ui_info "Removing Notion launcher, icon and .desktop entry..."
  system_as_root rm -f -- "$NOTION_BIN" "$NOTION_DESKTOP" "$NOTION_ICON_PATH"
  ui_info "Workspace data lives inside your browser profile and is not touched here."
  ui_success "Notion fully removed."
}

app_notion_update() {
  ui_step "Updating Notion (PWA)"
  if [[ ! -x "$NOTION_BIN" ]]; then
    ui_warn "Notion is not installed; nothing to update."
    return 0
  fi
  system_require_sudo || return 1
  system_ensure_base_deps || return 1
  # The web app itself is always the latest; we just refresh the launcher.
  notion_deploy || return 1
  ui_success "Notion launcher refreshed."
}

# app_notion_status — print the status string; exit 0 if installed, 1 if not.
app_notion_status() {
  if [[ -x "$NOTION_BIN" ]]; then
    printf '%s' "${C_GREEN}installed${C_RESET}"
    return 0
  fi
  printf '%s' "${C_DIM}not installed${C_RESET}"
  return 1
}

# app_notion_latest — Notion is the live web app; no versioned release.
app_notion_latest() {
  printf '%s' "rolling release (web app)"
}

# ---------------------------------------------------------------------------
# Obsidian
# ---------------------------------------------------------------------------
readonly OBSIDIAN_PKG="obsidian"
readonly OBSIDIAN_API="https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest"
_OBSIDIAN_LATEST=""

# obsidian_latest_version — print the latest published Obsidian version,
# cached for the session to avoid hitting the GitHub API repeatedly.
obsidian_latest_version() {
  if [[ -z "$_OBSIDIAN_LATEST" ]]; then
    _OBSIDIAN_LATEST="$(
      curl -fsSL -H 'Accept: application/vnd.github+json' "$OBSIDIAN_API" 2>/dev/null \
        | grep -oE '"tag_name":[[:space:]]*"v[0-9][^"]*"' \
        | head -n1 \
        | sed -E 's/.*"v([^"]+)".*/\1/'
    )"
  fi
  printf '%s' "$_OBSIDIAN_LATEST"
}

# obsidian_install_deb <version> — download and install the official .deb.
obsidian_install_deb() {
  local version="$1" arch url archive
  arch="$(dpkg --print-architecture)"
  url="https://github.com/obsidianmd/obsidian-releases/releases/download/v${version}/obsidian_${version}_${arch}.deb"
  archive="$(mktemp --suffix=.deb)"

  ui_info "Downloading Obsidian ${version} (${arch})..."
  if ! curl -fsSL "$url" -o "$archive"; then
    ui_error "Failed to download Obsidian (${url})."
    rm -f -- "$archive"
    return 1
  fi
  system_as_root apt-get install -y "$archive"
  rm -f -- "$archive"
}

app_obsidian_install() {
  ui_step "Installing Obsidian"
  if system_pkg_installed "$OBSIDIAN_PKG"; then
    ui_warn "Obsidian is already installed (v$(system_pkg_version "$OBSIDIAN_PKG"))."
    return 0
  fi
  system_require_sudo || return 1
  system_ensure_base_deps || return 1

  local version
  ui_info "Looking up the latest Obsidian release..."
  version="$(obsidian_latest_version)"
  if [[ -z "$version" ]]; then
    ui_error "Could not determine the latest Obsidian release."
    return 1
  fi

  obsidian_install_deb "$version" || return 1
  if system_pkg_installed "$OBSIDIAN_PKG"; then
    ui_success "Obsidian installed (v$(system_pkg_version "$OBSIDIAN_PKG"))."
  else
    ui_error "Obsidian installation failed."
    return 1
  fi
}

app_obsidian_uninstall() {
  ui_step "Uninstalling Obsidian"
  system_require_sudo || return 1
  if system_pkg_installed "$OBSIDIAN_PKG"; then
    system_as_root apt-get purge -y "$OBSIDIAN_PKG"
    system_as_root apt-get autoremove -y --purge
  else
    ui_warn "Obsidian is not installed."
  fi
  system_purge_user_data "$HOME/.config/obsidian"
  rm -rf -- "$HOME/.cache/obsidian" "$HOME/.local/share/obsidian"
  ui_success "Obsidian fully removed."
}

app_obsidian_update() {
  ui_step "Updating Obsidian"
  if ! system_pkg_installed "$OBSIDIAN_PKG"; then
    ui_warn "Obsidian is not installed; nothing to update."
    return 0
  fi
  system_require_sudo || return 1

  local current latest
  current="$(system_pkg_version "$OBSIDIAN_PKG")"
  latest="$(obsidian_latest_version)"
  if [[ -z "$latest" ]]; then
    ui_error "Could not determine the latest Obsidian release."
    return 1
  fi
  if [[ "$latest" == "$current" ]]; then
    ui_success "Obsidian is already up to date (v${current})."
    return 0
  fi
  ui_info "New version available: ${current} -> ${latest}"
  obsidian_install_deb "$latest" || return 1
  ui_success "Obsidian updated to v$(system_pkg_version "$OBSIDIAN_PKG")."
}

# app_obsidian_status — print the status string; exit 0 if installed, 1 if not.
app_obsidian_status() {
  if system_pkg_installed "$OBSIDIAN_PKG"; then
    printf '%s' "${C_GREEN}v$(system_pkg_version "$OBSIDIAN_PKG")${C_RESET}"
    return 0
  fi
  printf '%s' "${C_DIM}not installed${C_RESET}"
  return 1
}

# app_obsidian_latest — print the latest GitHub release version.
app_obsidian_latest() {
  local v
  v="$(obsidian_latest_version)"
  printf '%s' "${v:-unknown}"
}

# ---------------------------------------------------------------------------
# Bitwarden
# ---------------------------------------------------------------------------
readonly BITWARDEN_PKG="bitwarden"
readonly BITWARDEN_URL="https://vault.bitwarden.com/download/?app=desktop&platform=linux&variant=deb"
_BITWARDEN_LATEST=""

# bitwarden_latest_version — resolve the redirect URL to read the version
# from the final .deb filename. Cached per session.
bitwarden_latest_version() {
  if [[ -z "$_BITWARDEN_LATEST" ]]; then
    _BITWARDEN_LATEST="$(
      curl -fsSILo /dev/null -w '%{url_effective}\n' "$BITWARDEN_URL" 2>/dev/null \
        | grep -oE 'Bitwarden-[0-9]+\.[0-9]+\.[0-9]+' \
        | head -n1 \
        | sed -E 's/Bitwarden-//'
    )"
  fi
  printf '%s' "$_BITWARDEN_LATEST"
}

# bitwarden_install_deb — download the official .deb (latest) and install it.
bitwarden_install_deb() {
  local archive
  archive="$(mktemp --suffix=.deb)"
  ui_info "Downloading Bitwarden from the official site..."
  if ! curl -fsSL "$BITWARDEN_URL" -o "$archive"; then
    ui_error "Failed to download Bitwarden."
    rm -f -- "$archive"
    return 1
  fi
  system_as_root apt-get install -y "$archive"
  rm -f -- "$archive"
}

app_bitwarden_install() {
  ui_step "Installing Bitwarden"
  if system_pkg_installed "$BITWARDEN_PKG"; then
    ui_warn "Bitwarden is already installed (v$(system_pkg_version "$BITWARDEN_PKG"))."
    return 0
  fi
  system_require_sudo || return 1
  system_ensure_base_deps || return 1

  bitwarden_install_deb || return 1
  if system_pkg_installed "$BITWARDEN_PKG"; then
    ui_success "Bitwarden installed (v$(system_pkg_version "$BITWARDEN_PKG"))."
  else
    ui_error "Bitwarden installation failed."
    return 1
  fi
}

app_bitwarden_uninstall() {
  ui_step "Uninstalling Bitwarden"
  system_require_sudo || return 1
  if system_pkg_installed "$BITWARDEN_PKG"; then
    system_as_root apt-get purge -y "$BITWARDEN_PKG"
    system_as_root apt-get autoremove -y --purge
  else
    ui_warn "Bitwarden is not installed."
  fi
  system_purge_user_data "$HOME/.config/Bitwarden"
  rm -rf -- "$HOME/.cache/Bitwarden" "$HOME/.local/share/Bitwarden"
  ui_success "Bitwarden fully removed."
}

app_bitwarden_update() {
  ui_step "Updating Bitwarden"
  if ! system_pkg_installed "$BITWARDEN_PKG"; then
    ui_warn "Bitwarden is not installed; nothing to update."
    return 0
  fi
  system_require_sudo || return 1

  local current latest
  current="$(system_pkg_version "$BITWARDEN_PKG")"
  latest="$(bitwarden_latest_version)"
  if [[ -n "$latest" && "$latest" == "${current%%-*}" ]]; then
    ui_success "Bitwarden is already up to date (v${current})."
    return 0
  fi
  ui_info "New version available: ${current} -> ${latest:-unknown}"
  bitwarden_install_deb || return 1
  ui_success "Bitwarden updated to v$(system_pkg_version "$BITWARDEN_PKG")."
}

# app_bitwarden_status — print the status string; exit 0 if installed, 1 if not.
app_bitwarden_status() {
  if system_pkg_installed "$BITWARDEN_PKG"; then
    printf '%s' "${C_GREEN}v$(system_pkg_version "$BITWARDEN_PKG")${C_RESET}"
    return 0
  fi
  printf '%s' "${C_DIM}not installed${C_RESET}"
  return 1
}

# app_bitwarden_latest — print the latest version published on the official site.
app_bitwarden_latest() {
  local v
  v="$(bitwarden_latest_version)"
  printf '%s' "${v:-unknown}"
}

# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------
registry_add_category "productivity" "Productivity"
registry_add_app "notion"    "productivity" "Notion (PWA)"
registry_add_app "obsidian"  "productivity" "Obsidian"
registry_add_app "bitwarden" "productivity" "Bitwarden"
