---
name: disco-livre
description: Analisa espaço no Mac com a CLI disco-livre e propõe limpezas por item, usando catálogo validado e confirmação humana.
---

# Disco Livre — análise e limpeza por item

Use somente a CLI deste fork, em um commit revisado. Se ela não estiver instalada, explique o procedimento do README; não execute instaladores remotos nem instale sem pedido do usuário.

1. Rode `disco-livre dados geral` para analisar e apresente itens, estimativas e bloqueios por app em uso. O histórico de conversas e modelos de IA são dados do usuário, não lixo presumido.
2. Peça autorização para os itens específicos, salvo se ela já estiver clara no pedido atual. Depois rode `disco-livre limpar-itens <ids autorizados> --json`.
3. Leia o código de saída, a lista `erros` e os `pulados`. Falha ou resultado ilegível não é sucesso.
4. `liberado_kb` é o aumento medido de espaço livre no volume, sujeito a outras atividades e ao APFS; `lixeira_kb` é uma estimativa do que foi para a Lixeira e continua ocupando espaço.
5. Esvaziar a Lixeira exige autorização explícita e afeta todo seu conteúdo. Não faça isso como consequência automática de uma limpeza.

`DISCO_LIVRE_SIMULAR=1` impede as mutações operacionais e registra intenções em simulado.log. Mesmo assim, valide código novo com fixtures temporárias, nunca com dados reais. Não reatribua HOME.

A vigilância começa desligada. Auto-limpeza e limpar-crash começam em nao e precisam ser habilitadas explicitamente. A limpeza de relatórios de falhas depende de ambas as opções; preserve relatórios durante investigações.

`disco-livre mover <pasta> <destino>` copia e confere conteúdo, links e metadados; preserva a origem em um backup independente. Explique que esse backup continua ocupando espaço e que o usuário deve revisar antes de removê-lo. Não mova arquivos em uso ou uma máquina virtual em execução.

Não execute código remoto para atualizar, remova quarentena ou desabilite proteções do macOS. Não pause serviços sem identificar o que fazem e ter autorização. Preserve arquivos pessoais e prefira medidas reversíveis.
