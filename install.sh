#!/bin/zsh
# Instala o disco-livre: ferramenta de terminal + app da barra de menus + skill pra IA + vigilância.
#
#   ./install.sh                         pergunta a meta e as opções, e no fim abre a análise geral
#   ./install.sh --sim                   instala com os padrões, sem perguntar (bom pra IA)
#   ./install.sh --meta 30 --vigia sim --auto-limpeza nao
#   Outras opções: --sem-app  --compilar (compila em vez de baixar o app pronto)  --nao-abrir
set -e
cd "${0:A:h}"

B=$'\e[1m' D=$'\e[2m' G=$'\e[32m' Y=$'\e[33m' N=$'\e[0m'
[[ -t 1 ]] || B= D= G= Y= N=
BIN="$HOME/.local/bin"
REPO="Willclaf/disco-livre"
VERSAO=$(sed -n 's/^VERSAO="\(.*\)"/\1/p' bin/disco-livre)

META= VIGIA= AUTO= SEM_APP= COMPILAR= NAO_ABRIR= PERGUNTAR=1
[[ -t 0 ]] || PERGUNTAR=0
while (( $# )); do
  case $1 in
    --sim|-y)       PERGUNTAR=0 ;;
    --meta)         META=$2; shift ;;
    --vigia)        VIGIA=$2; shift ;;
    --auto-limpeza) AUTO=$2; shift ;;
    --sem-app)      SEM_APP=1 ;;
    --compilar)     COMPILAR=1 ;;
    --nao-abrir)    NAO_ABRIR=1 ;;
    -h|--help)      sed -n '2,7p' "$0"; exit 0 ;;
    *) print -r -- "opção desconhecida: $1" >&2; exit 1 ;;
  esac
  shift
done
# instalação por IA (sem perguntas): a própria IA conduz a análise geral e abre o app depois
(( PERGUNTAR )) || NAO_ABRIR=${NAO_ABRIR:-1}

print -r -- ""
print -r -- "${B}💽 Instalando o Disco Livre $VERSAO${N}"
[[ $(uname) == Darwin ]] || { print -r -- "O Disco Livre só funciona no macOS."; exit 1; }
MAC=$(sw_vers -productVersion)
(( ${MAC%%.*} >= 13 )) || { print -r -- "Precisa do macOS 13 (Ventura) ou mais novo. Este Mac está no $MAC."; exit 1; }

# 1. Ferramenta de terminal
mkdir -p "$BIN"
cp bin/disco-livre "$BIN/disco-livre"
chmod +x "$BIN/disco-livre"
print -r -- "${G}✓${N} Ferramenta em ~/.local/bin/disco-livre"

if [[ ":$PATH:" != *":$BIN:"* ]] && ! grep -q '.local/bin' "$HOME/.zshrc" 2>/dev/null; then
  print -r -- '' >> "$HOME/.zshrc"
  print -r -- '# disco-livre' >> "$HOME/.zshrc"
  print -r -- 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
  print -r -- "${G}✓${N} Comando disco-livre liberado no Terminal (vale nas janelas novas)"
fi

# 2. Skill pro Claude Code / Codex
for dir in "$HOME/.claude" "$HOME/.codex"; do
  if [[ -d $dir ]]; then
    mkdir -p "$dir/skills"
    rm -rf "$dir/skills/disco-livre"
    cp -R skill/disco-livre "$dir/skills/disco-livre"
    print -r -- "${G}✓${N} Skill em ${dir/#$HOME/~}/skills/disco-livre"
  fi
done

# 3. Configuração (numa atualização, mantém o que a pessoa já tinha escolhido)
CONF_ATUAL="$HOME/.config/disco-livre/config"
ATUALIZANDO=
if [[ -f $CONF_ATUAL ]]; then
  ATUALIZANDO=1
  [[ -z $META ]] && META=$(sed -n 's/^META_GB=//p' "$CONF_ATUAL")
  [[ -z $AUTO ]] && AUTO=$(sed -n 's/^AUTO_LIMPEZA=//p' "$CONF_ATUAL")
  if [[ -z $VIGIA ]]; then
    [[ -f $HOME/Library/LaunchAgents/com.disco-livre.vigia.plist ]] && VIGIA=sim || VIGIA=nao
  fi
fi
if (( PERGUNTAR )); then
  print -r -- ""
  [[ -z $META ]]  && { read -r "META?Quantos GB livres você quer manter no mínimo? [30] " || true; }
  [[ -z $VIGIA ]] && { read -r "VIGIA?Ligar a vigilância automática (avisa quando passar da meta)? [S/n] " || true; }
  if [[ $VIGIA != [nN]* && -z $AUTO ]]; then
    read -r "AUTO?Quando passar da meta, limpar o lixo seguro sozinho? [s/N] " || true
  fi
