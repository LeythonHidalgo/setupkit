#!/usr/bin/env bash
#
# development.sh — Development category.
#
# Apps in this module:
#   * Visual Studio Code      — official Microsoft APT repository
#   * Git                     — official Debian/Ubuntu repositories
#   * Docker & Docker Compose — official Docker APT repository
#   * Postman                 — official Postman release (dl.pstmn.io)
#
# Every app is installed from an official, verified source.

# ---------------------------------------------------------------------------
# Visual Studio Code
# ---------------------------------------------------------------------------
readonly VSCODE_PKG="code"
readonly VSCODE_KEY_URL="https://packages.microsoft.com/keys/microsoft.asc"
readonly VSCODE_KEY_PATH="${SYSTEM_KEYRING_DIR}/packages.microsoft.asc"
readonly VSCODE_SOURCE_PATH="/etc/apt/sources.list.d/vscode.list"

app_vscode_install() {
  ui_step "Installing Visual Studio Code"
  if system_pkg_installed "$VSCODE_PKG"; then
    ui_warn "Visual Studio Code is already installed (v$(system_pkg_version "$VSCODE_PKG"))."
    return 0
  fi
  system_require_sudo || return 1
  system_ensure_base_deps || return 1

  ui_info "Adding Microsoft's official signing key and repository..."
  system_download_keyring "$VSCODE_KEY_URL" "$VSCODE_KEY_PATH" || return 1
  system_write_apt_source "$VSCODE_SOURCE_PATH" \
    "deb [signed-by=${VSCODE_KEY_PATH}] https://packages.microsoft.com/repos/code stable main"

  system_apt_update || return 1
  if system_as_root apt-get install -y "$VSCODE_PKG"; then
    ui_success "Visual Studio Code installed (v$(system_pkg_version "$VSCODE_PKG"))."
  else
    ui_error "Visual Studio Code installation failed."
    return 1
  fi
}

app_vscode_uninstall() {
  ui_step "Uninstalling Visual Studio Code"
  system_require_sudo || return 1

  if system_pkg_installed "$VSCODE_PKG"; then
    system_as_root apt-get purge -y "$VSCODE_PKG"
    system_as_root apt-get autoremove -y --purge
  else
    ui_warn "Visual Studio Code package is not installed; cleaning up any leftovers."
  fi

  ui_info "Removing Microsoft repository and signing key..."
  system_as_root rm -f -- "$VSCODE_SOURCE_PATH" "$VSCODE_KEY_PATH"

  system_purge_user_data "$HOME/.config/Code" "$HOME/.vscode"
  system_apt_update
  ui_success "Visual Studio Code fully removed."
}

app_vscode_update() {
  ui_step "Updating Visual Studio Code"
  if ! system_pkg_installed "$VSCODE_PKG"; then
    ui_warn "Visual Studio Code is not installed; nothing to update."
    return 0
  fi
  system_require_sudo || return 1
  system_apt_update   || return 1

  local current candidate
  current="$(system_pkg_version "$VSCODE_PKG")"
  candidate="$(system_pkg_candidate "$VSCODE_PKG")"
  if [[ -n "$candidate" && "$candidate" != "$current" ]]; then
    ui_info "New version available: ${current} -> ${candidate}"
    system_as_root apt-get install -y --only-upgrade "$VSCODE_PKG" \
      && ui_success "Visual Studio Code updated to v$(system_pkg_version "$VSCODE_PKG")."
  else
    ui_success "Visual Studio Code is already up to date (v${current})."
  fi
}

# app_vscode_status — print the status string; exit 0 if installed, 1 if not.
app_vscode_status() {
  if system_pkg_installed "$VSCODE_PKG"; then
    printf '%s' "${C_GREEN}v$(system_pkg_version "$VSCODE_PKG")${C_RESET}"
    return 0
  fi
  printf '%s' "${C_DIM}not installed${C_RESET}"
  return 1
}

