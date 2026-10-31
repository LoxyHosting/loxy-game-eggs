#!/bin/bash
set -Eeuo pipefail

cd /home/container

RUNTIME_IMAGE="ghcr.io/ptero-eggs/games:samp"
SAMPVOICE_VERSION="${SAMPVOICE_VERSION:-1.0.0}"
SAMPVOICE_SHA256="${SAMPVOICE_SHA256:-ff21093fb5a1d981a7168dee87ef9e2978d186348b725d2dbb09b2adc46c964f}"
VOICE_URL="https://raw.githubusercontent.com/LoxyHosting/loxy-game-eggs/main/sampvoice.so"
SAMP_VOIP="${SAMP_VOIP:-0}"
VOIP_PORT="${VOIP_PORT:-0}"
SAMP_DIAGNOSTIC="${SAMP_DIAGNOSTIC:-0}"
SAMP_PLUGIN_SSCANF="${SAMP_PLUGIN_SSCANF:-1}"
SAMP_PLUGIN_STREAMER="${SAMP_PLUGIN_STREAMER:-1}"
SAMP_PLUGIN_PAWNRAKNET="${SAMP_PLUGIN_PAWNRAKNET:-1}"
SAMP_PLUGIN_SAMPVOICE="${SAMP_PLUGIN_SAMPVOICE:-${SAMP_VOIP}}"
CONFIG_BACKUP=""
PLUGINS_TMP=""

warn() { echo "[WARN] $1"; }
fail() { echo "[ERROR] $1"; exit "${2:-1}"; }
plugin_enabled() {
  local value="${1:-1}"
  case "${value,,}" in
    1|true|yes|on|enabled) return 0 ;;
    0|false|no|off|disabled) return 1 ;;
    *) return 0 ;;
  esac
}
restore_server_cfg() {
  if [[ -n "${CONFIG_BACKUP}" && -f "${CONFIG_BACKUP}" ]]; then
    cp -f "${CONFIG_BACKUP}" ./server.cfg
    rm -f "${CONFIG_BACKUP}"
  fi
  if [[ -n "${PLUGINS_TMP}" && -f "${PLUGINS_TMP}" ]]; then
    rm -f "${PLUGINS_TMP}"
  fi
}
trap 'status=$?; if [[ ${status} -ne 0 ]]; then echo "[ERROR] O processo SA-MP encerrou inesperadamente."; echo "[ERROR] Exit Code: ${status}"; if [[ ${status} -eq 139 ]]; then echo "[ERROR] Tipo: Segmentation Fault"; fi; fi; restore_server_cfg; if compgen -G "./core*" > /dev/null; then mkdir -p ./debug 2>/dev/null || true; cp -f ./core* ./debug/ 2>/dev/null || true; fi; exit ${status}' EXIT
ulimit -c unlimited 2>/dev/null || true
mkdir -p ./plugins ./debug

printf '\n'
echo "=================================================="
echo "          SA-MP Connect - Loxy v3.0"
echo " Runtime: ${RUNTIME_IMAGE}"
echo "=================================================="

if [[ ! -f "./samp03svr" ]]; then fail "samp03svr nao encontrado. Execute Reinstall no Pterodactyl para restaurar os arquivos base." 127; fi
if [[ ! -f "./server.cfg" ]]; then fail "server.cfg nao encontrado no diretorio do servidor." 1; fi
chmod 755 ./samp03svr
[[ -f "./samp-npc" ]] && chmod 755 ./samp-npc
[[ -f "./announce" ]] && chmod 755 ./announce
find ./plugins -maxdepth 1 -type f -name "*.so" -exec chmod 755 {} \; 2>/dev/null || true
if [[ -f ./server.cfg ]]; then CONFIG_BACKUP="./server.cfg.bak.$(date +%s)"; cp -a ./server.cfg "${CONFIG_BACKUP}"; fi

detect_elf_class() {
  local file_path="${1:-}"
  if [[ -z "${file_path}" || ! -f "${file_path}" ]]; then echo "missing"; return 0; fi
  if command -v readelf >/dev/null 2>&1; then readelf -h "${file_path}" 2>/dev/null | awk '/Class:/{print $2; exit}' || true
  elif command -v objdump >/dev/null 2>&1; then objdump -f "${file_path}" 2>/dev/null | awk '/architecture:/{print $NF; exit}' || true
  elif command -v file >/dev/null 2>&1; then file "${file_path}" 2>/dev/null | awk '{print $3, $4}' | grep -E '32|64' | head -n1 || true
  else echo "unknown"; fi
}

validate_voice_asset() {
  local asset_path="${1:-}"
  if [[ ! -f "${asset_path}" ]]; then return 1; fi

  local expected_hash="${SAMPVOICE_SHA256,,}"

  if command -v sha256sum >/dev/null 2>&1; then
    local actual_hash
    actual_hash="$(sha256sum "${asset_path}" | awk '{print $1}')"
    actual_hash="${actual_hash,,}"
    if [[ "${actual_hash}" != "${expected_hash}" ]]; then
      echo "[ERROR] Hash do SampVoice invalido: ${actual_hash} (esperado ${expected_hash})." >&2
      return 2
    fi
  fi

  if command -v readelf >/dev/null 2>&1; then
    local asset_class="$(detect_elf_class "${asset_path}")"
    local server_class="$(detect_elf_class ./samp03svr)"
    if [[ -n "${asset_class}" && "${asset_class}" != "missing" && "${asset_class}" != "${server_class}" ]]; then
      echo "[ERROR] Arquitetura do SampVoice incompatível com a do executavel (${asset_class} != ${server_class})." >&2
      return 3
    fi
  fi
  return 0
}

