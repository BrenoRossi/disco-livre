#!/bin/zsh
# Instala o disco-livre: ferramenta + skill pro Claude Code / Codex + vigilância.
set -e
cd "${0:A:h}"

B=$'\e[1m' G=$'\e[32m' Y=$'\e[33m' N=$'\e[0m'
BIN="$HOME/.local/bin"

print -r -- "${B}Instalando o disco-livre${N}"

mkdir -p "$BIN"
cp bin/disco-livre "$BIN/disco-livre"
chmod +x "$BIN/disco-livre"
print -r -- "${G}✓${N} Ferramenta em ~/.local/bin/disco-livre"

for dir in "$HOME/.claude" "$HOME/.codex"; do
  if [[ -d $dir ]]; then
    mkdir -p "$dir/skills"
    rm -rf "$dir/skills/disco-livre"
    cp -R skill/disco-livre "$dir/skills/disco-livre"
    print -r -- "${G}✓${N} Skill instalada em ${dir/#$HOME/~}/skills/disco-livre"
  fi
done

if [[ ":$PATH:" != *":$BIN:"* ]]; then
  if ! grep -q '.local/bin' "$HOME/.zshrc" 2>/dev/null; then
    print -r -- '' >> "$HOME/.zshrc"
    print -r -- '# disco-livre' >> "$HOME/.zshrc"
    print -r -- 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
  fi
  print -r -- "${Y}!${N} Abra um terminal novo (ou rode: source ~/.zshrc) pra usar o comando disco-livre"
fi

# Configuração inicial (só pergunta se for terminal interativo)
if [[ -t 0 ]]; then
  print -r -- ""
  read -r "meta?Quantos GB livres você quer manter no mínimo? [30] "
  "$BIN/disco-livre" config meta "${meta:-30}" >/dev/null

  read -r "auto?Ligar a vigilância automática (avisa quando passar da meta)? [S/n] "
  if [[ $auto != [nN]* ]]; then
    read -r "limpa?Quando passar da meta, limpar o lixo seguro sozinho? [s/N] "
    [[ $limpa == [sSyY]* ]] && "$BIN/disco-livre" config auto-limpeza sim >/dev/null
    "$BIN/disco-livre" ativar
  fi
fi

print -r -- ""
print -r -- "${G}Pronto!${N} Experimente: ${B}disco-livre analisar${N}"