# app_vscode_latest — print the latest version offered by the APT index.
app_vscode_latest() {
  local candidate
  candidate="$(system_pkg_candidate "$VSCODE_PKG")"
  printf '%s' "${candidate:-unknown}"
}

# ---------------------------------------------------------------------------
# Git  (ships in the official Debian/Ubuntu repositories — no extra repo)
# ---------------------------------------------------------------------------
readonly GIT_PKG="git"

app_git_install() {
  ui_step "Installing Git"
  if system_pkg_installed "$GIT_PKG"; then
    ui_warn "Git is already installed (v$(system_pkg_version "$GIT_PKG"))."
    return 0
  fi
  system_require_sudo || return 1
  system_apt_update   || return 1
  if system_as_root apt-get install -y "$GIT_PKG"; then
    ui_success "Git installed (v$(system_pkg_version "$GIT_PKG"))."
  else
    ui_error "Git installation failed."
    return 1
  fi
}

app_git_uninstall() {
  ui_step "Uninstalling Git"
  if ! system_pkg_installed "$GIT_PKG"; then
    ui_warn "Git is not installed."
  else
    system_require_sudo || return 1
    system_as_root apt-get purge -y "$GIT_PKG"
    system_as_root apt-get autoremove -y --purge
  fi
  system_purge_user_data "$HOME/.gitconfig" "$HOME/.config/git"
  ui_success "Git fully removed."
}

app_git_update() {
  ui_step "Updating Git"
  if ! system_pkg_installed "$GIT_PKG"; then
    ui_warn "Git is not installed; nothing to update."
    return 0
  fi
  system_require_sudo || return 1
  system_apt_update   || return 1

  local current candidate
  current="$(system_pkg_version "$GIT_PKG")"
  candidate="$(system_pkg_candidate "$GIT_PKG")"
  if [[ -n "$candidate" && "$candidate" != "$current" ]]; then
    ui_info "New version available: ${current} -> ${candidate}"
    system_as_root apt-get install -y --only-upgrade "$GIT_PKG" \
      && ui_success "Git updated to v$(system_pkg_version "$GIT_PKG")."
  else
    ui_success "Git is already up to date (v${current})."
  fi
}

# app_git_status — print the status string; exit 0 if installed, 1 if not.
app_git_status() {
  if system_pkg_installed "$GIT_PKG"; then
    printf '%s' "${C_GREEN}v$(system_pkg_version "$GIT_PKG")${C_RESET}"
    return 0
  fi
  printf '%s' "${C_DIM}not installed${C_RESET}"
  return 1
}

# app_git_latest — print the latest version offered by the APT index.
app_git_latest() {
  local candidate
  candidate="$(system_pkg_candidate "$GIT_PKG")"
  printf '%s' "${candidate:-unknown}"
}

# ---------------------------------------------------------------------------
# Docker & Docker Compose
# ---------------------------------------------------------------------------
readonly DOCKER_PKG="docker-ce"
readonly -a DOCKER_PKGS=(docker-ce docker-ce-cli containerd.io
                         docker-buildx-plugin docker-compose-plugin)
readonly DOCKER_KEY_PATH="${SYSTEM_KEYRING_DIR}/docker.asc"
readonly DOCKER_SOURCE_PATH="/etc/apt/sources.list.d/docker.list"

