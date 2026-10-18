# Disco Livre — fork com correções de segurança

Fork de [Willclaf/disco-livre](https://github.com/Willclaf/disco-livre), sob a licença MIT original. Esta versão corrige os problemas encontrados na auditoria da 1.3.2. Consulte [SECURITY.md](SECURITY.md) para os limites e [CHANGELOG.md](CHANGELOG.md) para as mudanças.

O aplicativo mostra o espaço livre na barra de menus, analisa pastas e permite escolher itens para limpeza. Há também uma CLI zsh e uma skill para Claude Code/Codex. Funciona no macOS 13 ou posterior, Intel e Apple Silicon.

## Padrões desta versão

- Vigilância e limpezas começam desligadas. Configurações antigas precisam de novo consentimento para limpeza automática.
- Relatórios de falhas só entram na limpeza automática quando **auto-limpeza e limpar-crash** estão ligados. Desligar auto-limpeza impede ambas as exclusões automáticas.
- A simulação `DISCO_LIVRE_SIMULAR=1` impede instalação, exclusões, movimentação, atualização e alteração de tarefas/configuração. Somente o registro de simulação pode ser escrito.
- A limpeza recalcula o alvo no catálogo atual e recusa ids forjados, caminhos com links e alvos fora da pasta pessoal.
- Falhas são reportadas. “Aumento medido” vem da diferença de espaço livre do volume; pode ser afetado por outros aplicativos e pelo APFS. Não é a soma de estimativas antigas.

## Instalar um commit revisado

**Este fork não publica um DMG notarizado.** O aplicativo é compilado do fonte local. Não use os binários da versão original para obter estas correções. O instalador não remove a quarentena do macOS nem executa scripts baixados da branch `main`.

Requisitos: Git; ferramentas de linha de comando da Apple para compilar o aplicativo (`swiftc`, `lipo`, `iconutil`). A CLI usa os utilitários do macOS, sem pacotes de terceiros. Python 3 só é necessário para os testes.

```sh
git clone https://github.com/BrenoRossi/disco-livre.git
cd disco-livre
git log --oneline -5
```

Revise o código e selecione um SHA completo de 40 caracteres. Substitua `<SHA_REVISADO>` nas duas linhas:

```sh
git checkout --detach <SHA_REVISADO>
./install.sh --revisao <SHA_REVISADO>
```

O instalador recusa um SHA diferente do checkout ou alterações locais em arquivos versionados. Ele copia CLI/skill/configuração e compila o app; só ativa a vigilância se você escolher isso. A compilação local é assinada ad hoc, sem certificado de distribuição Apple. Para instalar apenas a CLI, acrescente `--sem-app`.

Para aceitar os padrões sem interação, use `--sim --vigia nao --auto-limpeza nao --nao-abrir`. Nesse instalador, `--sim` significa “sim, aceitar padrões”; a **simulação sem alterações** é sempre a variável `DISCO_LIVRE_SIMULAR=1`.

Não houve instalação do app ou ativação de serviços durante o desenvolvimento destas correções.

## Usar

```sh
disco-livre                     # resumo
disco-livre dados geral          # análise em JSON
disco-livre geral                # análise com seleção e confirmação
disco-livre limpar               # estimativa, sem excluir
disco-livre limpar --executar    # pede confirmação antes de excluir
disco-livre limpar-itens <ids> --json  # somente ids escolhidos da análise
disco-livre config              # configurações
disco-livre ativar               # opt-in: instala o vigia a cada 3 horas
disco-livre desativar            # para o vigia e remove seu LaunchAgent
```

`limpar-itens` devolve `erros` por item e status diferente de zero se houver falha. Itens em uso aparecem em `pulados`. O cache da análise nunca autoriza, sozinho, uma exclusão. Logs ficam em `~/Library/Logs/disco-livre.log`.

Para permitir limpeza automática abaixo da meta:

```sh
disco-livre config auto-limpeza sim
```

Para permitir também a exclusão automática de relatórios acumulados, habilite separadamente `disco-livre config limpar-crash sim`. A interface mostra ambos os controles. Relatórios são evidências úteis para diagnóstico; mantenha a opção desligada enquanto investiga falhas.

Esvaziar a Lixeira exige confirmação e apaga **todo o conteúdo dela**, não apenas itens enviados pelo Disco Livre.

## Mover pastas com recuperação

```sh
disco-livre mover <pasta> <destino>
```

A função copia com `ditto`, verifica cada entrada, conteúdo, links, permissões, atributos estendidos e ACLs, e mantém a origem com o nome `.disco-livre-backup-...`. No caminho original fica um link para o destino. **O backup continua ocupando espaço:** revise a cópia antes de remover o backup manualmente. O Disco Livre não o apaga.

Pastas em uso, arquivos especiais, diferenças de conteúdo e metadados alterados durante a operação causam recusa ou restauração da origem. Pastas sincronizadas por FileProvider podem mudar enquanto são copiadas e ser recusadas. Feche os aplicativos e aguarde a sincronização. Não mova uma máquina virtual em execução.

## Atualizar

`disco-livre atualizar` mostra instruções; o botão do app abre as releases do fork para revisão. Nenhum deles baixa e executa código remoto. Revise e instale outro checkout limpo pelo SHA completo, como na instalação inicial.

## Testar e compilar

```sh
python3 -m unittest discover -s tests -v
zsh -n bin/disco-livre
swiftc -typecheck -swift-version 5 -parse-as-library app/DiscoLivre.swift
./app/build.sh
```

Os testes usam pastas temporárias dedicadas em HOME, fora de Documentos/FileProvider, sem reatribuir HOME. Nenhum instalador real, serviço, Finder ou dado pessoal é usado. Para provar as regressões na versão original, `DISCO_LIVRE_TEST_SOURCE` pode apontar para o CLI imutável da auditoria.

```sh
DISCO_LIVRE_SIMULAR=1 disco-livre vigiar
```

Nesse exemplo não há exclusão nem ativação de serviço. O registro fica em `~/.config/disco-livre/simulado.log`.

## Remover e créditos

`./uninstall.sh` remove CLI, app, skill, configuração e vigia, preservando o log. Não desfaz limpezas nem movimentações. Se você habilitou “Abrir ao ligar o Mac”, desligue essa opção antes de remover o app.

Projeto original e créditos: [Willian Claf / Willclaf](https://github.com/Willclaf/disco-livre). O botão de apoio incluído no aplicativo continua destinado ao autor original. As correções deste fork não representam aprovação ou publicação pelo projeto original.