ensure_voice() {
  local voice_path="./plugins/sampvoice.so"
  if plugin_enabled "${SAMP_PLUGIN_SAMPVOICE}"; then
    if [[ "${SAMP_VOIP:-0}" == "1" ]]; then
      if [[ ! -s "${voice_path}" ]]; then
        echo "[VOICE] sampvoice.so ausente. Baixando versao fixada ${SAMPVOICE_VERSION}..."
        rm -f "${voice_path}.tmp"
        curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 5 -o "${voice_path}.tmp" "${VOICE_URL}"
        if [[ ! -s "${voice_path}.tmp" ]]; then rm -f "${voice_path}.tmp"; fail "Falha ao baixar o SampVoice. O servidor nao pode iniciar com voice habilitado." 1; fi
        if ! validate_voice_asset "${voice_path}.tmp"; then rm -f "${voice_path}.tmp"; fail "Download do SampVoice invalido ou incompatível com a arquitetura do servidor." 1; fi
        mv -f "${voice_path}.tmp" "${voice_path}"
        chmod 755 "${voice_path}"
      elif ! validate_voice_asset "${voice_path}"; then
        echo "[VOICE] sampvoice.so inválido ou incompatível. Rebaixando versao fixada ${SAMPVOICE_VERSION}..."
        rm -f "${voice_path}"
        curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 5 -o "${voice_path}.tmp" "${VOICE_URL}"
        if [[ ! -s "${voice_path}.tmp" ]]; then rm -f "${voice_path}.tmp"; fail "Falha ao rebaixar o SampVoice. O servidor nao pode iniciar com voice habilitado." 1; fi
        if ! validate_voice_asset "${voice_path}.tmp"; then rm -f "${voice_path}.tmp"; fail "Download do SampVoice invalido ou incompatível com a arquitetura do servidor." 1; fi
        mv -f "${voice_path}.tmp" "${voice_path}"
        chmod 755 "${voice_path}"
      fi
      echo "[VOICE] Porta configurada: ${VOIP_PORT}"
    else
      if [[ -f "${voice_path}" ]]; then echo "[VOICE] SampVoice desabilitado no startup; nao sera carregado pelo server.cfg."; fi
    fi
  else
    echo "[VOICE] SampVoice desabilitado por configuracao do cliente."
  fi
}

rewrite_plugins_cfg() {
  local config="./server.cfg"
  local -a desired=()
  local -a keep=()
  for plugin in sscanf streamer pawnraknet sampvoice; do
    local enabled_var="SAMP_PLUGIN_$(printf '%s' "${plugin}" | tr '[:lower:]' '[:upper:]')"
    local enabled_value="${!enabled_var:-1}"
    local plugin_path="./plugins/${plugin}.so"
    if plugin_enabled "${enabled_value}" && [[ -f "${plugin_path}" ]]; then desired+=("${plugin}.so"); fi
  done
  if grep -Eq '^[[:space:]]*plugins([[:space:]]|$)' "${config}"; then
    while IFS= read -r line; do
      if [[ "${line}" =~ ^[[:space:]]*plugins([[:space:]]|$) ]]; then
        for item in ${line}; do
          if [[ "${item}" == "plugins" ]]; then continue; fi
          local lower="${item,,}"
          lower="${lower%.so}"
          case "${lower}" in sscanf|streamer|pawnraknet|sampvoice) continue ;; *) keep+=("${item}") ;; esac
        done
        break
      fi
    done < "${config}"
    for item in "${desired[@]}"; do keep+=("${item}"); done
    PLUGINS_TMP="./server.cfg.plugins.tmp"
    awk -v new="${keep[*]}" 'BEGIN { OFS=" " } /^[[:space:]]*plugins([[:space:]]|$)/ { if (new != "") { print "plugins " new }; next } { print }' "${config}" > "${PLUGINS_TMP}"
    mv -f "${PLUGINS_TMP}" "${config}"
    PLUGINS_TMP=""
  elif (( ${#desired[@]} > 0 )); then
    echo "plugins ${desired[*]}" >> "${config}"
  fi
}

if [[ "${SAMP_VOIP:-0}" == "1" ]]; then
  if [[ "${VOIP_PORT:-0}" =~ ^[0-9]+$ ]] && (( VOIP_PORT >= 1 && VOIP_PORT <= 65535 )); then
    if grep -Eq '^[[:space:]]*sv_port[[:space:]]+' ./server.cfg; then
      sed -i -E "s/^[[:space:]]*sv_port[[:space:]]+.*/sv_port ${VOIP_PORT}/" ./server.cfg
    else
      echo "sv_port ${VOIP_PORT}" >> ./server.cfg
    fi
  else
    warn "SAMP_VOIP=1, mas VOIP_PORT nao e uma porta valida. Voice sera desligado."
    SAMP_VOIP=0
  fi
else
  sed -i -E '/^[[:space:]]*sv_port[[:space:]]+/d' ./server.cfg 2>/dev/null || true
fi

ensure_voice
rewrite_plugins_cfg

echo "[START] Iniciando servidor..."
exec ./samp03svr
