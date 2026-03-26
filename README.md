# 🛡️ LogTool - Professional Log Analysis Toolkit

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey.svg)

**LogTool is a high-performance PowerShell toolkit for the collection, analysis, and reporting of Windows Event Logs. Engineered for security and efficiency, the system utilizes a Single Responsibility architecture and O(n) algorithmic optimizations for processing log data in enterprise environments.**

LogTool converts raw event data into structured diagnostics for system administrators and security analysts. The current version implements a modular architecture, streaming I/O reporting, and absolute path confinement for secure operations.

- **🛡️ Security Hardened**: Verified against security vulnerabilities.
- **🚀 Ultra-Scale Performance**: Streaming I/O engine for HTML reports ($O(n)$ memory efficiency).
- **💪 Industrial Resilience**: Archive operations isolated in background jobs with safety timeouts.
- **🧠 Linear Logic**: Analysis operations optimized for linear temporal complexity.
- **🔒 Path Confinement**: Zero-Trust I/O with SHA-256 integrity validation and Regex escaping.
- **📊 Audit Logging**: Internal execution logs with automated rotation filters.

## 🚀 Getting Started

### Prerequisites

1. **Windows PowerShell 5.1** or higher.
2. **Administrator Privileges** (required for event log access).

### Installation

```bash
git clone https://github.com/L0g0rhythm/LogTool.git
cd LogTool
```

## 🛠️ Usage

All commands are executed via the smart launcher `lt.ps1` as **Administrator**.

### 1. Collect Logs

```powershell
.\lt.ps1 collect
```

### 2. Analyze (Console)

```powershell
.\lt.ps1 analyze
```

### 3. Create HTML Report

```powershell
.\lt.ps1 create-report
```

## 🔧 Configuration

Controlled by `config.psd1`. Customize logs, critical Event IDs, suspicious keywords, and maintenance cycles.

## 🛡️ Framework Integrity

LogTool implements several safety and performance benchmarks to ensure enterprise-grade stability:

- **Security**: Verified path confinement and Regex sanitization.
- **Data Integrity**: SHA-256 manifest validation for log archives.
- **Efficiency**: O(n) complexity enforcement across all analysis modules.
- **Modularity**: Strict Domain Isolation (SRP) between Shared, Backend, and Frontend layers.

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.
