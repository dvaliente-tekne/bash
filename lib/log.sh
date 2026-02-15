#!/usr/bin/env bash
# shellcheck shell=bash
LOG_LEVEL="${LOG_LEVEL:-INFO}"

_ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
_log() { local level="$1"; shift; printf "%s [%s] %s\n" "$(_ts)" "$level" "$*" >&2; }
log_debug(){ [[ "$LOG_LEVEL" == "DEBUG" ]] && _log "DEBUG" "$@"; }
log_info(){  _log "INFO"  "$@"; }
log_warn(){  _log "WARN"  "$@"; }
log_error(){ _log "ERROR" "$@"; }
die(){ log_error "$@"; exit 1; }
on_exit(){ local ec="$1"; (( ec==0 )) || log_error "Exited with code $ec"; }
