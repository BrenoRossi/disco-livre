#!/bin/zsh
# Instala o disco-livre: ferramenta de terminal + app da barra de menus + skill pra IA + vigilância.
#
#   ./install.sh                         pergunta a meta e as opções, e no fim abre a análise geral
#   ./install.sh --sim                   instala com os padrões, sem perguntar (bom pra IA)
#   ./install.sh --meta 30 --vigia sim --auto-limpeza nao
#   Exige --revisao <SHA completo> de um checkout Git limpo e revisado.
#   Outras opções: --sem-app --compilar --nao-abrir; app compilado do fonte local.
set -e
setopt PIPE_FAIL
cd "${0:A:h}"

B=$'\e[1m' D=$'\e[2m' G=$'\e[32m' Y=$'\e[33m' N=$'\e[0m'
[[ -t 1 ]] || B= D= G= Y= N=
BIN="$HOME/.local/bin"

VERSAO=$(sed -n 's/^VERSAO="\(.*\)"/\1/p' bin/disco-livre)

META= VIGIA= AUTO= SEM_APP= COMPILAR= NAO_ABRIR= PERGUNTAR=1 REVISAO=
[[ -t 0 ]] || PERGUNTAR=0
while (( $# )); do
  case $1 in
    --sim|-y)       PERGUNTAR=0 ;;
    --revisao)      REVISAO=$2; shift ;;
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
# Simulação não instala arquivos, skills, configuração ou tarefas.
if [[ ${DISCO_LIVRE_SIMULAR:-0} == 1 ]]; then
  print -r -- "Simulação: instalação não executada."
  exit 0
fi
[[ ${#REVISAO} == 40 && $REVISAO != *[^0-9a-f]* ]] || {
  print -r -- "Revise o checkout e informe --revisao <SHA completo>." >&2; exit 1
}
revisao_atual=$(git rev-parse --verify HEAD 2>/dev/null) || { print "Não consegui ler a revisão Git." >&2; exit 1; }
[[ $revisao_atual == $REVISAO ]] || {
  print -r -- "A revisão solicitada não corresponde ao checkout." >&2; exit 1
}
estado_git=$(git status --porcelain --untracked-files=no) || { print "Não consegui verificar o checkout." >&2; exit 1; }
[[ -z $estado_git ]] || {
  print -r -- "Há alterações locais; instale somente um commit revisado e limpo." >&2; exit 1
}
# Inclui somente os arquivos do commit: extras locais/ignorados não são instalados.
staging_source=$(mktemp -d)
trap 'rm -rf -- "$staging_source"' EXIT
git archive "$REVISAO" | tar -xf - -C "$staging_source"
cd "$staging_source"
# instalação por IA (sem perguntas): a própria IA conduz a análise geral e abre o app depois
(( PERGUNTAR )) || NAO_ABRIR=${NAO_ABRIR:-1}

print -r -- ""
print -r -- "${B}💽 Instalando o Disco Livre $VERSAO${N}"
[[ $(uname) == Darwin ]] || { print -r -- "O Disco Livre só funciona no macOS."; exit 1; }
MAC=$(sw_vers -productVersion)
(( ${MAC%%.*} >= 13 )) || { print -r -- "Precisa do macOS 13 (Ventura) ou mais novo. Este Mac está no $MAC."; exit 1; }

# 1. Ferramenta de terminal
mkdir -p "$BIN"
[[ ! -L "$BIN/disco-livre" ]] || { print "CLI instalada é um link; substituição recusada." >&2; exit 1; }
cli_nova=$(mktemp "$BIN/.disco-livre.XXXXXX")
cp bin/disco-livre "$cli_nova"
chmod +x "$cli_nova"
mv "$cli_nova" "$BIN/disco-livre"
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
  [[ -z $AUTO ]] && AUTO=nao
  if [[ -z $VIGIA ]]; then
    VIGIA=nao
  fi
fi
if (( PERGUNTAR )); then
  print -r -- ""
  [[ -z $META ]]  && { read -r "META?Quantos GB livres você quer manter no mínimo? [30] " || true; }
  [[ -z $VIGIA ]] && { read -r "VIGIA?Ligar a vigilância automática (avisa quando passar da meta)? [s/N] " || true; }
  if [[ $VIGIA == [sSyY]* && -z $AUTO ]]; then
    read -r "AUTO?Quando passar da meta, limpar o lixo seguro sozinho? [s/N] " || true
  fi
fi
[[ $META == <1-> ]] || META=30
[[ $VIGIA == [sSyY]* ]] && VIGIA=sim || VIGIA=nao
[[ $AUTO == [sSyY]* ]] && AUTO=sim || AUTO=nao

"$BIN/disco-livre" config somente-analisar sim >/dev/null
"$BIN/disco-livre" config meta "$META" >/dev/null
"$BIN/disco-livre" config auto-limpeza "$AUTO" >/dev/null
"$BIN/disco-livre" config limpar-crash nao >/dev/null
print -r -- "${G}✓${N} Meta: $META GB livres · limpeza automática: $AUTO"
if [[ $VIGIA == sim ]]; then
  "$BIN/disco-livre" ativar
elif [[ -f $HOME/Library/LaunchAgents/com.disco-livre.vigia.plist ]]; then
  "$BIN/disco-livre" desativar >/dev/null
fi

# 4. Compila exclusivamente o fonte do commit local revisado.
# Não baixa binários nem remove a quarentena do macOS.
APP_OK= DEST=
if [[ -z $SEM_APP ]]; then
  if command -v swiftc >/dev/null 2>&1 && app/build.sh; then
    app_compilado=$(cat app/build/app-path)
    [[ -d $app_compilado && ! -L $app_compilado ]] || { print "Build sem aplicativo válido." >&2; exit 1; }
    DEST=/Applications
    [[ -w $DEST ]] || { DEST="$HOME/Applications"; mkdir -p "$DEST"; }
    [[ ! -L "$DEST/Disco Livre.app" ]] || { print "Destino é um link; instalação recusada." >&2; exit 1; }
    staging=$(mktemp -d "$DEST/.disco-livre.XXXXXX")
    ditto "$app_compilado" "$staging/Disco Livre.app"
    codesign --verify --deep --strict "$staging/Disco Livre.app"
    backup="$DEST/Disco Livre.app.backup-$(date +%Y%m%d%H%M%S)"
    [[ ! -e $backup && ! -L $backup ]] || { print "Backup já existe: $backup" >&2; exit 1; }
    pkill -u "$UID" -x DiscoLivre 2>/dev/null || true
    if [[ -e "$DEST/Disco Livre.app" ]]; then mv "$DEST/Disco Livre.app" "$backup"; fi
    if mv "$staging/Disco Livre.app" "$DEST/Disco Livre.app"; then
      APP_OK=1
      rmdir "$staging"
      print -r -- "${G}✓${N} App compilado localmente em $DEST/Disco Livre.app"
    else
      [[ -d $backup ]] && mv "$backup" "$DEST/Disco Livre.app"
      print -r -- "Falha ao instalar o app; backup preservado: $backup" >&2
      exit 1
    fi
  else
    print -r -- "Não consegui compilar o app. CLI instalada; para o app são necessárias as ferramentas da Apple."
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
