#!/usr/bin/env bats

load "../lib/log.sh"
load "../lib/os.sh"
load "../lib/github.sh"

setup() {
    export LOG_FILE="/dev/null"
    export CURRENT_VERSION="v0.0.0"
    export REPO_OWNER="DanHUMassMed"
    export REPO_NAME="jupyter_launcher"
    export REPO_PATH="${REPO_OWNER}/${REPO_NAME}"
    export GITHUB_API_URL="https://api.github.com/repos/${REPO_PATH}"
}

@test "require_curl returns 0 when curl is present" {
    if ! command -v curl; then
        skip "curl not installed"
    fi
    run require_curl
    [ "$status" -eq 0 ]
}

@test "github functions are loaded" {
    run type get_latest_github_tag
    [ "$status" -eq 0 ]
}
