@{
    # Archival Lifecycle Policy
    LifecycleConfig = @{
        Enabled            = $true
        MaxArchiveAgeDays  = 30
        MaxArchivesToKeep  = 50
    }

    # Acquisition Parameters
    CollectionTasks = @(
        @{ LogName = "System";  MaxEvents = 1000; Filter = @{ Level = 1,2 } }
        @{ LogName = "Application"; MaxEvents = 1000; Filter = @{ Level = 1,2 } }
    )
    
    # Analysis Criteria
    AnalysisThresholds = @{
        CriticalEvents = @(41, 1074, 6005, 6006, 6008)
        Keywords       = @("fail", "error", "critical", "denied", "warning")
    }
}
