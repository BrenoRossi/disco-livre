#!/bin/zsh
# Remove o disco-livre (ferramenta, skill e vigilância). Não mexe em nada que ele limpou.
"$HOME/.local/bin/disco-livre" desativar 2>/dev/null
rm -f "$HOME/.local/bin/disco-livre"
rm -rf "$HOME/.claude/skills/disco-livre" "$HOME/.codex/skills/disco-livre" "$HOME/.config/disco-livre"
print -r -- "✓ disco-livre removido. (O histórico fica em ~/Library/Logs/disco-livre.log)"
