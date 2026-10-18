# Segurança e limites deste fork

Este fork parte da versão 1.3.2, commit `3579ed9ae61edd29b94c601d7ffd662510575cf6`, do projeto [Willclaf/disco-livre](https://github.com/Willclaf/disco-livre). As mudanças não são uma certificação do projeto original.

## Correções da auditoria

| Problema | Comportamento corrigido |
|---|---|
| Movimentação perdia links/metadados e excluía a origem | `ditto`, comparação de conteúdo por entrada, links, permissões, xattrs e ACLs; origem preservada em backup independente; rollback em divergências |
| Simulação permitia exclusões no vigia | Barreira antes de vigiar, excluir, mover, esvaziar Lixeira, instalar/desinstalar, configurar e alterar tarefas |
| Limpeza automática desligada ainda apagava crashes | Padrões desligados, migração de configuração antiga e exigência das duas opções explícitas para apagar relatórios automaticamente |
| Cache local autorizava alvos diferentes | Id, tipo e caminho são revalidados no catálogo atual; caminhos com links ou fora de HOME são recusados |
| Instalador removia quarentena e executava código remoto | Sem retirada de quarentena ou atualização remota executável; instalação exige commit completo/checkout limpo e usa `git archive` para distribuir exclusivamente seus arquivos |
| Exclusão falha podia aparecer como sucesso/GB liberados | Status de erro propagado, falhas por item em JSON e interface; contabilização pelo aumento medido no espaço livre |

A revisão independente acrescentou a recusa de movimentação quando `lsof` falha ou mostra advertências. A instalação a partir de um arquivo Git do SHA revisado também impede incluir arquivos extras locais, inclusive ignorados pelo Git, nas skills e no aplicativo.

## Verificação

`python3 -m unittest discover -s tests -v` executa os cenários de regressão com fixtures temporárias dedicadas. Os testes positivos de movimentação substituem a fronteira `lsof` por um resultado controlado; há testes separados para arquivo ocupado e falhas/advertências da ferramenta. Cópia, conteúdo, links e atributos são exercitados de fato no macOS.

As regressões principais falharam primeiro na revisão original. A suíte inclui cópia incompleta, corrupção de mesmo tamanho, alterações durante a troca, cache/id/tipo forjados, erros de exclusão, migração, bootstrap e payload remoto. O workflow `macOS safety checks` executa testes, sintaxe e build sem instalar.

## Limites conhecidos

- Sem Developer ID/notarização nesta entrega. A compilação local continua com assinatura ad hoc. Não há promessa de que o Gatekeeper aceite um binário distribuído; este fork não fornece nem baixa esses binários.
- Confirmar um SHA significa fixar uma árvore de código, não provar que esse código é benigno. Revise-o antes de instalar. O instalador em execução e o commit local continuam sendo uma fronteira de confiança.
- Não execute com `sudo`. O programa usa permissões do usuário; não amplia acesso ou desabilita proteções do macOS.
- Uma confirmação de uso por `lsof` é pontual. Outro processo pode começar a gravar depois; o backup independente é mantido para recuperação. Este programa não cria snapshots nem trava os arquivos de outros aplicativos.
- Pastas sincronizadas podem ter metadados alterados pelo FileProvider. Nesses casos, o programa deve recusar ou restaurar a origem, sem ignorar a diferença.
- O backup da movimentação permanece ocupando espaço. Não o remova sem revisar a cópia. Arquivos especiais são recusados.
- O espaço livre do APFS pode mudar por outras atividades, snapshots e operações assíncronas. `liberado_kb` representa uma diferença observada no volume; não atribui cada byte exclusivamente ao programa.
- Caches considerados regeneráveis podem exigir rede para recriação e programas podem perder desempenho temporariamente. Preserve relatórios de falhas enquanto investiga um problema.
- A configuração em `~/.config/disco-livre/config` é código zsh carregado por `source`. Não substitua esse arquivo por conteúdo não confiável.
- A validação de caminhos não cria isolamento contra outro processo malicioso com as mesmas permissões do usuário. Este programa não é uma fronteira de privilégio nem uma ferramenta para apagar árvores controladas por adversários.

Nenhum aplicativo ou serviço foi instalado no Mac do usuário para validar estas correções. Os testes não usam dados pessoais nem esvaziam a Lixeira real.
