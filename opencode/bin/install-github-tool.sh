#!/usr/bin/env bash
set -euo pipefail

# Generic binary installer — GitHub releases, GitLab, direct URLs
# Resolves asset names via GitHub API (handles versioned filenames)
#
# Usage:
#   install-github-tool.sh 'hadolint/hadolint|hadolint|hadolint-Linux-x86_64'
#   install-github-tool.sh 'dandavison/delta|delta|git-delta_.*_amd64\.deb'
#   install-github-tool.sh 'direct|mytool|mytool|https://cdn.example.com/mytool'
#
# Format: <repo>|<binary>|<asset-pattern>
#   repo:               owner/repo (GitHub default)
#   repo prefix:         github:owner/repo, gitlab:owner/repo, direct:URL

install_one() {
  local spec="$1"
  local repo bin pattern url

  IFS='|' read -r repo bin pattern <<< "${spec}"
  local dest="/usr/local/bin/${bin}"

  # --- resolve source and download URL ---
  if [[ "${repo}" == gitlab:* ]]; then
    repo="${repo#gitlab:}"
    url="https://gitlab.com/${repo}/-/releases/permalink/latest/downloads/${pattern}"
  elif [[ "${repo}" == direct:* ]]; then
    url="${repo#direct:}"
  else
    # default: GitHub — resolve via API to handle versioned asset names
    repo="${repo#github:}"  # strip optional github: prefix
    printf '→ resolving %s from %s (pattern: %s)\n' "${bin}" "${repo}" "${pattern}"

    local api_url="https://api.github.com/repos/${repo}/releases/latest"
    local download_url
    download_url="$(curl -fsS "${api_url}" 2>/dev/null | jq -r --arg pattern "${pattern}" '.assets[] | select(.name | test($pattern)) | .browser_download_url' | head -1)"

    if [ -z "${download_url}" ] || [ "${download_url}" = "null" ]; then
      printf '  ⚠️  asset matching "%s" not found in latest release of %s\n' "${pattern}" "${repo}" >&2
      return 1
    fi
    url="${download_url}"
  fi

  printf '  → %s\n' "${url}"

  # --- install by file type ---
  case "${url}" in
    *.tar.gz|*.tgz|*.tar.bz2|*.tar.xz|*.tar)
      local tmp_dir
      tmp_dir="$(mktemp -d)"
      curl -fsSL "${url}" | tar x -C "${tmp_dir}" 2>/dev/null
      local found
      found="$(find "${tmp_dir}" -type f -name "${bin}" | head -1)"
      [ -n "${found}" ] && install -m 0755 "${found}" "${dest}"
      rm -rf "${tmp_dir}"
      [ -f "${dest}" ] || { printf '  ⚠️  binary "%s" not found in archive\n' "${bin}" >&2; return 1; }
      ;;
    *.deb)
      local tmp_deb
      tmp_deb="$(mktemp)"
      curl -fsSLo "${tmp_deb}" "${url}"
      dpkg -i "${tmp_deb}" 2>/dev/null || apt-get install -fy >/dev/null 2>&1
      rm -f "${tmp_deb}"
      ;;
    *)
      curl -fsSLo "${dest}" "${url}"
      chmod +x "${dest}"
      ;;
  esac

  printf '  ✅ %s installed\n' "${bin}"
}

for spec in "$@"; do
  install_one "${spec}" || printf '  ❌ failed to install: %s\n' "${spec}" >&2
done
