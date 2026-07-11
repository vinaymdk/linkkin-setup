#!/usr/bin/env bash
# Parse workspace.yml into shell variables (no external YAML deps).

set -euo pipefail

if [[ -z "${LINKKIN_CONFIG_LOADED:-}" ]]; then
  LINKKIN_CONFIG_LOADED=1

  ws_config_file() {
    echo "${WORKSPACE_ROOT}/workspace.yml"
  }

  ws_yaml_section_value() {
    local section="$1" key="$2" file
    file="$(ws_config_file)"
    [[ -f "$file" ]] || return 1
    awk -v section="$section" -v key="$key" '
      $0 ~ "^" section ":" { in_section=1; next }
      in_section && /^[a-zA-Z]/ && $0 !~ /^  / { in_section=0 }
      in_section {
        line=$0; sub(/^[ \t]+/, "", line)
        split(line, a, ":")
        gsub(/^[ \t]+|[ \t]+$/, "", a[1])
        if (a[1] == key) {
          val=substr(line, index(line, ":")+1)
          gsub(/^[ \t]+|[ \t]+$/, "", val)
          print val
          exit
        }
      }
    ' "$file"
  }

  ws_load_config() {
    local file
    file="$(ws_config_file)"
    if [[ ! -f "$file" ]]; then
      echo "workspace.yml not found at $file" >&2
      return 1
    fi

    WS_RUN_DIR="$(ws_yaml_section_value workspace run_dir)"; WS_RUN_DIR="${WS_RUN_DIR:-.linkkin-run}"
    WS_GIT_ORG="$(ws_yaml_section_value git org)"; WS_GIT_ORG="${WS_GIT_ORG:-vinaymdk}"
    WS_REPOS_PARENT="$(ws_yaml_section_value workspace repos_parent)"; WS_REPOS_PARENT="${WS_REPOS_PARENT:-..}"

    PORT_BACKEND="$(ws_yaml_section_value ports backend)"; PORT_BACKEND="${PORT_BACKEND:-8000}"
    PORT_WEB="$(ws_yaml_section_value ports web)"; PORT_WEB="${PORT_WEB:-5173}"
    PORT_ADMIN="$(ws_yaml_section_value ports admin)"; PORT_ADMIN="${PORT_ADMIN:-5174}"
    PORT_SUPPORT="$(ws_yaml_section_value ports support)"; PORT_SUPPORT="${PORT_SUPPORT:-5175}"
    PORT_ICECAST="$(ws_yaml_section_value ports icecast)"; PORT_ICECAST="${PORT_ICECAST:-8089}"

    URL_BACKEND="$(ws_yaml_section_value urls backend)"; URL_BACKEND="${URL_BACKEND:-http://127.0.0.1:$PORT_BACKEND}"
    URL_WEB="$(ws_yaml_section_value urls web)"; URL_WEB="${URL_WEB:-http://127.0.0.1:$PORT_WEB}"
    URL_ADMIN="$(ws_yaml_section_value urls admin)"; URL_ADMIN="${URL_ADMIN:-http://127.0.0.1:$PORT_ADMIN}"
    URL_SUPPORT="$(ws_yaml_section_value urls support)"; URL_SUPPORT="${URL_SUPPORT:-http://127.0.0.1:$PORT_SUPPORT}"
    URL_ICECAST="$(ws_yaml_section_value urls icecast)"; URL_ICECAST="${URL_ICECAST:-http://127.0.0.1:$PORT_ICECAST}"

    PREFLIGHT_MIN_DISK_FREE="$(ws_yaml_section_value preflight min_disk_free_percent)"; PREFLIGHT_MIN_DISK_FREE="${PREFLIGHT_MIN_DISK_FREE:-10}"
    PREFLIGHT_MIN_MEMORY_MB="$(ws_yaml_section_value preflight min_memory_mb)"; PREFLIGHT_MIN_MEMORY_MB="${PREFLIGHT_MIN_MEMORY_MB:-512}"

    WORKSPACE_REPOS=()
    local order label path
    while IFS='|' read -r order label path; do
      [[ -n "$label" && -n "$path" ]] && WORKSPACE_REPOS+=("$label:$path")
    done < <(awk '
      /^  - label:/ {
        if (label != "" && path != "") print order "|" label "|" path
        label = $3; gsub(/"/, "", label); path = ""; order = 99
      }
      /^    path:/ { path = $2; gsub(/"/, "", path) }
      /^    order:/ { order = $2 }
      END { if (label != "" && path != "") print order "|" label "|" path }
    ' "$file" | sort -t'|' -k1,1n)
  }

  ws_repo_by_label() {
    local want="$1" entry label path
    for entry in "${WORKSPACE_REPOS[@]}"; do
      label="${entry%%:*}"
      path="${entry#*:}"
      [[ "$label" == "$want" ]] && echo "$path" && return 0
    done
    return 1
  }

  ws_clone_url() {
    echo "git@github.com:${WS_GIT_ORG}/${1}.git"
  }

  ws_run_dir() {
    echo "$WORKSPACE_ROOT/${WS_RUN_DIR:-.linkkin-run}"
  }

  # Returns lines: key|label|pid_var|expected (pid_var may be empty)
  ws_list_service_expectations() {
    local file
    file="$(ws_config_file)"
    [[ -f "$file" ]] || return 1
  # Parse services: section only
    awk '
      /^services:/ { in_svc=1; next }
      in_svc && /^[a-zA-Z]/ && $0 !~ /^  / { in_svc=0 }
      in_svc && /^  - key:/ {
        if (key != "") print key "|" label "|" pid_var "|" expected
        key = $3; gsub(/"/, "", key); label = key; pid_var = ""; expected = "running"
      }
      in_svc && /^    label:/ { label = $2; gsub(/"/, "", label) }
      in_svc && /^    pid_var:/ { pid_var = $2; gsub(/"/, "", pid_var) }
      in_svc && /^    expected:/ { expected = $2; gsub(/"/, "", expected) }
      END { if (key != "") print key "|" label "|" pid_var "|" expected }
    ' "$file"
  }
fi
