# Changelog

All notable changes to LogTool are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

## [28.1.3] — 2026-03-25

### Performance

- **[NEW — AUD-PERF-02]** Migrated HTML reporting to a Streaming I/O model using `StreamWriter`. The system now writes reports directly to disk, enabling the generation of massive datasets (100k+ lines) with stable memory consumption.

---

## [28.1.2] — 2026-03-25

### Observability

- **[NEW — AUD-OBS-01]** Integrated automatic log rotation for `events.jsonl` in `Shared.psm1`. Files exceeding 10MB are now rotated to `.old` to ensure local storage stability.

---

## [28.1.1] — 2026-03-25

### Resilience & I/O

- **[FIX — AUD-RES-01]** Implemented `Invoke-CompressedArchiveWithTimeout` in `Collection.psm1`. Archive operations now run in isolated background jobs with a 60s timeout to prevent process-level deadlocks during I/O contention.

---

## [28.0.0] — 2026-03-25

### Security (AEGIS APEX Hardening — L0/L1 Audit)

- **[CRITICAL FIX — ISSUE-001]** `Import-Clixml` deserialization now protected by SHA-256 integrity manifest. `Invoke-LogCollection` generates a `.sha256` sidecar file on every archive. `Invoke-LogAnalysis` calls `Assert-ArchiveIntegrity` before extraction — fail-closed on hash mismatch.
- **[CRITICAL FIX — ISSUE-002]** `ArchivePath` parameter now confined to the `reports/` boundary via `Assert-PathWithinBoundary`.
- **[CRITICAL FIX — ISSUE-003]** CLI-supplied `-Keyword` is now escaped with `[regex]::Escape()`. Prevents ReDoS.

### Architecture & SRP

- **[REFACTOR — ISSUE-010]** `Show-ConsoleReport` migrated from `Analysis.psm1` to `Reporting.psm1`.
- **[NEW]** `Assert-PathWithinBoundary` extracted as a reusable security helper in `Shared.psm1`.

### Operations

- **[NEW — ISSUE-013]** Pester 5.x test suite added under `tests/`.
- **[NEW — ISSUE-014]** GitHub Actions pipeline with four sequential gates.
- **[NEW — ISSUE-015]** `CHANGELOG.md` introduced.

---

## [27.0.0] — Previous Release

- Initial internationalization (i18n) engine with `en-US` / `pt-BR` support.
- HTML report `StringBuilder` optimisation.
- XSS mitigation for keyword highlight rendering.
- Path traversal protection on `OutputPath`.
