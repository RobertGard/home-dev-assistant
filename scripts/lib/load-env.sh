#!/usr/bin/env bash

load_env_file() {
  local env_file="$1"
  local line
  local key
  local value
  local bs_placeholder=$'\001'
  local dq_placeholder=$'\002'
  local dl_placeholder=$'\003'
  local bt_placeholder=$'\004'
  local esc_bs='\\'
  local esc_dq='\"'
  local esc_dl='\$'
  local esc_bt='\`'
  local bt_char=$'\140'

  if [ ! -f "$env_file" ]; then
    printf '.env не найден: %s\n' "$env_file" >&2
    return 1
  fi

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|'#'*) continue ;;
    esac

    if [[ "$line" != *=* ]]; then
      printf '.env содержит невалидную строку: %s\n' "$line" >&2
      return 1
    fi

    key="${line%%=*}"
    value="${line#*=}"

    if [[ ! "$key" =~ ^[A-Z0-9_]+$ ]]; then
      printf '.env содержит невалидное имя переменной: %s\n' "$key" >&2
      return 1
    fi

    if [[ "$value" =~ ^\'.*\'$ ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "$value" =~ ^\".*\"$ ]]; then
      value="${value:1:${#value}-2}"
      value="${value//$esc_dq/$dq_placeholder}"
      value="${value//$esc_dl/$dl_placeholder}"
      value="${value//$esc_bt/$bt_placeholder}"
      value="${value//$esc_bs/$bs_placeholder}"
      value="${value//$dq_placeholder/\"}"
      value="${value//$dl_placeholder/$}"
      value="${value//$bt_placeholder/$bt_char}"
      value="${value//$bs_placeholder/\\}"
    fi

    printf -v "$key" '%s' "$value"
    export "$key"
  done <"$env_file"
}