app_docker_install() {
  ui_step "Installing Docker & Docker Compose"
  if system_pkg_installed "$DOCKER_PKG"; then
    ui_warn "Docker is already installed (v$(system_pkg_version "$DOCKER_PKG"))."
    return 0
  fi
  system_require_sudo || return 1
  system_ensure_base_deps || return 1

  # Docker's repository path and codename depend on the distribution.
  local family codename
  case "$DISTRO_ID" in
    ubuntu) family="ubuntu" ;;
    debian) family="debian" ;;
    *) [[ " ${DISTRO_LIKE} " == *ubuntu* ]] && family="ubuntu" || family="debian" ;;
  esac
  if [[ "$family" == "ubuntu" ]]; then
    codename="${DISTRO_UBUNTU_CODENAME:-$DISTRO_CODENAME}"
  else
    codename="$DISTRO_CODENAME"
  fi
  if [[ -z "$codename" ]]; then
    ui_error "Could not determine the distribution codename for the Docker repository."
    return 1
  fi

  ui_info "Adding Docker's official signing key and repository..."
  system_download_keyring "https://download.docker.com/linux/${family}/gpg" \
    "$DOCKER_KEY_PATH" || return 1
  system_write_apt_source "$DOCKER_SOURCE_PATH" \
    "deb [signed-by=${DOCKER_KEY_PATH}] https://download.docker.com/linux/${family} ${codename} stable"

  system_apt_update || return 1
  if ! system_as_root apt-get install -y "${DOCKER_PKGS[@]}"; then
    ui_error "Docker installation failed."
    return 1
  fi

  ui_info "Enabling the Docker service..."
  system_as_root systemctl enable --now docker \
    || ui_warn "Could not enable the Docker service automatically."

  ui_info "Adding '$(id -un)' to the 'docker' group..."
  system_as_root usermod -aG docker "$(id -un)"
  ui_warn "Log out and back in (or run 'newgrp docker') for the group change to apply."

  ui_success "Docker installed (v$(system_pkg_version "$DOCKER_PKG")) with the Compose plugin."
}

app_docker_uninstall() {
  ui_step "Uninstalling Docker & Docker Compose"
  system_require_sudo || return 1

  if system_pkg_installed "$DOCKER_PKG"; then
    system_as_root systemctl disable --now docker.socket docker containerd 2>/dev/null
    system_as_root apt-get purge -y "${DOCKER_PKGS[@]}" docker-ce-rootless-extras
    system_as_root apt-get autoremove -y --purge
  else
    ui_warn "Docker package is not installed; cleaning up any leftovers."
  fi

  ui_info "Removing Docker repository and signing key..."
  system_as_root rm -f -- "$DOCKER_SOURCE_PATH" "$DOCKER_KEY_PATH"

  ui_warn "All Docker images, containers and volumes live in /var/lib/docker."
  if ui_confirm "Delete /var/lib/docker, /var/lib/containerd and /etc/docker permanently?"; then
    system_as_root rm -rf -- /var/lib/docker /var/lib/containerd /etc/docker
    ui_success "Docker data directories removed."
  else
    ui_info "Docker data directories kept."
  fi

  # Drop the 'docker' group membership and the group itself if no one is left.
  if getent group docker >/dev/null; then
    ui_info "Cleaning up the 'docker' group..."
    system_as_root gpasswd -d "$(id -un)" docker 2>/dev/null || true
    if [[ -z "$(getent group docker | cut -d: -f4)" ]]; then
      system_as_root groupdel docker 2>/dev/null || true
    fi
  fi
  rm -rf -- "$HOME/.docker"

  system_apt_update
  ui_success "Docker fully removed."
}

app_docker_update() {
  ui_step "Updating Docker & Docker Compose"
  if ! system_pkg_installed "$DOCKER_PKG"; then
    ui_warn "Docker is not installed; nothing to update."
    return 0
  fi
  system_require_sudo || return 1
  system_apt_update   || return 1

  local current candidate
  current="$(system_pkg_version "$DOCKER_PKG")"
  candidate="$(system_pkg_candidate "$DOCKER_PKG")"
  if [[ -n "$candidate" && "$candidate" != "$current" ]]; then
    ui_info "New version available: ${current} -> ${candidate}"
    system_as_root apt-get install -y --only-upgrade "${DOCKER_PKGS[@]}" \
      && ui_success "Docker updated to v$(system_pkg_version "$DOCKER_PKG")."
  else
    ui_success "Docker is already up to date (v${current})."
  fi
}

# app_docker_status — print the status string; exit 0 if installed, 1 if not.
app_docker_status() {
  if system_pkg_installed "$DOCKER_PKG"; then
    printf '%s' "${C_GREEN}v$(system_pkg_version "$DOCKER_PKG")${C_RESET}"
    return 0
  fi
  printf '%s' "${C_DIM}not installed${C_RESET}"
  return 1
}

