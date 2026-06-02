# Changelog

All notable changes to LogTool are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

## [28.2.0] — 2026-06-02

### Security (Audit Sprint — CRITICAL Fixes)

- **[CRITICAL FIX — ISSUE-001]** All localized strings in `Invoke-HtmlReport` are now sanitized via `HtmlEncode()`. Prevents XSS injection through config-controlled i18n values.
- **[HIGH FIX — ISSUE-002]** SHA-256 hash comparison in `Assert-ArchiveIntegrity` now uses constant-time byte-level XOR comparison. Eliminates timing oracle attack vector.
- **[HIGH FIX — ISSUE-003]** Config-driven `KeywordsToFlag` are now escaped via `[regex]::Escape()` before joining into regex pattern. Prevents ReDoS from malicious config values.
- **[MEDIUM FIX — ISSUE-004]** Archive names now use millisecond resolution + 8-char GUID suffix (`HH-mm-ss-fff_XXXXXXXX`) to prevent race condition on concurrent collection.
- **[MEDIUM FIX — ISSUE-008]** `Initialize-SystemEnvironment` now purges rogue root `config.psd1` BEFORE any module can import it, closing the config injection window.

### Supply Chain (M17)

- **[FIX — ISSUE-005/006]** All GitHub Actions in `security.yml` pinned by full commit SHA instead of mutable tags: `actions/checkout`, `actions/upload-artifact`, `gitleaks/gitleaks-action`, `anchore/sbom-action`.

### Observability (M22)

- **[NEW — ISSUE-009]** `Write-AuditLog` now includes `correlation_id` (per-session GUID), `hostname`, and `PID` in every log entry for forensic traceability.
- **[NEW — ISSUE-010]** Audit log `audit.jsonl` now auto-rotates at 10MB threshold to prevent unbounded growth.
- **[FIX — ISSUE-011]** `Initialize-SystemEnvironment` auto-creates `core/logs/` directory to prevent silent `Write-AuditLog` failures.

### Resilience

- **[NEW]** Zip Bomb protection: archives with uncompressed size exceeding 500MB are rejected before extraction with a `SECURITY VIOLATION` error.

### Quality

- **[FIX — ISSUE-013]** `AnalyzingArchive` key in `en-US` dictionary corrected from Portuguese to English.
- **[FIX — ISSUE-014]** Added missing `DeletingOldByAge` key to both `en-US` and `pt-BR` i18n dictionaries.
- **[EXPANDED — ISSUE-017]** Test suite expanded from 4 to 10 test cases. New tests: XSS encoding validation, SHA-256 integrity failure, path traversal rejection, archive name uniqueness, i18n key parity.

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

### Security (Hardening and Audit compliance)

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
