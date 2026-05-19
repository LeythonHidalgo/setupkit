#!/usr/bin/env bash
#
# registry.sh — central catalog of categories and apps.
#
# Modules under modules/ self-register here at load time. The menu in
# setup.sh is generated entirely from this data, so adding a new category
# or app never requires touching the menu code.
#
# Each app implements handlers named app_<id>_<action>:
#   install / uninstall / update — perform the action
#   status — print a short status, exit 0 if installed
#   latest — print the latest available version

# Ordered list of category ids.
REGISTRY_CATEGORIES=()
# category id -> human readable label.
declare -A REGISTRY_CATEGORY_LABEL
# category id -> space separated app ids (registration order).
declare -A REGISTRY_CATEGORY_APPS
# app id -> human readable name.
declare -A REGISTRY_APP_NAME

# registry_add_category <id> <label>
registry_add_category() {
  local id="$1" label="$2"
  [[ -z "${REGISTRY_CATEGORY_LABEL[$id]:-}" ]] && REGISTRY_CATEGORIES+=("$id")
  REGISTRY_CATEGORY_LABEL["$id"]="$label"
}

# registry_add_app <app_id> <category_id> <display_name>
registry_add_app() {
  local app_id="$1" category_id="$2" name="$3"
  REGISTRY_APP_NAME["$app_id"]="$name"
  REGISTRY_CATEGORY_APPS["$category_id"]+="${REGISTRY_CATEGORY_APPS[$category_id]:+ }${app_id}"
}

# registry_dispatch <app_id> <install|uninstall|status|update>
# Routes an action to the app's handler function.
registry_dispatch() {
  local app_id="$1" action="$2" fn="app_${app_id}_${action}"
  if ! declare -F "$fn" >/dev/null; then
    ui_error "Action '${action}' is not implemented for '${app_id}'."
    return 1
  fi
  "$fn"
}
