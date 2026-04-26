#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_ROOT="${OPENCODE_WORKSPACE_ROOT:-/workspace}"
CATALOG_FILE="${OPENCODE_REPO_CATALOG_FILE:-}"

if [ -z "${CATALOG_FILE}" ] || [ ! -f "${CATALOG_FILE}" ]; then
  printf 'info: repo catalog not found at %s; skipping repo bootstrap\n' "${CATALOG_FILE:-<unset>}"
  exit 0
fi

auth_repo_url() {
  local repo_url="$1"
  if [ -n "${GITHUB_TOKEN:-}" ] && [[ "${repo_url}" == https://github.com/* ]]; then
    printf 'https://x-access-token:%s@%s' "${GITHUB_TOKEN}" "${repo_url#https://}"
    return
  fi

  printf '%s' "${repo_url}"
}

repo_items() {
  jq -c 'if type == "array" then . else .repos // [] end | map(select((.enabled // true) == true))[]' "${CATALOG_FILE}"
}

compose_file_for_repo() {
  local repo_dir="$1"
  local declared_file="$2"

  if [ -n "${declared_file}" ] && [ -f "${repo_dir}/${declared_file}" ]; then
    printf '%s\n' "${repo_dir}/${declared_file}"
    return
  fi

  if [ -f "${repo_dir}/compose.yaml" ]; then
    printf '%s\n' "${repo_dir}/compose.yaml"
    return
  fi

  if [ -f "${repo_dir}/docker-compose.yml" ]; then
    printf '%s\n' "${repo_dir}/docker-compose.yml"
    return
  fi
}

install_repo_dependencies() {
  local repo_dir="$1"
  local package_manager="$2"

  case "${package_manager}" in
    pnpm)
      pnpm install --dir "${repo_dir}"
      ;;
    bun)
      bun install --cwd "${repo_dir}"
      ;;
    npm-ci)
      npm ci --prefix "${repo_dir}"
      ;;
    npm)
      npm install --prefix "${repo_dir}"
      ;;
    auto)
      if [ -f "${repo_dir}/pnpm-lock.yaml" ]; then
        pnpm install --dir "${repo_dir}"
      elif [ -f "${repo_dir}/bun.lockb" ] || [ -f "${repo_dir}/bun.lock" ]; then
        bun install --cwd "${repo_dir}"
      elif [ -f "${repo_dir}/package-lock.json" ]; then
        npm ci --prefix "${repo_dir}"
      elif [ -f "${repo_dir}/package.json" ]; then
        npm install --prefix "${repo_dir}"
      fi
      ;;
  esac
}

run_turbo_smoke() {
  local repo_dir="$1"
  local tasks_csv="$2"

  if [ ! -f "${repo_dir}/turbo.json" ]; then
    return
  fi

  local tasks=()
  IFS=',' read -r -a tasks <<< "${tasks_csv}"
  if [ "${#tasks[@]}" -eq 0 ]; then
    return
  fi

  turbo run "${tasks[@]}" --continue --cache-dir .turbo --cwd "${repo_dir}" || true
}

while IFS= read -r repo; do
  slug="$(printf '%s' "${repo}" | jq -r '.slug')"
  repo_url="$(printf '%s' "${repo}" | jq -r '.url')"
  repo_ref="$(printf '%s' "${repo}" | jq -r '.ref // "main"')"
  repo_path="$(printf '%s' "${repo}" | jq -r '.path // .slug')"
  package_manager="$(printf '%s' "${repo}" | jq -r '.package_manager // "auto"')"
  install_deps="$(printf '%s' "${repo}" | jq -r '.install_dependencies // true')"
  turbo_smoke="$(printf '%s' "${repo}" | jq -r '.turbo_smoke // false')"
  turbo_tasks="$(printf '%s' "${repo}" | jq -r '(.turbo_tasks // ["build","test"]) | join(",")')"
  gsd_local="$(printf '%s' "${repo}" | jq -r '.install_gsd_local // false')"
  post_bootstrap="$(printf '%s' "${repo}" | jq -r '.post_bootstrap // empty')"
  auto_start_docker="$(printf '%s' "${repo}" | jq -r '.auto_start_docker // false')"
  docker_file="$(printf '%s' "${repo}" | jq -r '.docker_file // empty')"
  repo_dir="${WORKSPACE_ROOT}/${repo_path}"

  mkdir -p "$(dirname "${repo_dir}")"

  if [ ! -d "${repo_dir}/.git" ]; then
    git clone "$(auth_repo_url "${repo_url}")" "${repo_dir}"
  fi

  git -C "${repo_dir}" remote set-url origin "$(auth_repo_url "${repo_url}")"
  git -C "${repo_dir}" fetch --all --prune || true
  git -C "${repo_dir}" checkout "${repo_ref}" || true
  git -C "${repo_dir}" pull --ff-only origin "${repo_ref}" || true

  if [ "${install_deps}" = "true" ]; then
    install_repo_dependencies "${repo_dir}" "${package_manager}"
  fi

  if [ "${turbo_smoke}" = "true" ]; then
    run_turbo_smoke "${repo_dir}" "${turbo_tasks}"
  fi

  if [ "${gsd_local}" = "true" ]; then
    (cd "${repo_dir}" && npx -y get-shit-done-cc@latest --opencode --local) || true
  fi

  if [ -n "${post_bootstrap}" ]; then
    (cd "${repo_dir}" && bash -lc "${post_bootstrap}") || true
  fi

  if [ "${auto_start_docker}" = "true" ]; then
    compose_file="$(compose_file_for_repo "${repo_dir}" "${docker_file}")"
    if [ -n "${compose_file}" ]; then
      docker compose -f "${compose_file}" up -d || true
    fi
  fi

  printf 'bootstrapped repo %s at %s\n' "${slug}" "${repo_dir}"
done < <(repo_items)
