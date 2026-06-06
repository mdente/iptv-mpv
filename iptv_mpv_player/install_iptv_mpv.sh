#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="/opt/iptv-mpv"
BIN_FILE="/usr/local/bin/iptv-mpv"
APP_FILE="$APP_DIR/iptv_mpv.py"

echo "== IPTV MPV Player - Instalador Ubuntu =="

if [[ "${EUID}" -ne 0 ]]; then
  echo "ERRO: execute com sudo:"
  echo "  sudo bash install_iptv_mpv.sh"
  exit 1
fi

echo "== Instalando pacotes =="
apt update
apt install -y python3 python3-venv python3-pip mpv alsa-utils curl ca-certificates chafa

echo "== Criando diretório =="
mkdir -p "$APP_DIR"

cat > "$APP_FILE" <<'PYEOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
IPTV MPV Player para Ubuntu/Linux Server.

Lê playlist M3U/M3U8 com metadados:
  - tvg-id
  - tvg-name
  - tvg-logo
  - group-title
  - nome do canal após a vírgula do #EXTINF

Exibe seletor em terminal usando curses e abre o stream com mpv.
Quando possível, mostra o logo do canal usando chafa no terminal.
"""

from __future__ import annotations

import argparse
import curses
import hashlib
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Tuple


@dataclass
class Channel:
    index: int
    name: str
    url: str
    group: str = "Sem grupo"
    tvg_id: str = ""
    tvg_name: str = ""
    logo: str = ""


def clean_text(value: str) -> str:
    value = value or ""
    value = value.replace("\t", " ")
    value = re.sub(r"\s+", " ", value)
    return value.strip()


def parse_attrs(line: str) -> dict:
    attrs = {}
    for key, value in re.findall(r'([\w\-]+)="([^"]*)"', line):
        attrs[key.lower()] = clean_text(value)
    return attrs


def parse_m3u(path: Path) -> List[Channel]:
    if not path.exists():
        raise FileNotFoundError(f"Arquivo não encontrado: {path}")

    text = path.read_text(encoding="utf-8", errors="replace")
    lines = [line.strip() for line in text.splitlines() if line.strip()]

    channels: List[Channel] = []
    pending = None

    for line in lines:
        if line.startswith("#EXTINF"):
            attrs = parse_attrs(line)

            fallback_name = ""
            if "," in line:
                fallback_name = clean_text(line.split(",", 1)[1])

            tvg_name = clean_text(attrs.get("tvg-name", ""))
            name = tvg_name or fallback_name or clean_text(attrs.get("tvg-id", "")) or "Canal sem nome"

            pending = {
                "name": name,
                "group": clean_text(attrs.get("group-title", "")) or "Sem grupo",
                "tvg_id": clean_text(attrs.get("tvg-id", "")),
                "tvg_name": tvg_name,
                "logo": clean_text(attrs.get("tvg-logo", "")),
            }
            continue

        if line.startswith("#"):
            continue

        if line.startswith(("http://", "https://", "rtmp://", "rtsp://", "udp://")):
            if pending is None:
                pending = {
                    "name": f"Canal {len(channels) + 1}",
                    "group": "Sem grupo",
                    "tvg_id": "",
                    "tvg_name": "",
                    "logo": "",
                }

            channels.append(Channel(
                index=len(channels) + 1,
                name=pending["name"],
                url=line,
                group=pending["group"],
                tvg_id=pending["tvg_id"],
                tvg_name=pending["tvg_name"],
                logo=pending["logo"],
            ))
            pending = None

    return channels


def logo_cache_path(cache_dir: Path, logo_url: str) -> Path:
    digest = hashlib.sha1(logo_url.encode("utf-8", errors="ignore")).hexdigest()
    suffix = ".img"
    match = re.search(r"\.(png|jpg|jpeg|webp)(?:\?|$)", logo_url, re.I)
    if match:
        suffix = "." + match.group(1).lower().replace("jpeg", "jpg")
    return cache_dir / f"{digest}{suffix}"


def download_logo(cache_dir: Path, logo_url: str, timeout: int = 5) -> Optional[Path]:
    if not logo_url.startswith(("http://", "https://")):
        return None

    cache_dir.mkdir(parents=True, exist_ok=True)
    target = logo_cache_path(cache_dir, logo_url)
    if target.exists() and target.stat().st_size > 0:
        return target

    try:
        req = urllib.request.Request(
            logo_url,
            headers={"User-Agent": "Mozilla/5.0 iptv-mpv-player"},
        )
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = resp.read(1024 * 1024 * 3)
        if data:
            target.write_bytes(data)
            return target
    except Exception:
        return None

    return None


def render_logo_text(cache_dir: Path, logo_url: str, width: int = 30, height: int = 12) -> List[str]:
    if not shutil.which("chafa"):
        return []

    img_path = download_logo(cache_dir, logo_url)
    if not img_path:
        return []

    try:
        result = subprocess.run(
            ["chafa", "--symbols=block", f"--size={width}x{height}", str(img_path)],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=4,
            check=False,
        )
        if result.stdout.strip():
            return result.stdout.splitlines()
    except Exception:
        return []

    return []


def run_mpv(channel: Channel, audio: str, fullscreen: bool, no_video: bool, extra_args: List[str]) -> int:
    cmd = ["mpv"]

    if no_video:
        cmd.append("--no-video")

    if fullscreen:
        cmd.append("--fs")

    if audio:
        cmd.append(f"--ao={audio}")

    cmd += [
        "--force-window=yes",
        "--keep-open=no",
        f"--title=IPTV - {channel.name}",
        channel.url,
    ]

    cmd += extra_args

    print("")
    print(f"Reproduzindo: {channel.name}")
    print(f"Grupo       : {channel.group}")
    print(f"URL         : {channel.url}")
    print("")
    print("Teclas do mpv: q=sair | espaço=pause | 9/0=volume | f=tela cheia")
    print("Ao fechar o mpv, o seletor volta.")
    print("")

    try:
        return subprocess.call(cmd)
    except FileNotFoundError:
        print("ERRO: mpv não encontrado. Instale com: sudo apt install -y mpv")
        return 127


def filter_channels(channels: List[Channel], query: str, group: str) -> List[Channel]:
    q = clean_text(query).lower()
    selected = channels

    if group and group != "Todos":
        selected = [c for c in selected if c.group == group]

    if q:
        selected = [
            c for c in selected
            if q in c.name.lower()
            or q in c.group.lower()
            or q in c.tvg_id.lower()
            or q in c.url.lower()
        ]

    return selected


def draw_screen(stdscr, channels: List[Channel], filtered: List[Channel], pos: int, query: str, group: str, logo_lines: List[str]):
    stdscr.erase()
    height, width = stdscr.getmaxyx()

    title = " IPTV MPV Player "
    stdscr.addstr(0, 0, title[:width - 1], curses.A_REVERSE)

    help_line = "↑↓ navega | Enter toca | / busca | g grupo | a todos | r recarrega logo | q sai"
    stdscr.addstr(1, 0, help_line[:width - 1], curses.A_DIM)

    info = f"Canais: {len(channels)} | Filtro: {len(filtered)} | Grupo: {group or 'Todos'} | Busca: {query or '-'}"
    stdscr.addstr(2, 0, info[:width - 1])

    left_width = max(45, width - 42)
    list_top = 4
    list_height = max(3, height - list_top - 1)

    if not filtered:
        stdscr.addstr(4, 0, "Nenhum canal encontrado.")
        stdscr.refresh()
        return

    pos = max(0, min(pos, len(filtered) - 1))
    start = max(0, pos - list_height // 2)
    end = min(len(filtered), start + list_height)

    for row, idx in enumerate(range(start, end), list_top):
        channel = filtered[idx]
        marker = ">" if idx == pos else " "
        line = f"{marker} {channel.index:04d} | {channel.group[:22]:22} | {channel.name}"
        attr = curses.A_REVERSE if idx == pos else curses.A_NORMAL
        stdscr.addstr(row, 0, line[:left_width - 1], attr)

    detail_x = min(left_width + 1, width - 1)
    if detail_x < width - 10:
        selected = filtered[pos]
        stdscr.addstr(4, detail_x, "Detalhes".ljust(width - detail_x - 1), curses.A_BOLD)
        detail_lines = [
            f"Nome : {selected.name}",
            f"Grupo: {selected.group}",
            f"ID   : {selected.tvg_id or '-'}",
            f"Logo : {selected.logo or '-'}",
            "",
            "Logo terminal:",
        ]

        y = 6
        for line in detail_lines:
            if y < height - 1:
                stdscr.addstr(y, detail_x, line[:width - detail_x - 1])
                y += 1

        for line in logo_lines[: max(0, height - y - 1)]:
            if y < height - 1:
                safe = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", line)
                stdscr.addstr(y, detail_x, safe[:width - detail_x - 1])
                y += 1

    stdscr.refresh()


def ask_input(stdscr, prompt: str) -> str:
    curses.echo()
    height, width = stdscr.getmaxyx()
    stdscr.move(height - 1, 0)
    stdscr.clrtoeol()
    stdscr.addstr(height - 1, 0, prompt[:width - 1])
    value = stdscr.getstr(height - 1, min(len(prompt), width - 2), max(1, width - len(prompt) - 1))
    curses.noecho()
    try:
        return value.decode("utf-8", errors="replace").strip()
    except Exception:
        return ""


def choose_group(stdscr, groups: List[str], current: str) -> str:
    stdscr.erase()
    height, width = stdscr.getmaxyx()
    stdscr.addstr(0, 0, "Escolha o grupo - Enter seleciona | q cancela", curses.A_REVERSE)

    groups2 = ["Todos"] + groups
    pos = max(0, groups2.index(current) if current in groups2 else 0)

    while True:
        stdscr.erase()
        stdscr.addstr(0, 0, "Escolha o grupo - Enter seleciona | q cancela", curses.A_REVERSE)
        start = max(0, pos - (height - 4) // 2)
        end = min(len(groups2), start + height - 2)
        for row, idx in enumerate(range(start, end), 2):
            attr = curses.A_REVERSE if idx == pos else curses.A_NORMAL
            stdscr.addstr(row, 0, groups2[idx][:width - 1], attr)
        stdscr.refresh()

        key = stdscr.getch()
        if key in (ord("q"), 27):
            return current
        if key in (curses.KEY_ENTER, 10, 13):
            return groups2[pos]
        if key == curses.KEY_UP:
            pos = max(0, pos - 1)
        if key == curses.KEY_DOWN:
            pos = min(len(groups2) - 1, pos + 1)


def ui(stdscr, args):
    curses.curs_set(0)
    stdscr.keypad(True)

    channels = parse_m3u(Path(args.playlist))
    if not channels:
        raise RuntimeError("Nenhum canal encontrado no arquivo M3U.")

    groups = sorted({c.group for c in channels})
    query = args.search or ""
    group = "Todos"
    pos = 0
    logo_lines: List[str] = []
    cache_dir = Path.home() / ".cache" / "iptv-mpv" / "logos"
    last_logo_url = ""

    while True:
        filtered = filter_channels(channels, query, group)
        if pos >= len(filtered):
            pos = max(0, len(filtered) - 1)

        selected = filtered[pos] if filtered else None
        if selected and selected.logo != last_logo_url:
            last_logo_url = selected.logo
            logo_lines = render_logo_text(cache_dir, selected.logo, width=30, height=10)

        draw_screen(stdscr, channels, filtered, pos, query, group, logo_lines)

        key = stdscr.getch()

        if key in (ord("q"), 27):
            break

        if key == curses.KEY_UP:
            pos = max(0, pos - 1)
        elif key == curses.KEY_DOWN:
            pos = min(max(0, len(filtered) - 1), pos + 1)
        elif key == curses.KEY_NPAGE:
            pos = min(max(0, len(filtered) - 1), pos + 10)
        elif key == curses.KEY_PPAGE:
            pos = max(0, pos - 10)
        elif key in (ord("/"),):
            query = ask_input(stdscr, "Buscar: ")
            pos = 0
            last_logo_url = ""
        elif key in (ord("a"),):
            query = ""
            group = "Todos"
            pos = 0
            last_logo_url = ""
        elif key in (ord("g"),):
            group = choose_group(stdscr, groups, group)
            pos = 0
            last_logo_url = ""
        elif key in (ord("r"),):
            last_logo_url = ""
            logo_lines = []
        elif key in (curses.KEY_ENTER, 10, 13):
            if not selected:
                continue
            curses.endwin()
            run_mpv(selected, args.audio, args.fullscreen, args.no_video, args.mpv_arg or [])
            input("\nPressione Enter para voltar ao seletor...")
            stdscr.clear()
            curses.curs_set(0)


def main() -> int:
    parser = argparse.ArgumentParser(description="Seletor de canais M3U para mpv.")
    parser.add_argument("playlist", help="Arquivo .m3u/.m3u8")
    parser.add_argument("--audio", default="alsa", help="Saída de áudio do mpv: alsa, pulse, pipewire, auto. Padrão: alsa")
    parser.add_argument("--fullscreen", action="store_true", help="Abrir mpv em tela cheia")
    parser.add_argument("--no-video", action="store_true", help="Tocar somente áudio")
    parser.add_argument("--search", default="", help="Busca inicial")
    parser.add_argument("--mpv-arg", action="append", default=[], help="Argumento extra para mpv. Pode repetir.")
    args = parser.parse_args()

    if args.audio == "auto":
        args.audio = ""

    try:
        curses.wrapper(ui, args)
        return 0
    except KeyboardInterrupt:
        return 0
    except Exception as exc:
        print(f"ERRO: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
PYEOF

chmod +x "$APP_FILE"

cat > "$BIN_FILE" <<EOF
#!/usr/bin/env bash
exec python3 "$APP_FILE" "\$@"
EOF

chmod +x "$BIN_FILE"

echo "== Ajustando áudio ALSA =="
amixer sset Master unmute >/dev/null 2>&1 || true
amixer sset Speaker unmute >/dev/null 2>&1 || true
amixer sset Headphone unmute >/dev/null 2>&1 || true
amixer sset PCM unmute >/dev/null 2>&1 || true
amixer sset Master 80% >/dev/null 2>&1 || true
amixer sset Speaker 80% >/dev/null 2>&1 || true
amixer sset Headphone 80% >/dev/null 2>&1 || true
amixer sset PCM 80% >/dev/null 2>&1 || true

echo ""
echo "Instalação concluída."
echo ""
echo "Uso:"
echo "  iptv-mpv /caminho/para/lista.m3u"
echo ""
echo "Exemplo:"
echo "  iptv-mpv ~/canais.m3u"
echo ""
echo "Para forçar PulseAudio:"
echo "  iptv-mpv ~/canais.m3u --audio pulse"
echo ""
echo "Para usar PipeWire:"
echo "  iptv-mpv ~/canais.m3u --audio pipewire"
echo ""
echo "Para somente áudio:"
echo "  iptv-mpv ~/canais.m3u --no-video"
echo ""
