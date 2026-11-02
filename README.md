# loxy-game-eggs
Eggs, scripts de inicialização e runtimes personalizados para servidores SA-MP, OpenMP e outros serviços da Loxy Hosting no Pterodactyl.

## SA-MP startup

O launcher de SA-MP foi reestruturado para validar o runtime, detectar arquitetura do executável e plugins, fazer backup de server.cfg antes de ajustes de runtime e evitar download não validado de sampvoice.so.

Variáveis suportadas:
- `SAMP_VOIP=1` ou `0` para habilitar/desabilitar o SA-MP Voice.
- `VOIP_PORT` para a porta do voice em separado da principal.
- `SAMP_PLUGIN_SSCANF`, `SAMP_PLUGIN_STREAMER`, `SAMP_PLUGIN_PAWNRAKNET`, `SAMP_PLUGIN_SAMPVOICE` para controle individual dos plugins.
- `SAMP_DIAGNOSTIC=1` para iniciar em modo diagnóstico sem Pawn.RakNet e sem SampVoice.
- `SAMPVOICE_VERSION` para fixar a versão do plugin e `SAMPVOICE_SHA256` para validar o arquivo antes de substituir o plugin instalado.

A versão fixa do SampVoice usada pela egg é `1.0.0`, com hash SHA-256 validado antes de instalar o arquivo no diretório de plugins.

Quando `tail` está disponível, o launcher exibe no console do Pterodactyl apenas as novas linhas de `server_log.txt`; o stdout normal do executável é suprimido para não repetir as mesmas mensagens. O stderr continua visível para diagnósticos. Sem `tail`, usa stdout/stderr diretamente como alternativa.

## Acelerador de downloads MTA

O `mta.sh` baixa `mta-accelerator.py` do repositório, valida o script antes de substituir a cópia local e só inicia o MTA depois que o listener HTTP do acelerador responde. O acelerador transmite os bytes originais de qualquer arquivo presente no cache do MTA (incluindo PNG, TXD, DFF, COL, áudio e mods), sem gzip ou outra transformação que possa alterar tamanho, CRC ou MD5. O servidor HTTP atende downloads em paralelo e transmite arquivos em blocos, sem carregar arquivos grandes inteiros na memória.

Configure `EXPRESS_PORT` com uma allocation adicional do Pterodactyl. Opcionalmente, defina `MTA_DOWNLOAD_HOST` para o IP público ou domínio que os jogadores usarão. Se estiver vazio, o acelerador tenta `SERVER_IP` e depois detecta o IP público. Os requests e erros do processo são registrados em `accelerator.log` e `accelerator_error.log`; falhas de inicialização também são exibidas no console.

Os testes locais podem ser executados com `python3 -m unittest discover -s tests -p 'test_mta_accelerator.py' -v`.
