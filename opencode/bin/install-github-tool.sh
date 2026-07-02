#!/usr/bin/env bash
set -euo pipefail

# Generic binary installer — works with GitHub, GitLab, direct URLs
#
# Usage:
#   install-github-tool.sh 'github:hadolint/hadolint|hadolint|hadolint-Linux-x86_64'
#   install-github-tool.sh 'direct|delta|git-delta_amd64|https://github.com/dandavison/delta/releases/latest/download/git-delta_amd64.deb'
#   install-github-tool.sh 'gitlab:owner/repo|tool|tool-linux-amd64.tar.gz'
#
# Format: <source>:<repo>|<binary-name>|<asset-pattern>|<custom-url>
#   source: github (default), gitlab, direct
#   custom-url: overrides auto-generated URL

install_one() {
  local spec="$1"
  local source repo bin pattern direct_url url

  IFS='|' read -r source repo bin pattern direct_url <<< "${spec}"
  local dest="/usr/local/bin/${bin}"

  # --- resolve download URL ---
  if [ -n "${direct_url}" ]; then
    url="${direct_url}"
  elif [[ "${source}" == gitlab:* ]]; then
    repo="${source#gitlab:}"
    url="https://gitlab.com/${repo}/-/releases/permalink/latest/downloads/${pattern}"
  elif [[ "${source}" == direct:* ]]; then
    repo="${source#direct:}"
    url="${repo}"
  else
    # default: github
    repo="${source#github:}"
    [ "${repo}" = "${source}" ] && repo="${source}"  # bare 'owner/repo' without prefix
    url="https://github.com/${repo}/releases/latest/download/${pattern}"
  fi

  printf '→ %s ← %s\n' "${bin}" "${url}"

  # --- install by file type ---
  case "${pattern}" in
    *.tar.gz|*.tgz)
      local tmp_dir
      tmp_dir="$(mktemp -d)"
      curl -fsSL "${url}" | tar xz -C "${tmp_dir}" "${bin}"
      install -m 0755 "${tmp_dir}/${bin}" "${dest}"
      rm -rf "${tmp_dir}"
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
}

for spec in "$@"; do
  install_one "${spec}"
done