fi
[[ $META == <1-> ]] || META=30
[[ $VIGIA == [nN]* ]] && VIGIA=nao || VIGIA=sim
[[ $AUTO == [sSyY]* ]] && AUTO=sim || AUTO=nao

"$BIN/disco-livre" config meta "$META" >/dev/null
"$BIN/disco-livre" config auto-limpeza "$AUTO" >/dev/null
print -r -- "${G}✓${N} Meta: $META GB livres · limpeza automática: $AUTO"
if [[ $VIGIA == sim ]]; then
  "$BIN/disco-livre" ativar
elif [[ -f $HOME/Library/LaunchAgents/com.disco-livre.vigia.plist ]]; then
  "$BIN/disco-livre" desativar >/dev/null
fi

# 4. App da barra de menus
#    a) baixa o app pronto (universal, conferido por SHA-256) — funciona em qualquer Mac, sem ferramentas da Apple
#    b) se não der, compila aqui (precisa das Ferramentas de Linha de Comando da Apple)
APP_OK= DEST=
instalar_app() {   # $1 = pasta do .app
  DEST=/Applications
  [[ -w $DEST ]] || { DEST="$HOME/Applications"; mkdir -p "$DEST"; }
  pkill -x DiscoLivre 2>/dev/null || true
  rm -rf "$DEST/Disco Livre.app"
  ditto "$1" "$DEST/Disco Livre.app"
  xattr -dr com.apple.quarantine "$DEST/Disco Livre.app" 2>/dev/null || true
  APP_OK=1
}

baixar_app() {
  local tmp esperado obtido
  [[ -f app/DiscoLivre.zip.sha256 ]] || return 1
  esperado=$(cut -d' ' -f1 < app/DiscoLivre.zip.sha256)
  tmp=$(mktemp -d)
  curl -fsL --retry 2 -o "$tmp/DiscoLivre.zip" \
    "https://github.com/$REPO/releases/download/v$VERSAO/DiscoLivre.zip" || { rm -rf "$tmp"; return 1; }
  obtido=$(shasum -a 256 "$tmp/DiscoLivre.zip" | cut -d' ' -f1)
  if [[ $obtido != $esperado ]]; then
    print -r -- "${Y}!${N} O app baixado não bate com a assinatura esperada — não vou instalar ele."
    rm -rf "$tmp"; return 1
  fi
  ditto -x -k "$tmp/DiscoLivre.zip" "$tmp/app" || { rm -rf "$tmp"; return 1; }
  instalar_app "$tmp/app/Disco Livre.app"
  rm -rf "$tmp"
}

compilar_app() {
  command -v swiftc >/dev/null 2>&1 || return 1
  print -r -- "  Compilando o app (uns 30 segundos)…"
  app/build.sh >/dev/null 2>&1 || return 1
  instalar_app "app/build/Disco Livre.app"
}

if [[ -z $SEM_APP ]]; then
  if [[ -n $COMPILAR ]]; then
    compilar_app || baixar_app || true
  else
    print -r -- "  Baixando o app…"
    baixar_app || compilar_app || true
  fi
  if [[ -n $APP_OK ]]; then
    print -r -- "${G}✓${N} App em ${DEST/#$HOME/~}/Disco Livre.app"
  else
    print -r -- "${Y}!${N} Não consegui instalar o app da barra de menus. A ferramenta de terminal funciona normalmente."
    print -r -- "  ${D}Pra tentar compilar: xcode-select --install e depois ./install.sh --compilar${N}"
  fi
fi

print -r -- ""
print -r -- "${G}${B}Pronto!${N} 🎉"

# 5. Primeira impressão: a análise geral do Mac
if [[ -z $NAO_ABRIR ]]; then
  if [[ -n $APP_OK ]]; then
    if [[ -n $ATUALIZANDO ]]; then
      open "$DEST/Disco Livre.app"
      print -r -- "Atualizado! O Disco Livre está de volta na barra de menus."
    else
      open "$DEST/Disco Livre.app" --args --boas-vindas
      print -r -- ""
      print -r -- "👉 ${B}Olhe lá em cima, na barra de menus:${N} o Disco Livre abriu a análise geral do seu Mac."
      print -r -- "   Ele mostra quanto espaço escondido encontrou e você escolhe o que limpar."
    fi
  elif (( PERGUNTAR )); then
    "$BIN/disco-livre" geral
  fi
else
  print -r -- "  ${D}Próximo passo: disco-livre geral (análise geral do Mac)${N}"
fi
