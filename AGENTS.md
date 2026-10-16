# AGENTS.md — instruções para assistentes de IA

Você é um assistente de IA (Claude Code, Codex, Cursor etc.) e a pessoa pediu pra instalar ou usar o **disco-livre**. Siga este guia. A pessoa provavelmente **não é técnica**: fale em português simples e explique cada pedido de permissão antes de fazer.

## O que é

- `bin/disco-livre`: ferramenta de terminal (zsh puro, sem dependências) que analisa o disco, limpa lixo seguro e vigia o espaço livre.
- `app/`: app da barra de menus "Disco Livre" (SwiftUI). O instalador baixa o app pronto da release (conferido por SHA-256); se não der, compila com `swiftc`.
- `skill/disco-livre/SKILL.md`: skill pro Claude Code / Codex usar a ferramenta.
- `instalar.sh` (instalação em uma linha, sem git), `install.sh` / `uninstall.sh`: instalação e remoção.

Só funciona em **macOS 13 ou mais novo** (Intel ou Apple Silicon).

## Instalar (passo a passo)

O objetivo é que a pessoa termine **impressionada**: instalou e já viu quantos GB escondidos o Mac tinha. Não pule a análise geral (passo 4).

1. **Confirme que é um Mac com macOS 13+:** `sw_vers -productVersion`. Se não for Mac, avise que o Disco Livre é só pra macOS e pare.

2. **Pergunte à pessoa** (uma pergunta só, com os padrões sugeridos):
   - Quantos GB livres ela quer manter no mínimo (padrão **30**)
   - Se quer a vigilância automática (padrão **sim**)
   - Se quer que ele limpe o lixo seguro sozinho quando passar da meta (padrão **não**)

3. **Instale sem perguntas interativas.** Não precisa de git nem das ferramentas da Apple: o app vem pronto e é conferido por SHA-256.
   ```bash
   zsh -c "$(curl -fsSL https://raw.githubusercontent.com/Willclaf/disco-livre/main/instalar.sh)" -- --sim --meta 30 --vigia sim --auto-limpeza nao
   ```
   (troque os valores pelo que a pessoa escolheu. Se o repositório já estiver clonado, dá no mesmo: `./install.sh --sim --meta 30 ...`)

   O instalador:
   - copia a ferramenta pra `~/.local/bin/disco-livre` e libera o comando no `~/.zshrc`
   - copia a skill pra `~/.claude/skills/` e `~/.codex/skills/` (se essas pastas existirem)
   - salva a configuração e liga a vigilância (LaunchAgent `com.disco-livre.vigia`, a cada 3 h)
   - instala `/Applications/Disco Livre.app` (baixa pronto; se não der, compila; se nada der, segue só com o terminal)
   - com `--sim`, **não abre o app**: é você que conduz a análise geral

4. **Análise geral (a primeira impressão — obrigatória):**
   ```bash
   ~/.local/bin/disco-livre dados geral
   ```
   Devolve JSON: `{"livre": KB, "itens": [{"id","nivel","kb","quem","desc","nota","lixeira"}]}` (`kb` em KB; 1 GB ≈ 976 562 KB).
   - Mostre à pessoa uma **tabela** com o total encontrado em destaque ("Encontrei **26,4 GB** que dá pra liberar"), separada em:
     - **Seguro** (`nivel: "seguro"`) — se recria sozinho; sugira limpar todos.
     - **Revise** (`nivel: "revisar"`) — é da pessoa; explique a `nota` de cada um; só entra se ela pedir.
   - Itens com `quem` preenchido estão em uso: peça pra pessoa **fechar aquele app** (ex.: "feche o Google Chrome") e rode `dados geral` de novo depois.
   - Pergunte **quais limpar** e espere a resposta. Nunca limpe sem o "sim" dela.
   - Limpe só os escolhidos:
     ```bash
     ~/.local/bin/disco-livre limpar-itens <id> <id> ... --json
     ```
     Devolve `{"liberado_kb","lixeira_kb","itens","livre_antes","livre_depois","pulados":[{"desc","quem"}]}`.
   - Comemore com o número real: "🎉 Você liberou **X GB** que estavam escondidos. Antes: A livres → agora: B livres."
   - Se `lixeira_kb > 0`: explique que esses arquivos foram pra **Lixeira** (dá pra recuperar) e ainda ocupam espaço. Pergunte se pode esvaziar. Só com o "sim": `~/.local/bin/disco-livre esvaziar-lixeira --sim` (o macOS pode pedir permissão pra controlar o Finder: é pra esvaziar a Lixeira).
   - Se a pessoa não quiser limpar nada agora: `~/.local/bin/disco-livre geral --pular` (o app não pergunta de novo).

