#!/usr/bin/env bash
set -Eeuo pipefail

# SA-MP startup simplificado para Pterodactyl / Loxy Hosting.
# - Converte referencias .dll (ou sem extensao) para .so no server.cfg.
# - Carrega automaticamente todos os .so da pasta plugins/.
# - SAMP_VOIP=1 baixa sampvoice.so apenas se estiver ausente/vazio e aplica VOIP_PORT.
# - Nao sobrescreve plugins existentes e nao cria backups persistentes.
# - Exibe server_log.txt no console e preserva stderr sem duplicar o stdout.

SERVER_DIR="${SERVER_DIR:-/home/container}"
SERVER_BIN="./samp03svr"
SERVER_CFG="./server.cfg"
PLUGIN_DIR="./plugins"
SERVER_LOG="./server_log.txt"
VOICE_URL="${SAMPVOICE_URL:-https://raw.githubusercontent.com/LoxyHosting/loxy-game-eggs/main/sampvoice.so}"
SAMP_VOIP="${SAMP_VOIP:-1}"
VOIP_PORT="${VOIP_PORT:-0}"
CONFIG_TMP=""
VOICE_TMP=""
SERVER_PID=""
TAIL_PID=""

log()  { printf '[SA-MP] %s\n' "$*"; }
warn() { printf '[AVISO] %s\n' "$*" >&2; }
fail() { printf '[ERRO] %s\n' "$*" >&2; exit "${2:-1}"; }

cleanup() {
    local status=$?
    if [[ -n "${TAIL_PID}" ]] && kill -0 "${TAIL_PID}" 2>/dev/null; then
        kill "${TAIL_PID}" 2>/dev/null || true
        wait "${TAIL_PID}" 2>/dev/null || true
    fi
    [[ -z "${CONFIG_TMP}" || ! -f "${CONFIG_TMP}" ]] || rm -f -- "${CONFIG_TMP}"
    [[ -z "${VOICE_TMP}" || ! -f "${VOICE_TMP}" ]] || rm -f -- "${VOICE_TMP}"
    return "${status}"
}

forward_signal() {
    local signal="$1"
    log "Sinal ${signal} recebido; encaminhando ao processo SA-MP..."
    if [[ -n "${SERVER_PID}" ]] && kill -0 "${SERVER_PID}" 2>/dev/null; then
        kill -s "${signal}" "${SERVER_PID}" 2>/dev/null || true
    fi
}

trap cleanup EXIT
trap 'forward_signal TERM' TERM
trap 'forward_signal INT' INT
trap 'printf "[ERRO] Falha no startup (linha %s, codigo %s).\\n" "$LINENO" "$?" >&2' ERR

cd "${SERVER_DIR}" || fail "Nao foi possivel acessar ${SERVER_DIR}."
[[ -f "${SERVER_BIN}" ]] || fail "samp03svr nao encontrado. Execute Reinstall no Pterodactyl para restaurar os arquivos base." 127
[[ -f "${SERVER_CFG}" ]] || fail "server.cfg nao encontrado."
command -v awk >/dev/null 2>&1 || fail "awk nao esta disponivel na imagem Docker."

chmod u+x "${SERVER_BIN}" || fail "Nao foi possivel liberar a execucao de samp03svr."
mkdir -p "${PLUGIN_DIR}"

# Remove apenas marcadores vazios legados criados por startups antigos da Loxy.
for legacy_marker in .loxy-sampvoice-managed .loxy-svport-managed; do
    if [[ -f "${legacy_marker}" ]]; then
        rm -f -- "${legacy_marker}"
        log "Marcador legado removido: ${legacy_marker}"
    fi
done

# SAMP_VOIP controla o download automatico e a aplicacao de sv_port.
# Plugins .so que ja estejam em plugins/ continuam sujeitos a autodeteccao normal.
case "${SAMP_VOIP,,}" in
    1|true|yes|on|enabled) VOIP_ENABLED=1 ;;
    0|false|no|off|disabled|'') VOIP_ENABLED=0 ;;
    *) fail "SAMP_VOIP invalido ('${SAMP_VOIP}'). Use 0 ou 1." ;;
esac

