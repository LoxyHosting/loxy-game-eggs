#!/usr/bin/env bash
set -Eeuo pipefail

SERVER_DIR="${SERVER_DIR:-/home/container}"
SERVER_BIN="${SERVER_BIN:-./samp-server.exe}"
SERVER_CFG="${SERVER_CFG:-./server.cfg}"
PLUGIN_DIR="${PLUGIN_DIR:-./plugins}"
SERVER_LOG="${SERVER_LOG:-./server_log.txt}"
WINEPREFIX="${WINEPREFIX:-${SERVER_DIR}/.wine}"
WINEARCH="${WINEARCH:-win32}"

SERVER_PORT="${SAMP_PORT:-${SERVER_PORT:-7777}}"
MAX_PLAYERS="${SAMP_MAX_PLAYERS:-${MAX_PLAYERS:-50}}"
SERVER_HOSTNAME="${SAMP_SERVER_HOSTNAME:-${SERVER_HOSTNAME:-Loxy Hosting SA-MP Server}}"
RCON_PASSWORD="${SAMP_RCON_PASSWORD:-${RCON_PASSWORD:-}}"
SERVER_PASSWORD="${SAMP_SERVER_PASSWORD:-${SERVER_PASSWORD:-}}"
ANNOUNCE="${SAMP_ANNOUNCE:-${ANNOUNCE:-1}}"
QUERY="${SAMP_QUERY:-${QUERY:-1}}"
LAN="${SAMP_LAN:-${LAN:-0}}"
RCON="${SAMP_RCON:-${RCON:-1}}"
SAMP_VOIP="${SAMP_VOIP:-0}"
VOIP_PORT="${SAMP_VOIP_PORT:-${VOIP_PORT:-0}}"
SAMPVOICE_URL="${SAMPVOICE_URL:-}"
# A Egg nao baixa sampvoice.dll automaticamente. O cliente pode instalar o DLL manualmente
# na pasta plugins/ e usar VOIP_PORT para configurar a porta conforme desejado.

SERVER_PID=""
TAIL_PID=""

log()  { printf '[SAMP-WINE] %s\n' "$*"; }
warn() { printf '[SAMP-WINE] [AVISO] %s\n' "$*" >&2; }
fail() { printf '[SAMP-WINE] [ERRO] %s\n' "$*" >&2; exit "${2:-1}"; }

cleanup() {
    local status=$?
    if [[ -n "${TAIL_PID}" ]] && kill -0 "${TAIL_PID}" 2>/dev/null; then
        kill "${TAIL_PID}" 2>/dev/null || true
        wait "${TAIL_PID}" 2>/dev/null || true
    fi
    if [[ -n "${SERVER_PID}" ]] && kill -0 "${SERVER_PID}" 2>/dev/null; then
        kill -TERM "${SERVER_PID}" 2>/dev/null || true
        sleep 2 || true
        kill -KILL "${SERVER_PID}" 2>/dev/null || true
        wait "${SERVER_PID}" 2>/dev/null || true
    fi
    if command -v wineserver >/dev/null 2>&1; then
        WINEPREFIX="${WINEPREFIX}" WINEARCH="${WINEARCH}" wineserver -k 2>/dev/null || true
    fi
    return "${status}"
}

handle_signal() {
    local signal="$1"
    log "Sinal ${signal} recebido; encerrando processo SA-MP..."
    if [[ -n "${SERVER_PID}" ]] && kill -0 "${SERVER_PID}" 2>/dev/null; then
        kill -s "${signal}" "${SERVER_PID}" 2>/dev/null || true
    fi
}

trap cleanup EXIT
trap 'handle_signal TERM' TERM
trap 'handle_signal INT' INT
trap 'printf "[SAMP-WINE] [ERRO] Falha no startup (linha %s, codigo %s).\\n" "$LINENO" "$?" >&2' ERR