5. **Abra o app:** `open -a "Disco Livre"`. Diga que o ícone de disco com os GB livres está na **barra de menus** (lá em cima, à direita) e que passar o mouse mostra o resumo.

6. **Confira se deu certo:**
   ```bash
   ~/.local/bin/disco-livre                      # espaço livre, meta e "Vigilância: ligada"
   launchctl print gui/$(id -u)/com.disco-livre.vigia | grep "last exit"   # deve ser 0
   ```

## Permissões que podem aparecer

| Quando | O que a pessoa vê | O que dizer |
|---|---|---|
| Esvaziar a Lixeira | "… quer controlar o Finder" | "É só pra esvaziar a Lixeira, pode permitir" |
| Análise geral | Talvez "… quer acessar a pasta Downloads" | "É pra achar instaladores velhos (.dmg) esquecidos" |
| Primeira notificação | "Editor de Scripts quer enviar notificações" | "É o aviso de pouco espaço, pode permitir" |
| Abrir o app | Nada (é compilado no próprio Mac, não vem da internet) | — |
| Medir pastas | Talvez "Disco Livre quer acessar dados de outros apps" | "É só pra medir o tamanho das pastas, não lê o conteúdo" |

## Usar depois de instalado

Leia `skill/disco-livre/SKILL.md`: tem o fluxo completo de análise e limpeza, as regras de segurança e casos reais.

Regras que valem sempre:
- **Nunca apague arquivos pessoais** sem um "sim" explícito pra aquele item. Prefira `disco-livre mover <pasta> <HD externo>` ou mandar pra Lixeira.
- `disco-livre limpar --executar --sim` só apaga lixo que se recria (cache, logs velhos, relatórios de crash).
- Pra parar tarefas em segundo plano, use `disco-livre pausar-tarefa <label>` (reversível). Não apague o `.plist`.

## Desinstalar

```bash
./uninstall.sh
```

Remove ferramenta, app, skill, configuração e vigilância. Não desfaz nada que já foi limpo.

## Desenvolver

- Ferramenta: `zsh -n bin/disco-livre` checa a sintaxe. `DISCO_LIVRE_DIR=/tmp/x bin/disco-livre ...` usa uma pasta de configuração separada pra testes.
- O app lê os dados com `disco-livre dados resumo` e `disco-livre dados pastas` (JSON).
- App: `app/build.sh` gera `app/build/Disco Livre.app` (universal, assinado ad-hoc). `open "app/build/Disco Livre.app" --args --mostrar` abre já com o resumo aberto; `--boas-vindas` abre a análise geral.
- **Testes sem apagar nada:** `DISCO_LIVRE_SIMULAR=1` faz a ferramenta executar tudo, menos apagar (registra em `$DISCO_LIVRE_DIR/simulado.log`). Use sempre isso ao testar limpeza numa máquina real.
- **Nova versão:** suba `VERSAO` em `bin/disco-livre`, rode `app/build.sh`, gere o zip (`ditto -c -k --keepParent "app/build/Disco Livre.app" app/build/DiscoLivre.zip`), grave o SHA-256 em `app/DiscoLivre.zip.sha256` e publique o zip na release `v<VERSAO>`.
