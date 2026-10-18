#!/bin/zsh
# Assina somente uma cópia do app recém-compilado; nunca instala ou abre o app.
set -euo pipefail
umask 077
cd "${0:A:h}/.."
if [[ ${DISCO_LIVRE_SIMULAR:-0} == 1 ]]; then
  print 'Simulação: nenhuma assinatura ou submissão foi realizada.'
  exit 0
fi
(( $# == 2 )) || { print -u2 'Uso: scripts/notarizar.sh <Developer ID Application: nome (TEAM)> <perfil-local-notarytool>'; exit 1; }
IDENTIDADE=$1
PERFIL=$2
[[ $IDENTIDADE == 'Developer ID Application: '* ]] || { print -u2 'Exige identidade Developer ID Application.'; exit 1; }
# Somente identidades com chave privada disponíveis no chaveiro local.
security find-identity -v -p codesigning | /usr/bin/grep -F -- "\"$IDENTIDADE\"" >/dev/null || {
  print -u2 'Certificado/chave privada Developer ID indisponível no chaveiro.'; exit 1
}
./app/build.sh
ORIGINAL=$(cat app/build/app-path)
[[ -d $ORIGINAL && ! -L $ORIGINAL ]] || exit 1
SAIDA=$(mktemp -d "${TMPDIR:-/tmp}/disco-livre-release.XXXXXX")
APP="$SAIDA/Disco Livre.app"
ditto "$ORIGINAL" "$APP"
codesign --force --options runtime --timestamp --sign "$IDENTIDADE" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
# ZIP de submissão. As credenciais ficam no chaveiro, nunca no repositório.
ditto -c -k --keepParent "$APP" "$SAIDA/submissao.zip"
xcrun notarytool submit "$SAIDA/submissao.zip" --keychain-profile "$PERFIL" --wait --output-format plist > "$SAIDA/notarizacao.plist"
[[ $(/usr/libexec/PlistBuddy -c 'Print :status' "$SAIDA/notarizacao.plist") == Accepted ]] || {
  print -u2 "Notarização não aprovada. Consulte $SAIDA/notarizacao.plist"; exit 1
}
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"
ditto -c -k --keepParent "$APP" "$SAIDA/Disco-Livre-notarizado.zip"
shasum -a 256 "$SAIDA/Disco-Livre-notarizado.zip" > "$SAIDA/Disco-Livre-notarizado.zip.sha256"
print -r -- "Artefato assinado, notarizado e validado: $SAIDA/Disco-Livre-notarizado.zip"