SV_PORT_ENABLED=0
if (( VOIP_ENABLED == 1 )); then
    # O download e ativado por padrao. A porta e opcional para nao impedir
    # o primeiro boot antes de o cliente adicionar uma allocation UDP.
    if [[ "${VOIP_PORT}" =~ ^[0-9]{1,5}$ ]] && (( 10#${VOIP_PORT} >= 1 && 10#${VOIP_PORT} <= 65535 )); then
        SV_PORT_ENABLED=1
    elif [[ "${VOIP_PORT}" == "0" ]]; then
        warn "SAMP_VOIP esta ativo, mas VOIP_PORT=0. O plugin sera baixado/carregado; sv_port nao sera alterado ate configurar uma porta UDP."
    else
        fail "VOIP_PORT invalida ('${VOIP_PORT}'). Use 0 (sem configurar sv_port) ou uma porta entre 1 e 65535."
    fi

    if [[ ! -s "${PLUGIN_DIR}/sampvoice.so" ]]; then
        command -v curl >/dev/null 2>&1 || fail "SAMP_VOIP=1, mas curl nao esta instalado na imagem Docker."
        log "SAMP_VOIP ativado; baixando sampvoice.so..."
        VOICE_TMP="${PLUGIN_DIR}/.sampvoice.so.tmp.$$"
        rm -f -- "${VOICE_TMP}"
        if ! curl -fLsS --retry 3 --retry-delay 2 --connect-timeout 10 \
            -o "${VOICE_TMP}" "${VOICE_URL}"; then
            fail "Nao foi possivel baixar sampvoice.so de ${VOICE_URL}."
        fi
        [[ -s "${VOICE_TMP}" ]] || fail "O download do sampvoice.so retornou um arquivo vazio."
        chmod 755 "${VOICE_TMP}"
        mv -f -- "${VOICE_TMP}" "${PLUGIN_DIR}/sampvoice.so"
        VOICE_TMP=""
        log "sampvoice.so instalado em ${PLUGIN_DIR}."
    else
        log "SampVoice ja existe; mantendo o arquivo do cliente sem sobrescrever."
    fi
else
    log "SAMP_VOIP desativado; download automatico e ajuste de sv_port ignorados."
fi

# Converte os nomes referenciados no server.cfg para .so.
normalize_plugin_name() {
    local name="${1##*/}"
    name="${name##*\\}"
    case "${name,,}" in
        *.dll) name="${name:0:${#name}-4}.so" ;;
        *.so)  ;;
        *)     name="${name}.so" ;;
    esac
    printf '%s' "${name}"
}

declare -a configured_plugins=()
declare -a plugin_files=()
declare -a selected_plugins=()
declare -A selected_lookup=()

