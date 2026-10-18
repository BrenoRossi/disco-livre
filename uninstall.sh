#!/bin/zsh
# Remove o disco-livre (ferramenta, skill e vigilância). Não mexe em nada que ele limpou.
if [[ ${DISCO_LIVRE_SIMULAR:-0} == 1 ]]; then
  print -r -- "Simulação: desinstalação não executada."
  exit 0
fi
"$HOME/.local/bin/disco-livre" desativar 2>/dev/null
pkill -x DiscoLivre 2>/dev/null
rm -rf "/Applications/Disco Livre.app" "$HOME/Applications/Disco Livre.app"
rm -f "$HOME/.local/bin/disco-livre"
rm -rf "$HOME/.claude/skills/disco-livre" "$HOME/.codex/skills/disco-livre" "$HOME/.config/disco-livre"
print -r -- "✓ disco-livre removido. (O histórico fica em ~/Library/Logs/disco-livre.log)"
