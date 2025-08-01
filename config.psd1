# ===================================================================
# Advanced Configuration File for LogTool
# ===================================================================
@{
    # -------------------------------------------------------------------
    # NEW Section 1: General Tool Settings
    # -------------------------------------------------------------------
    ToolSettings = @{
        # Set the language for the tool's output and reports.
        # Supported values: "en-US", "pt-BR"
        Language = "en-US"
    }

    # -------------------------------------------------------------------
    # Section 2: Collection Task Configuration
    # -------------------------------------------------------------------
    CollectionTasks = @(
        # Profile 1: Detailed Security Analysis
        # Collects a large number of security events, focusing on
        # account changes and logon attempts.
        @{
            LogName   = "Security"
            MaxEvents = 10000 # Collect more events from this log due to its criticality.
            Filter    = @{
                # List of high-relevance security Event IDs:
                ID = 4625, # An account failed to log on
                     4624, # An account was successfully logged on
                     4720, # A user account was created
                     4722, # A user account was enabled
                     4724, # An attempt was made to reset an account's password
                     4725, # A user account was disabled
                     4726, # A user account was deleted
                     4732  # A member was added to a security-enabled local group
            }
        },

        # Profile 2: Application Error Focus
        # Collects a smaller number of events, but focuses only on problems.
        @{
            LogName   = "Application"
            MaxEvents = 5000
            Filter    = @{
                Level = 1, 2 # Only Critical (1) and Error (2) events.
            }
        },

        # Profile 3: System Stability Monitoring
        # Focuses on shutdown events and the VSS (Volume Shadow Copy) service.
        @{
            LogName   = "System"
            MaxEvents = 5000
            Filter    = @{
                ProviderName = "EventLog", "VSS"
                ID           = 6008, 1074 # Unexpected shutdown and user-initiated shutdown/reboot
            }
        },

        # Profile 4: General PowerShell Collection
        # Collects recent PowerShell events without a specific filter.
        @{
            LogName   = "Windows PowerShell"
            MaxEvents = 2000
            Filter    = $null # Using $null means no additional filter will be applied.
        }
    )

    # -------------------------------------------------------------------
    # Section 3: Analysis Report Configuration
    # -------------------------------------------------------------------
    AnalysisConfig = @{
        # Which Event IDs should be flagged as "Notable Critical Events"?
        CriticalEventIds = @(
            4625, # Logon Failure
            4720, # Account Creation
            4726, # Account Deletion
            4732, # Member added to Admin group
            6008, # Unexpected Shutdown
            1000  # Generic Application Error (crash)
        )

        # Which keywords, if found in error messages,
        # should trigger an alert? (Case-insensitive)
        KeywordsToFlag = @(
            "failed",
            "denied",
            "exception",
            "critical",
            "corrupt",
            "vulnerability"
        )

        # Controls the number of items (e.g., Top Sources, Last Events) shown in the report details.
        MaxDetailItems = 15
    }

    # -------------------------------------------------------------------
    # Section 4: Lifecycle Management
    # -------------------------------------------------------------------
    LifecycleConfig = @{
        # Set to $true to enable automatic cleanup, $false to disable.
        Enabled           = $true

        # Archives older than this many days will be deleted.
        MaxArchiveAgeDays = 30

        # Keep only this many of the newest archives. If the total number
        # exceeds this value, the oldest ones will be deleted.
        MaxArchivesToKeep = 50
    }
}
