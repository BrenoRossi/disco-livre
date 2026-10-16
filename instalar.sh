#!/bin/zsh
# Instalação em uma linha, sem git e sem ferramentas da Apple:
#   zsh -c "$(curl -fsSL https://raw.githubusercontent.com/Willclaf/disco-livre/main/instalar.sh)"
# Opções do install.sh podem vir depois:  ... instalar.sh)" -- --sim --meta 30
set -e
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
print -r -- "Baixando o Disco Livre…"
curl -fsSL "https://github.com/Willclaf/disco-livre/archive/refs/heads/main.tar.gz" | tar -xz -C "$tmp"
"$tmp/disco-livre-main/install.sh" "$@"
