# LogTool Issues Registry

## [DONE] — Implemented Issues

### ⚡ AUD-PERF-02: Renderização via Streaming

- **Status:** Integrated v28.1.3
- **Description:** Substituição de `StringBuilder` por `StreamWriter` para geração de relatórios.
- **Impact:** Suporte a relatórios de escala empresarial (100k+ eventos) com consumo estável de RAM.

### 📊 AUD-OBS-01: Rotação de Logs Internos

- **Status:** Integrated v28.1.2
- **Description:** Implementada política de rotação automática (10MB) para o arquivo `events.jsonl`.
- **Impact:** Estabilidade de armazenamento em execuções de longa duração.

### ⏳ AUD-RES-01: Resiliência em I/O de Compressão

- **Status:** Integrated v28.1.1
- **Description:** Implementado timeout explícito (60s) via Background Jobs para arquivamento.
- **Impact:** Eliminação de deadlocks síncronos por contenção de recursos.

### 🧹 AUD-PURGE-01: Higiene de Código L0/L1

- **Status:** Integrated v28.1.0
- **Description:** Expurgo total de tags legadas e comentários redundantes.

---

## [OPEN] — Pending Issues

### 🧪 AUD-TEST-01: Expansão de Testes de Stress

- **Priority:** Low
- **Description:** Criar bateria de testes Pester para validar o limite térmico de processamento do motor de análise.