cd "${SERVER_DIR}" || fail "Nao foi possivel acessar ${SERVER_DIR}."
mkdir -p "${PLUGIN_DIR}" "${SERVER_DIR}/.wine" || fail "Nao foi possivel preparar diretorios do servidor."
export WINEPREFIX HOME="${SERVER_DIR}"
WINE_BIN="$(command -v wine || command -v wine64 || true)"
[[ -n "${WINE_BIN}" ]] || fail "Wine nao foi encontrado na imagem Docker (wine/wine64)."

if ! command -v wineboot >/dev/null 2>&1; then
    fail "wineboot nao foi encontrado. A imagem precisa incluir as ferramentas completas do Wine."
fi

if ! "${WINE_BIN}" --version >/dev/null 2>&1; then
    fail "O Wine foi encontrado, mas nao conseguiu iniciar. Verifique as bibliotecas da imagem Docker."
fi

if [[ ! -f "${SERVER_BIN}" ]]; then
    fail "samp-server.exe nao encontrado em ${SERVER_DIR}. Execute Reinstall/Install para restaurar o servidor Windows."
fi

if [[ ! -f "${SERVER_CFG}" ]]; then
    fail "server.cfg nao encontrado em ${SERVER_DIR}. Crie ou instale a configuracao padrao antes do startup."
fi

