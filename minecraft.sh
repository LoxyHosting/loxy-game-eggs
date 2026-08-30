#!/bin/bash
set -Eeuo pipefail

cd /home/container

JAR="${SERVER_JARFILE:-server.jar}"
MC_VERSION="${MINECRAFT_VERSION:-latest}"

echo "=================================================="
echo "         Minecraft - Loxy Systems v2"
echo " Startup remoto: minecraft.sh"
echo "=================================================="

if [[ ! -s "${JAR}" ]]; then
    echo "[ERRO] ${JAR} nao foi encontrado ou esta vazio."
    echo "[ERRO] Execute Reinstall no Pterodactyl para restaurar o servidor."
    exit 127
fi

# Detecta a versao Java real do container.
JAVA_VERSION_RAW="$(java -version 2>&1 | head -n1 || true)"
JAVA_MAJOR="$(printf '%s\n' "${JAVA_VERSION_RAW}" | sed -nE 's/.*version "1\.([0-9]+).*/\1/p')"

if [[ -z "${JAVA_MAJOR}" ]]; then
    JAVA_MAJOR="$(printf '%s\n' "${JAVA_VERSION_RAW}" | sed -nE 's/.*version "([0-9]+).*/\1/p')"
fi

if [[ -z "${JAVA_MAJOR}" ]]; then
    echo "[ERRO] Nao foi possivel detectar a versao do Java."
    exit 127
fi

echo "[JAVA] ${JAVA_VERSION_RAW}"
echo "[JAVA] Major detectado: ${JAVA_MAJOR}"

# Recomenda a Java correta com base nas faixas atualmente documentadas pelo Paper.
RECOMMENDED_JAVA=""

case "${MC_VERSION}" in
    latest|"")
        RECOMMENDED_JAVA=""
        ;;
    26.*)
        RECOMMENDED_JAVA="25"
        ;;
    1.21.*|1.20.*)
        RECOMMENDED_JAVA="21"
        ;;
    1.19.*|1.18.*|1.17.*)
        RECOMMENDED_JAVA="17"
        ;;
    1.16.5)
        RECOMMENDED_JAVA="16"
        ;;
    1.16.*|1.15.*|1.14.*|1.13.*|1.12.*)
        RECOMMENDED_JAVA="11"
        ;;
    1.11.*|1.10.*|1.9.*|1.8.*|1.7.*)
        RECOMMENDED_JAVA="8"
        ;;
esac

if [[ -n "${RECOMMENDED_JAVA}" && "${JAVA_MAJOR}" != "${RECOMMENDED_JAVA}" ]]; then
    echo "--------------------------------------------------"
    echo "[AVISO] Java nao recomendada para Minecraft ${MC_VERSION}."
    echo "[AVISO] Atual: Java ${JAVA_MAJOR}"
    echo "[AVISO] Recomendada: Java ${RECOMMENDED_JAVA}"
    echo "[AVISO] Troque a Docker Image no Startup do Pterodactyl se houver erro."
    echo "--------------------------------------------------"
fi

# Calcula heap deixando memoria para JVM, threads, bibliotecas e o container.
MEMORY_MB="${SERVER_MEMORY:-0}"
XMS_MB=128

if [[ "${MEMORY_MB}" =~ ^[0-9]+$ ]] && (( MEMORY_MB > 0 )); then
    if (( MEMORY_MB <= 768 )); then
        RESERVE_MB=128
    elif (( MEMORY_MB <= 1536 )); then
        RESERVE_MB=256
    elif (( MEMORY_MB <= 4096 )); then
        RESERVE_MB=384
    elif (( MEMORY_MB <= 8192 )); then
        RESERVE_MB=512
    else
        RESERVE_MB=768
    fi

    XMX_MB=$(( MEMORY_MB - RESERVE_MB ))

    if (( XMX_MB < 256 )); then
        XMX_MB=256
    fi

    if (( XMS_MB > XMX_MB )); then
        XMS_MB="${XMX_MB}"
    fi

    MEMORY_FLAGS=("-Xms${XMS_MB}M" "-Xmx${XMX_MB}M")
    echo "[MEMORIA] Limite: ${MEMORY_MB} MB | Heap maximo: ${XMX_MB} MB | Reserva: ${RESERVE_MB} MB"
else
    # Fallback para ambientes sem SERVER_MEMORY.
    MEMORY_FLAGS=("-Xms128M" "-XX:MaxRAMPercentage=90.0")
    echo "[MEMORIA] SERVER_MEMORY indisponivel. Usando MaxRAMPercentage=90."
fi

COMMON_FLAGS=(
    "-Dfile.encoding=UTF-8"
    "-Dterminal.jline=false"
    "-Dterminal.ansi=true"
    "-XX:+UseG1GC"
    "-XX:+ParallelRefProcEnabled"
    "-XX:MaxGCPauseMillis=200"
    "-XX:+DisableExplicitGC"
    "-XX:+AlwaysPreTouch"
    "-XX:+PerfDisableSharedMem"
)

# Para JVMs antigas, usa ajustes G1 conservadores compatíveis com servidores legados.
LEGACY_FLAGS=()

if (( JAVA_MAJOR <= 16 )); then
    LEGACY_FLAGS=(
        "-XX:+UnlockExperimentalVMOptions"
        "-XX:G1ReservePercent=20"
        "-XX:InitiatingHeapOccupancyPercent=15"
    )
fi

echo "[OTIMIZACAO] Perfil automatico para Java ${JAVA_MAJOR}."
echo "[MINECRAFT] Iniciando ${JAR}..."

exec java \
    "${MEMORY_FLAGS[@]}" \
    "${COMMON_FLAGS[@]}" \
    "${LEGACY_FLAGS[@]}" \
    -jar "${JAR}" nogui
