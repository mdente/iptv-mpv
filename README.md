# IPTV MPV Player para Ubuntu Server

Um seletor de canais IPTV simples, leve e funcional para **Ubuntu Linux / Ubuntu Server**, feito em **Python** e usando o **mpv** como player.

O projeto lê arquivos `.m3u` ou `.m3u8`, organiza os canais por grupo, exibe nome, categoria, logo quando possível e permite reproduzir qualquer stream diretamente pelo terminal.

Funciona muito bem em ambientes sem interface gráfica pesada, como notebooks antigos, servidores Linux, mini PCs e instalações minimalistas do Ubuntu.

---

## ✨ Funcionalidades

* Leitura de playlists `.m3u` e `.m3u8`
* Suporte a metadados IPTV:

  * `tvg-id`
  * `tvg-name`
  * `tvg-logo`
  * `group-title`
* Seletor interativo de canais no terminal
* Busca por nome de canal
* Filtro por grupo/categoria
* Exibição de logo no terminal quando disponível
* Reprodução com `mpv`
* Suporte a áudio via:

  * ALSA
  * PulseAudio
  * PipeWire
* Opção de reprodução somente áudio
* Opção de tela cheia
* Retorno automático ao seletor ao fechar o player
* Ideal para Ubuntu Server

---

## 📺 Exemplo de playlist suportada

```m3u
#EXTM3U
#EXTINF:-1 tvg-id="band.br" tvg-name="Band HD" tvg-logo="https://i.imgur.com/nCJNjyN.png" group-title="Canais | Band",Band HD
http://servidor.exemplo/live/usuario/senha/36990.ts

#EXTINF:-1 tvg-id="tnt.br" tvg-name="TNT [4K]" tvg-logo="https://i.imgur.com/s99Fd0l.png" group-title="Canais | TNT",TNT [4K]
http://servidor.exemplo/live/usuario/senha/215404.ts
```

---

## 🧰 Requisitos

O instalador configura os principais pacotes automaticamente, mas o projeto utiliza:

* Python 3
* mpv
* alsa-utils
* chafa
* curl
* python3-requests

---

## 🚀 Instalação

Clone o repositório:

```bash
git clone https://github.com/seu-usuario/iptv-mpv-player.git
cd iptv-mpv-player
```

Execute o instalador:

```bash
chmod +x install_iptv_mpv.sh
sudo ./install_iptv_mpv.sh
```

Após a instalação, o comando `iptv-mpv` ficará disponível no sistema.

---

## ▶️ Como usar

Execute informando o arquivo da playlist:

```bash
iptv-mpv ~/canais.m3u
```

Também funciona com `.m3u8`:

```bash
iptv-mpv ~/minha-playlist.m3u8
```

---

## 🎮 Teclas do seletor

| Tecla                 | Ação                    |
| --------------------- | ----------------------- |
| `↑` / `↓`             | Navegar entre canais    |
| `PageUp` / `PageDown` | Navegar mais rápido     |
| `Enter`               | Tocar canal selecionado |
| `/`                   | Buscar canal por texto  |
| `g`                   | Filtrar por grupo       |
| `a`                   | Limpar busca e filtros  |
| `r`                   | Recarregar logo         |
| `q`                   | Sair                    |

---

## 🔊 Áudio no Ubuntu Server

Por padrão, o programa usa **ALSA**, que costuma funcionar melhor em Ubuntu Server.

```bash
iptv-mpv ~/canais.m3u --audio alsa
```

Para usar PulseAudio:

```bash
iptv-mpv ~/canais.m3u --audio pulse
```

Para usar PipeWire:

```bash
iptv-mpv ~/canais.m3u --audio pipewire
```

---

## 🖥️ Modo tela cheia

```bash
iptv-mpv ~/canais.m3u --fullscreen
```

---

## 🎧 Somente áudio

Útil para rádios ou streams sem necessidade de vídeo:

```bash
iptv-mpv ~/canais.m3u --no-video
```

---

## 🛠️ Ajuste de som no Linux

Se estiver sem áudio, teste primeiro o mixer do ALSA:

```bash
alsamixer
```

Dentro do `alsamixer`:

1. Pressione `F6`
2. Escolha a placa de som correta
3. Verifique `Master`, `Speaker`, `Headphone` e `PCM`
4. Se algum canal estiver como `MM`, pressione `M` para desmutar
5. Aumente o volume com as setas

Também é possível desmutar via terminal:

```bash
amixer sset Master unmute
amixer sset Speaker unmute
amixer sset Headphone unmute
amixer sset PCM unmute
amixer sset Master 80%
amixer sset Speaker 80%
amixer sset Headphone 80%
amixer sset PCM 80%
```

Teste o áudio com:

```bash
speaker-test -c 2 -t wav
```

---

## 📁 Estrutura sugerida do projeto

```text
iptv-mpv-player/
├── install_iptv_mpv.sh
├── iptv_mpv.py
├── README.md
└── examples/
    └── exemplo.m3u
```

---

## 📦 Exemplo de uso completo

```bash
sudo apt update
sudo apt install -y unzip

git clone https://github.com/seu-usuario/iptv-mpv-player.git
cd iptv-mpv-player

chmod +x install_iptv_mpv.sh
sudo ./install_iptv_mpv.sh

iptv-mpv ~/canais.m3u
```

---

## 🧪 Teste direto com mpv

Antes de usar o seletor, você pode testar um stream manualmente:

```bash
mpv --ao=alsa http://servidor.exemplo/live/usuario/senha/canal.ts
```

Somente áudio:

```bash
mpv --no-video --ao=alsa http://servidor.exemplo/live/usuario/senha/canal.ts
```

---

## 🐧 Uso recomendado

Este projeto foi pensado para quem quer transformar um Ubuntu Server em um player IPTV leve, sem depender de interfaces gráficas pesadas.

Casos ideais:

* ThinkPad antigo com Ubuntu Server
* Mini PC conectado na TV
* Servidor Linux com saída HDMI
* Ambiente sem desktop completo
* Player simples via terminal
* Rádio/TV via streaming com `mpv`

---

## ⚠️ Observação importante

Este projeto é apenas um **leitor de playlists M3U** e um **seletor local de canais**.

Ele não fornece canais, listas, credenciais, servidores IPTV ou qualquer tipo de conteúdo.
Use apenas playlists e streams aos quais você tenha direito de acesso.

---

## ❤️ Créditos

Criado para simplificar o uso de IPTV no Ubuntu Server usando ferramentas abertas, leves e confiáveis:

* Python
* mpv
* ALSA
* chafa

---

## 📄 Licença

Este projeto pode ser usado, modificado e distribuído livremente.

Sugestão de licença: MIT.
