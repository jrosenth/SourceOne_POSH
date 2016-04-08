try {
     
    import-module SourceOne-POSH -DisableNameChecking -ErrorAction Continue -ErrorVariable importError

    if ($importError)
    {
    Write-Host "Load failed"
    }

}

catch {

    Write-host "Caught it"

}