while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%%#*}"
    if [[ "${line}" =~ ^[[:space:]]*plugins([[:space:]]|$) ]]; then
        read -r -a fields <<< "${line}"
        for ((i = 1; i < ${#fields[@]}; i++)); do
            [[ -n "${fields[$i]}" ]] || continue
            configured_plugins+=("$(normalize_plugin_name "${fields[$i]}")")
        done
    fi
done < "${SERVER_CFG}"

add_plugin_if_present() {
    local plugin="$1"
    local source="$2"
    if [[ -f "${PLUGIN_DIR}/${plugin}" ]]; then
        if [[ -z "${selected_lookup[${plugin}]+x}" ]]; then
            selected_plugins+=("${plugin}")
            selected_lookup["${plugin}"]=1
        fi
    elif [[ "${source}" == "configured" ]]; then
        warn "Plugin listado no server.cfg, mas nao encontrado em ${PLUGIN_DIR}: ${plugin} (ignorado)."
    fi
}

# Mantem primeiro a ordem dos plugins que ja estavam no cfg.
for plugin in "${configured_plugins[@]}"; do
    add_plugin_if_present "${plugin}" "configured"
done

# Depois inclui todos os .so encontrados na pasta, sem variaveis individuais.
shopt -s nullglob nocaseglob
plugin_files=("${PLUGIN_DIR}"/*.so)
shopt -u nullglob nocaseglob
for plugin_path in "${plugin_files[@]}"; do
    plugin_name="${plugin_path##*/}"
    add_plugin_if_present "${plugin_name}" "discovered"
done

plugin_line=""
if (( ${#selected_plugins[@]} > 0 )); then
    plugin_line="plugins ${selected_plugins[*]}"
fi

# Um unico rewrite atomico: remove duplicatas de plugins, define output 1
# para gerar server_log.txt e define sv_port somente se VOIP_PORT for valido.
CONFIG_TMP="$(mktemp "${SERVER_CFG}.tmp.XXXXXX")" || fail "Nao foi possivel criar temporario para server.cfg."
awk \
    -v replacement="${plugin_line}" \
    -v voip_enabled="${SV_PORT_ENABLED}" \
    -v voip_port="${VOIP_PORT}" '
    /^[[:space:]]*plugins([[:space:]]|$)/ {
        if (!plugins_done) {
            if (replacement != "") print replacement
            plugins_done = 1
        }
        next
    }
    /^[[:space:]]*output([[:space:]]|$)/ {
        if (!output_done) print "output 1"
        output_done = 1
        next
    }
    /^[[:space:]]*sv_port([[:space:]]|$)/ {
        if (voip_enabled == "1") {
            if (!sv_port_done) print "sv_port " voip_port
            sv_port_done = 1
            next
        }
        print
        next
    }
    { print }
    END {
        if (!plugins_done && replacement != "") print replacement
        if (!output_done) print "output 1"
        if (voip_enabled == "1" && !sv_port_done) print "sv_port " voip_port
    }
' "${SERVER_CFG}" > "${CONFIG_TMP}" || fail "Nao foi possivel atualizar server.cfg."

if ! cmp -s "${SERVER_CFG}" "${CONFIG_TMP}"; then
    chmod --reference="${SERVER_CFG}" "${CONFIG_TMP}" 2>/dev/null || true
    mv -f -- "${CONFIG_TMP}" "${SERVER_CFG}" || fail "Nao foi possivel substituir server.cfg."
    CONFIG_TMP=""
    log "server.cfg atualizado sem gerar backup."
else
    rm -f -- "${CONFIG_TMP}"
    CONFIG_TMP=""
    log "server.cfg ja estava atualizado."
fi

# Permissoes simples: nao altera arquivos fora da pasta plugins/.
find "${PLUGIN_DIR}" -maxdepth 1 -type f -name '*.so' -exec chmod 755 {} + 2>/dev/null || true

if (( ${#selected_plugins[@]} > 0 )); then
    log "Plugins detectados (${#selected_plugins[@]}):"
    for plugin in "${selected_plugins[@]}"; do printf '  - %s\n' "${plugin}"; done
else
    warn "Nenhum arquivo .so encontrado em ${PLUGIN_DIR}; o servidor iniciara sem plugins."
fi

# O SA-MP grava o log de console em server_log.txt quando output 1 esta ativo.
# O arquivo e a unica fonte de logs normais para evitar duplicar o stdout do binario.
: >> "${SERVER_LOG}"
if command -v tail >/dev/null 2>&1; then
    tail -n 0 -F --sleep-interval=0.1 -- "${SERVER_LOG}" &
    TAIL_PID=$!
else
    warn "tail nao esta disponivel; stdout/stderr do samp03svr sera exibido diretamente no console."
fi

if [[ -n "${TAIL_PID}" ]]; then
    log "Iniciando SA-MP; server_log.txt sera exibido no console sem linhas duplicadas..."
    "${SERVER_BIN}" >/dev/null &
else
    log "Iniciando SA-MP; stdout/stderr serao exibidos diretamente no console..."
    "${SERVER_BIN}" &
fi
SERVER_PID=$!

SERVER_STATUS=0
set +e
while true; do
    wait "${SERVER_PID}"
    SERVER_STATUS=$?
    if ! kill -0 "${SERVER_PID}" 2>/dev/null; then break; fi
done
set -e

if (( SERVER_STATUS == 139 )); then
    warn "SA-MP encerrou com codigo 139 (possivel Segmentation Fault)."
elif (( SERVER_STATUS != 0 )); then
    warn "SA-MP encerrou com codigo ${SERVER_STATUS}."
else
    log "Processo SA-MP encerrado normalmente."
fi

sleep 0.2 2>/dev/null || true
exit "${SERVER_STATUS}"
