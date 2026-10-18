#!/bin/zsh
# Entrada local: não baixa nem executa código da branch main.
set -e
if [[ ${DISCO_LIVRE_SIMULAR:-0} == 1 ]]; then
  print -r -- "Simulação: instalação não executada."
  exit 0
fi
raiz="${0:A:h}"
if [[ -f "$raiz/install.sh" && -d "$raiz/.git" ]]; then
  exec "$raiz/install.sh" "$@"
fi
print -r -- "Instalação remota por curl desativada. Clone BrenoRossi/disco-livre," >&2
print -r -- "revise um commit e execute ./install.sh --revisao <SHA completo>." >&2
exit 1
