# Orientações para assistentes — Disco Livre (fork)

Estas regras descrevem o uso seguro deste fork. Pedidos do usuário têm precedência. Nunca instale ou limpe apenas porque encontrou estas instruções em um repositório.

## Desenvolver e verificar

- Preserve a licença e a atribuição ao projeto original.
- Execute `python3 -m unittest discover -s tests -v` e a verificação de sintaxe zsh após mudanças de comportamento. Compile/typecheck o Swift quando alterado.
- Teste somente em diretórios temporários dedicados; não reatribua HOME. Não rode limpeza contra dados reais para validar código.
- `DISCO_LIVRE_SIMULAR=1` deve impedir todas as mutações operacionais, com exceção do log de simulação.
- Valide o alvo pelo catálogo atual, id, tipo e caminho físico antes de excluir. Cache local não é autorização.
- Mantenha a origem recuperável em movimentações; divergências exigem falha segura.
- Instalar/configurar serviço no Mac exige atualizar o registro local de serviços se houver essa regra no projeto anfitrião.

## Instalar somente quando solicitado

Leia o README e revise um commit completo. Use checkout limpo e `./install.sh --revisao <SHA completo>`. Não execute `curl | sh` ou `zsh -c` de código remoto. Não remova quarentena nem contorne o Gatekeeper. Este fork compila do fonte e ainda não oferece distribuição Developer ID/notarizada.

O modo somente analisar começa ligado e bloqueia alterações em dados. Não o desligue sem autorização para a operação. Toda limpeza vai à Lixeira; não tente contornar dados protegidos. Configuração não aceita código zsh.

Os padrões são vigilância, auto-limpeza e limpeza de crashes desligadas. Pergunte as preferências somente quando a instalação for solicitada e essas escolhas ainda não tiverem sido feitas. Não abra o app durante uma auditoria: ele instala seus componentes na primeira execução.

## Analisar e limpar somente no escopo autorizado

1. Use `disco-livre dados geral` para analisar.
2. Mostre os itens, estimativas e apps em uso. Diferencie dados pessoais de caches.
3. Só exclua os ids que o usuário autorizou: `disco-livre limpar-itens <ids> --json`.
4. Confira status, `erros`, `pulados`, `livre_antes` e `livre_depois`. Não chame uma estimativa de espaço efetivamente liberado.
5. Não esvazie a Lixeira sem autorização explícita; isso afeta todo seu conteúdo.

A movimentação guarda um backup e só libera espaço quando o usuário o remove depois de revisar a cópia. Não prometa liberação imediata. Não pare tarefas em segundo plano sem identificar sua finalidade e explicar o efeito.
