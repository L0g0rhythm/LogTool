# 🛡️ LogTool - Professional Log Analysis Toolkit

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey.svg)

**LogTool is an advanced toolkit, developed in PowerShell, for the collection, analysis, and reporting of Windows Event Logs, with a focus on security and efficiency.**

Created for system administrators, security analysts, and power users, LogTool transforms the reactive task of digging through logs into a proactive, intelligent analysis. It allows you to quickly identify the root causes of instability, application crashes, or suspicious activities on your system.

## ✨ Key Features

- **⚙️ Configurable Collection Engine**: Easily define which event logs to collect, the maximum number of events, and apply specific filters by ID, Level, or Provider through a single `config.psd1` file.
- **🧠 Intelligent Dual-Verdict Analysis**: The engine not only scans for critical Event IDs but also for suspicious keywords, providing two independent verdicts on the system's health.
- **📊 Interactive HTML Reports**: Generate professional HTML reports with dynamic tables that allow real-time event filtering and expandable message details, making root-cause analysis faster than ever.
- **🔒 Security-First Architecture**: Built with a proactive security mindset, featuring Path Traversal prevention, Output Encoding to mitigate XSS, and ACL Hardening on the generated log archives.
- **♻️ Automated Lifecycle Management**: Includes an integrated cleanup system that automatically deletes old log archives based on age or quantity, helping to manage disk space.
- **⚡ Performance-Optimized Code**: Utilizes high-performance data structures like `HashSet`, `StringBuilder`, and pipeline processing to minimize memory consumption and maximize speed.
- **🚀 Smart Command-Line Interface**: Interact with the tool via a simple launcher (`lt.ps1`) with intuitive commands (`collect`, `analyze`, `create-report`) that translate user intent into powerful engine operations.
- **✍️ Robust Error Handling & Auditing**: All critical operations are wrapped in `try/catch` blocks to ensure graceful failure, and all actions are logged to an audit file for full traceability.
- **🌐 Internationalization (i18n) Support**: The UI and reports are translatable, with a localization engine that supports multiple languages out-of-the-box (EN/PT-BR).
- **📦 Zero External Dependencies**: Runs natively on any modern Windows system with PowerShell, requiring no external modules or libraries.

## 🚀 Getting Started

### Prerequisites

1. **Windows Operating System**
2. **PowerShell 5.1** or higher
3. **Administrator Privileges** (required to access system event logs)

### Installation

To get started, clone the repository to a local directory on your machine.

```bash
git clone https://github.com/L0g0rhythm/LogTool.git
cd LogTool
```

## 🛠️ Usage

All commands are executed via the smart launcher `lt.ps1` from within a PowerShell terminal running as **Administrator**.

### 1. Collect Logs

This is the first and most fundamental step. The `collect` command gathers event logs based on the rules in `config.psd1` and securely packages them into a `.zip` archive inside the `reports` directory.

```powershell
.\lt.ps1 collect
```

### 2. Analyze an Archive (Console)

After collecting logs, you can analyze them. This command provides an interactive list of available archives and displays a diagnostic summary directly in the console.

```powershell
.\lt.ps1 analyze
```

The tool will prompt you to select which archive to analyze.

### 3. Create an HTML Report

For a more detailed and shareable analysis, generate an interactive HTML report.

**Option A: Report from the latest archive**

```powershell
.\lt.ps1 create-report
```

**Option B: Report from a specific archive**

```powershell
.\lt.ps1 create-report-from -Path ".\reports\...\archive.zip"
```

An HTML file will be generated in the same directory as the source archive.

### 4. Advanced Filtering

You can refine your analysis on the fly with additional parameters:

- `IncludeEventId`: Adds specific Event IDs to the critical analysis.
- `Keyword`: Scans for a custom keyword in event messages.

**Example:**

Analyze the latest archive, but also flag Event ID 5156 and search for the word "firewall".

```powershell
.\lt.ps1 analyze -IncludeEventId 5156 -Keyword "firewall"
```

## 🔧 Configuration

The entire behavior of the LogTool is controlled by the `config.psd1` file. It allows you to customize:

- **ToolSettings**: Set the language for the UI and reports (`en-US` or `pt-BR`).
- **CollectionTasks**: Define which logs to collect (Security, Application, etc.), how many events, and apply specific filters.
- **AnalysisConfig**: Specify which Event IDs are considered "critical" and which keywords should trigger an alert.
- **LifecycleConfig**: Configure the automatic cleanup of old archives.

## 🤝 Contributing

Contributions are welcome! If you find a bug or have a suggestion for a new feature, please open an issue or submit a pull request.

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.