# app_docker_latest — print the latest version offered by the APT index.
app_docker_latest() {
  local candidate
  candidate="$(system_pkg_candidate "$DOCKER_PKG")"
  printf '%s' "${candidate:-unknown}"
}

# ---------------------------------------------------------------------------
# Postman  (official tarball; no APT repository exists)
# ---------------------------------------------------------------------------
readonly POSTMAN_URL="https://dl.pstmn.io/download/latest/linux64"
readonly POSTMAN_DIR="/opt/Postman"
readonly POSTMAN_BIN="/usr/local/bin/postman"
readonly POSTMAN_DESKTOP="/usr/share/applications/postman.desktop"

# postman_deploy — download the latest official tarball, install it under
# /opt and refresh the launcher and command-line symlink.
postman_deploy() {
  local archive
  archive="$(mktemp)"
  ui_info "Downloading Postman from the official site..."
  if ! curl -fsSL "$POSTMAN_URL" -o "$archive"; then
    ui_error "Failed to download Postman."
    rm -f -- "$archive"
    return 1
  fi

  ui_info "Installing Postman into ${POSTMAN_DIR}..."
  system_as_root rm -rf -- "$POSTMAN_DIR"
  system_as_root tar -xzf "$archive" -C /opt
  rm -f -- "$archive"

  system_as_root ln -sf "${POSTMAN_DIR}/Postman" "$POSTMAN_BIN"
  printf '%s\n' \
    "[Desktop Entry]" \
    "Type=Application" \
    "Name=Postman" \
    "GenericName=API Client" \
    "Icon=${POSTMAN_DIR}/app/resources/app/assets/icon.png" \
    "Exec=${POSTMAN_DIR}/Postman %U" \
    "Comment=Postman API client" \
    "Categories=Development;" \
    "Terminal=false" \
    "StartupWMClass=Postman" | system_as_root tee "$POSTMAN_DESKTOP" >/dev/null
}

app_postman_install() {
  ui_step "Installing Postman"
  if [[ -d "$POSTMAN_DIR" ]]; then
    ui_warn "Postman is already installed at ${POSTMAN_DIR}."
    return 0
  fi
  system_require_sudo || return 1
  system_ensure_base_deps || return 1
  postman_deploy || return 1
  ui_success "Postman installed."
}

app_postman_uninstall() {
  ui_step "Uninstalling Postman"
  system_require_sudo || return 1
  ui_info "Removing Postman files..."
  system_as_root rm -rf -- "$POSTMAN_DIR"
  system_as_root rm -f  -- "$POSTMAN_BIN" "$POSTMAN_DESKTOP"
  system_purge_user_data "$HOME/.config/Postman"
  ui_success "Postman fully removed."
}

app_postman_update() {
  ui_step "Updating Postman"
  if [[ ! -d "$POSTMAN_DIR" ]]; then
    ui_warn "Postman is not installed; nothing to update."
    return 0
  fi
  system_require_sudo || return 1
  system_ensure_base_deps || return 1
  postman_deploy || return 1
  ui_success "Postman updated to the latest release."
}

# app_postman_status — print the status string; exit 0 if installed, 1 if not.
app_postman_status() {
  if [[ -d "$POSTMAN_DIR" ]]; then
    printf '%s' "${C_GREEN}installed${C_RESET}"
    return 0
  fi
  printf '%s' "${C_DIM}not installed${C_RESET}"
  return 1
}

# app_postman_latest — Postman ships as a self-updating rolling release.
app_postman_latest() {
  printf '%s' "rolling release"
}

# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------
registry_add_category "development" "Development"
registry_add_app "vscode"  "development" "Visual Studio Code"
registry_add_app "git"     "development" "Git"
registry_add_app "docker"  "development" "Docker & Docker Compose"
registry_add_app "postman" "development" "Postman"
