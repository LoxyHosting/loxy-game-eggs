# SA-MP Ubuntu 24.04 Image

Este diretório contém uma imagem Docker para hospedagem profissional de servidores SA-MP e plugins compatíveis no Ubuntu 24.04 LTS, com suporte a arquiteturas 32-bit e 64-bit e preparação para Pterodactyl/Wings.

## Objetivo

- Base Ubuntu 24.04 LTS
- Suporte multiarch `i386` e `amd64`
- Compatibilidade com plugins SA-MP antigos e modernos
- Bibliotecas de runtime para executáveis ELF 32 e 64 bits
- Execução em ambiente Pterodactyl com usuário não-root

## Estrutura

```text
docker-images/samp-ubuntu24/
├── Dockerfile
├── README.md
├── .dockerignore
├── build.sh
├── test.sh
├── scripts/
│   ├── install-dependencies.sh
│   ├── compatibility-check.sh
│   └── entrypoint.sh
└── tests/
    ├── test-architecture.sh
    ├── test-libraries.sh
    └── test-pterodactyl.sh
```

## Bibliotecas instaladas

### Bibliotecas principais

- `libc6` / `libc6:i386`
- `libstdc++6` / `libstdc++6:i386`
- `libgcc-s1` / `libgcc-s1:i386`
- `zlib1g` / `zlib1g:i386`
- `libatomic1` / `libatomic1:i386`
- `libcurl4` / `libcurl4:i386`
- `libssl3` / `libssl3:i386`
- `libnghttp2-14` / `libnghttp2-14:i386`
- `libidn2-0` / `libidn2-0:i386`
- `libpsl5` / `libpsl5:i386`
- `libssh2-1` / `libssh2-1:i386`
- `librtmp1` / `librtmp1:i386`

### Bibliotecas de banco de dados

- `libmariadb3` / `libmariadb3:i386`
- `libmysqlclient21` / `libmysqlclient21:i386`
- `libsqlite3-0` / `libsqlite3-0:i386`

### Bibliotecas adicionais

- `libgomp1` / `libgomp1:i386`
- `libexpat1` / `libexpat1:i386`
- `libtinfo6` / `libtinfo6:i386`
- `libncurses6` / `libncurses6:i386`
- `libncurses5:i386`
- `libuuid1` / `libuuid1:i386`
- `lib32stdc++6`
- `ca-certificates`
- `tzdata`
- `locales`

## Bibliotecas legadas indisponíveis ou não instaladas

Ubuntu 24.04 não oferece suporte oficial para todas as versões legadas frequentemente exigidas por plugins antigos do SA-MP. As bibliotecas abaixo são conhecidas como incompatíveis ou indisponíveis na base oficial e não devem ser forçadas para o sistema:

- `libssl1.1:i386` — indisponível em Ubuntu 24.04 na base do sistema
- `libgcc1:i386` — substituída por `libgcc-s1` em releases modernas do Ubuntu
- `libmysqlclient18:i386` — removida do repositório oficial em Ubuntu 24.04

Quando uma dependência antiga não está disponível, a abordagem segura é isolar o binário/plugin em um diretório específico e apontar as bibliotecas locais sem sobrescrever as bibliotecas do sistema.

## Como construir

```bash
cd docker-images/samp-ubuntu24
chmod +x build.sh scripts/*.sh tests/*.sh
./build.sh
```

Para uma tag específica:

```bash
IMAGE_NAME=loxyhosting/samp-ubuntu24 TAG_REF=ubuntu24 ./build.sh
```

## Como testar

```bash
IMAGE_NAME=loxyhosting/samp-ubuntu24 TAG_REF=ubuntu24 ./test.sh
```

Também é possível executar os testes específicos:

```bash
./tests/test-architecture.sh
./tests/test-libraries.sh
./tests/test-pterodactyl.sh
```

## Publicação

```bash
docker login

docker tag loxyhosting/samp-ubuntu24:latest loxyhosting/samp-ubuntu24:ubuntu24
docker tag loxyhosting/samp-ubuntu24:latest loxyhosting/samp-ubuntu24:stable
docker push loxyhosting/samp-ubuntu24:latest
docker push loxyhosting/samp-ubuntu24:ubuntu24
docker push loxyhosting/samp-ubuntu24:stable
```

## Uso no Pterodactyl

- A imagem usa um usuário não-root: `container`
- O diretório de trabalho padrão é `/home/container`
- O entrypoint aceita execução de scripts de startup ou comandos passados diretamente
- Variáveis de ambiente do Pterodactyl continuam funcionais
- O container foi preparado para manter o processo principal ativo enquanto o servidor estiver em execução

Exemplo de comando de execução:

```bash
docker run --rm -it \
  -v "$PWD:/home/container" \
  -w /home/container \
  --user 1000:1000 \
  loxyhosting/samp-ubuntu24:latest
```

## Observações de compatibilidade

Não é suficiente apenas construir a imagem. A compatibilidade real precisa ser confirmada com testes de arquitetura, bibliotecas, plugins e carga no Pterodactyl.

## Disclaimer

Este projeto foi preparado para ser salvo no repositório existente do cliente e deve ser integrado ao passo de publicação do Docker Hub ou em um registro privado conforme a política da infraestrutura.
