# Alterações

## 2.0.0 — 2026-10-18 (fork; sem release binária)

- Mudança de comportamento: somente analisar ligado por padrão, inclusive em instalações/atualizações; alterações exigem opt-in. Limpezas sempre enviam à Lixeira. Esvaziamento exige confirmação permanente separada.
- Proteção adicional de documentos, fotos, máquinas virtuais e backups; configuração deixa de executar código zsh.
- Caminho, motivo, tamanho, acesso ao Finder e confirmação por item; nenhuma seleção automática.
- Hardened Runtime e fluxo Developer ID/notarização com validação do ticket/Gatekeeper, dependente de certificado e credenciais locais.

## 1.4.0 — 2026-10-18 (fork; sem release binária)

### Segurança

- Vigilância e exclusões automáticas desligadas por padrão; migração exige novo opt-in para configurações antigas.
- Simulação impede mutações, inclusive mover, vigiar, esvaziar Lixeira, instalar e alterar tarefas.
- Exclusões revalidam ids, tipos e caminhos contra o catálogo atual e recusam links.
- Removida execução de scripts remotos de main e remoção de quarentena. Instalação exige SHA revisado/checkout limpo e compila o aplicativo localmente.

### Correções

- Movimentação preserva links e metadados e mantém backup recuperável da origem.
- Conteúdo e metadados são comparados antes e depois da troca; falhas restauram a origem.
- Erros de limpeza são propagados para CLI/JSON/interface; espaço liberado deixa de usar estimativas do cache.
- Controles visíveis e separados para limpeza automática e limpeza de relatórios de falhas.
- Build fora de pastas sincronizadas, com limpeza seletiva dos metadados proibidos pela assinatura e preservação da quarentena.

### Compatibilidade e migração

A movimentação não apaga mais a origem permanentemente: é preciso revisar/remover o backup manualmente para liberar espaço. A instalação requer `--revisao <SHA completo>` e o atualizador agora orienta uma revisão manual. Artefatos do upstream 1.3.2 não contêm estas correções.
