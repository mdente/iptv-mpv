# IPTV MPV Player para Ubuntu Server

Programa em Python para ler um arquivo `.m3u`/`.m3u8`, exibir um seletor de canais no terminal e abrir o canal escolhido usando `mpv`.

## Recursos

- Lê `#EXTM3U` e entradas `#EXTINF`.
- Usa `tvg-name`, `tvg-logo`, `group-title` e nome do canal.
- Permite buscar por canal, grupo, ID ou URL.
- Permite filtrar por grupo.
- Mostra logo no terminal quando possível usando `chafa`.
- Abre stream com `mpv`.
- Por padrão usa `--ao=alsa`, melhor para Ubuntu Server sem interface gráfica.

## Instalação

Copie o arquivo `install_iptv_mpv.sh` para o Ubuntu e execute:

```bash
chmod +x install_iptv_mpv.sh
sudo ./install_iptv_mpv.sh
```

## Uso

```bash
iptv-mpv ~/canais.m3u
```

Com tela cheia:

```bash
iptv-mpv ~/canais.m3u --fullscreen
```

Somente áudio:

```bash
iptv-mpv ~/canais.m3u --no-video
```

Forçar PulseAudio:

```bash
iptv-mpv ~/canais.m3u --audio pulse
```

Forçar PipeWire:

```bash
iptv-mpv ~/canais.m3u --audio pipewire
```

## Teclas do seletor

- `↑` / `↓`: navegar
- `PageUp` / `PageDown`: navegar rápido
- `Enter`: tocar canal
- `/`: buscar
- `g`: escolher grupo
- `a`: limpar busca e voltar para todos
- `r`: recarregar logo
- `q`: sair

## Teclas do mpv

- `q`: sair do canal e voltar ao seletor
- `espaço`: pause/play
- `9` / `0`: volume
- `f`: tela cheia

## Diagnóstico de áudio

```bash
aplay -l
alsamixer
speaker-test -c 2 -t wav
```

Dentro do `alsamixer`, escolha a placa com `F6`, desmute com `M` e aumente `Master`, `Speaker`, `Headphone` e `PCM`.

## Observação

Use somente playlists/streams que você tem direito de acessar.