if [[ ! -f "${WINEPREFIX}/system.reg" ]]; then
    if [[ -e "${WINEPREFIX}" ]] && [[ -n "$(find "${WINEPREFIX}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
        warn "O prefixo Wine existe, mas nao possui system.reg. Ele pode estar incompleto."
    fi
    log "Criando prefixo Wine novo (${WINEARCH}) em ${WINEPREFIX}..."
    WINEARCH="${WINEARCH}" WINEPREFIX="${WINEPREFIX}" wineboot --init >> "${WINE_RUNTIME_LOG:-${SERVER_DIR}/wine-runtime.log}" 2>&1 ||
        fail "Falha ao inicializar o prefixo Wine. Consulte wine-runtime.log."
elif [[ ! -d "${WINEPREFIX}/drive_c" ]]; then
    fail "Prefixo Wine inconsistente: system.reg existe, mas drive_c esta ausente. Faça backup antes de recriar o prefixo."
else
    log "Prefixo Wine existente detectado; mantendo sua arquitetura original."
fi

validate_port() {
    local value="$1"
    local port_num
    if [[ ! "${value}" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    port_num=$((10#${value}))
    if (( port_num >= 1 && port_num <= 65535 )); then
        return 0
    fi
    return 1
}

plugin_name_for_cfg() {
    local raw_name="$1"
    raw_name="${raw_name##*/}"
    raw_name="${raw_name//\\//}"
    raw_name="${raw_name##*\\}"
    case "${raw_name,,}" in
        *.dll) printf '%s' "${raw_name}" ;;
        *.so) printf '%s' "${raw_name%.so}.dll" ;;
        *) printf '%s.dll' "${raw_name}" ;;
    esac
}

resolve_cfg_plugins() {
    declare -a configured=()
    declare -a discovered=()
    declare -A seen=()
    local line item

    while IFS= read -r line || [[ -n "${line}" ]]; do
        line="${line%%#*}"
        if [[ "${line}" =~ ^[[:space:]]*plugins[[:space:]] ]]; then
            read -r -a fields <<< "${line}"
            for ((i = 1; i < ${#fields[@]}; i++)); do
                item="${fields[$i]}"
                [[ -n "${item}" ]] || continue
                item="${item%$'\r'}"
                if [[ "${item}" == *.dll ]]; then
                    if [[ -f "${PLUGIN_DIR}/${item}" ]]; then
                        if [[ -z "${seen[$item]+x}" ]]; then
                            configured+=("${item}")
                            seen["${item}"]=1
                        fi
                    else
                        warn "Plugin listado no server.cfg nao encontrado em ${PLUGIN_DIR}: ${item} (ignorado)."
                    fi
                elif [[ "${item}" == *.so ]]; then
                    warn "Arquivo .so encontrado no server.cfg; o SA-MP Windows nao carrega .so. Ignorando: ${item}"
                elif [[ -f "${PLUGIN_DIR}/${item}" ]]; then
                    if [[ -z "${seen[$item]+x}" ]]; then
                        configured+=("${item}")
                        seen["${item}"]=1
                    fi
                else
                    warn "Referencia de plugin nao reconhecida e nao encontrada em ${PLUGIN_DIR}: ${item} (ignorado)."
                fi
            done
        fi
    done < "${SERVER_CFG}"

    shopt -s nullglob nocaseglob
    for plugin_path in "${PLUGIN_DIR}"/*.dll; do
        item="${plugin_path##*/}"
        if [[ -z "${seen[$item]+x}" ]]; then
            discovered+=("${item}")
            seen["${item}"]=1
        fi
    done
    shopt -u nullglob nocaseglob

    if (( ${#configured[@]} + ${#discovered[@]} > 0 )); then
        printf '%s\n' "${configured[@]}" "${discovered[@]}" | awk 'NF'
    fi
}

case "${SAMP_VOIP,,}" in
    1|true|yes|on|enabled) VOIP_ENABLED=1 ;;
    0|false|no|off|disabled|'') VOIP_ENABLED=0 ;;
    *) fail "SAMP_VOIP invalido ('${SAMP_VOIP}'). Use 0 ou 1." ;;
esac

if (( VOIP_ENABLED == 1 )); then
    if ! validate_port "${VOIP_PORT}"; then
        if [[ "${VOIP_PORT}" == "0" ]]; then
            warn "SAMP_VOIP esta ativo, mas VOIP_PORT=0. O servidor iniciara sem configurar sv_port."
        else
            fail "VOIP_PORT invalida ('${VOIP_PORT}'). Use 0 ou um valor entre 1 e 65535."
        fi
    fi

    if [[ -f "${PLUGIN_DIR}/sampvoice.dll" ]]; then
        log "sampvoice.dll encontrado em ${PLUGIN_DIR}; o plugin de voz sera usado se o servidor o carregar."
    else
        warn "sampvoice.dll nao foi encontrado em ${PLUGIN_DIR}. A Egg apenas configurar a porta VOIP_PORT; o DLL deve ser instalado manualmente pelo cliente."
    fi
else
    log "SAMP_VOIP desativado; a Egg nao altera a configuracao do VOIP."
fi

# Reescreve apenas a linha de plugins, sem remover plugins clientes existentes.
plugin_entries=( $(resolve_cfg_plugins) )
PLUGIN_LINE=""
if (( ${#plugin_entries[@]} > 0 )); then
    PLUGIN_LINE="plugins ${plugin_entries[*]}"
fi

# Atualiza server.cfg mantendo outros valores antigos.
if [[ -n "${PLUGIN_LINE}" ]]; then
    tmp_cfg="$(mktemp "${SERVER_CFG}.tmp.XXXXXX")"
    found_plugins=0
    while IFS= read -r line || [[ -n "${line}" ]]; do
        if [[ "${line}" =~ ^[[:space:]]*plugins[[:space:]] ]]; then
            printf '%s\n' "${PLUGIN_LINE}"
            found_plugins=1
        else
            printf '%s\n' "${line}"
        fi
    done < "${SERVER_CFG}" > "${tmp_cfg}"
    if (( found_plugins == 0 )); then
        printf '%s\n' "${PLUGIN_LINE}" >> "${tmp_cfg}"
    fi
    mv -f -- "${tmp_cfg}" "${SERVER_CFG}"
    log "Linha de plugins preservada e atualizada em ${SERVER_CFG}."
else
    warn "Nenhum plugin .dll valido encontrado em ${PLUGIN_DIR}; o servidor sera iniciado sem plugins."
fi

# Garante linhas basicas, sem apagar configuracoes user-defined.
update_cfg_value() {
    local key="$1"
    local value="$2"
    local tmp_file
    local found=0
    local lower_line lower_key
    lower_key="${key,,}"
    tmp_file="$(mktemp "${SERVER_CFG}.kv.XXXXXX")"

    while IFS= read -r line || [[ -n "${line}" ]]; do
        lower_line="${line,,}"
        if [[ "${lower_line}" =~ ^[[:space:]]*${lower_key}[[:space:]] ]]; then
            if (( found == 0 )); then
                printf '%s %s\n' "${key}" "${value}"
                found=1
            else
                warn "Removendo entrada duplicada de '${key}' no server.cfg."
            fi
        else
            printf '%s\n' "${line}"
        fi
    done < "${SERVER_CFG}" > "${tmp_file}"

    if (( found == 0 )); then
        printf '%s %s\n' "${key}" "${value}" >> "${tmp_file}"
    fi
    mv -f -- "${tmp_file}" "${SERVER_CFG}"
}

update_cfg_value "port" "${SERVER_PORT}"
update_cfg_value "maxplayers" "${MAX_PLAYERS}"
update_cfg_value "hostname" "${SERVER_HOSTNAME}"
update_cfg_value "announce" "${ANNOUNCE}"
update_cfg_value "query" "${QUERY}"
update_cfg_value "lanmode" "${LAN}"
update_cfg_value "rcon" "${RCON}"
if [[ -n "${RCON_PASSWORD}" ]]; then
    update_cfg_value "rcon_password" "${RCON_PASSWORD}"
fi
if [[ -n "${SERVER_PASSWORD}" ]]; then
    update_cfg_value "password" "${SERVER_PASSWORD}"
fi

if (( VOIP_ENABLED == 1 )); then
    if [[ "${VOIP_PORT}" == "0" ]]; then
        warn "VOIP_PORT=0; nenhuma linha sv_port sera alterada."
    else
        update_cfg_value "sv_port" "${VOIP_PORT}"
    fi
else
    if grep -Eq '^[[:space:]]*sv_port[[:space:]]' "${SERVER_CFG}"; then
        warn "SAMP_VOIP=0; a linha sv_port sera preservada, mas o plugin de voz nao sera gerenciado automaticamente."
    fi
fi

# O SA-MP grava o log do jogo em SERVER_LOG. O stdout/stderr do Wine
# vai para outro arquivo para nao misturar duas fontes no mesmo log/console.
WINE_RUNTIME_LOG="${WINE_RUNTIME_LOG:-${SERVER_DIR}/wine-runtime.log}"
: > "${SERVER_LOG}"
touch "${WINE_RUNTIME_LOG}"
log "Wine version: $(" ${WINE_BIN}" --version 2>/dev/null || printf 'indisponivel')"

if ! command -v tail >/dev/null 2>&1; then
    fail "O comando tail (coreutils) e necessario para transmitir server_log.txt ao console."
fi

tail -n 0 -F --sleep-interval=1 -- "${SERVER_LOG}" &
TAIL_PID=$!

log "Iniciando SA-MP Windows via Wine..."
log "Prefixo Wine: ${WINEPREFIX}"
log "Log SA-MP (console): ${SERVER_LOG}"
log "Log interno Wine: ${WINE_RUNTIME_LOG}"

# Nao redirecionar a saida do Wine para SERVER_LOG: isso duplicaria as
# mensagens que o proprio samp-server.exe ja grava nesse arquivo.
WINEPREFIX="${WINEPREFIX}" "${WINE_BIN}" "${SERVER_BIN}" >> "${WINE_RUNTIME_LOG}" 2>&1 &
SERVER_PID=$!

set +e
wait "${SERVER_PID}"
SERVER_STATUS=$?
set -e

if (( SERVER_STATUS != 0 )); then
    warn "samp-server.exe encerrou com codigo ${SERVER_STATUS}."
else
    log "samp-server.exe encerrou normalmente."
fi

if command -v wineserver >/dev/null 2>&1; then
    WINEPREFIX="${WINEPREFIX}" WINEARCH="${WINEARCH}" wineserver -k 2>/dev/null || true
fi

if [[ -n "${TAIL_PID}" ]] && kill -0 "${TAIL_PID}" 2>/dev/null; then
    kill "${TAIL_PID}" 2>/dev/null || true
    wait "${TAIL_PID}" 2>/dev/null || true
fi

exit "${SERVER_STATUS}"
