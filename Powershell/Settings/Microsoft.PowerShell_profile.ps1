# Credits to Rob Sewell and Chrissy Lemaire
function Prompt {
    #This function show loading time of each command at the prompt
    try {
        $history = Get-History -ErrorAction Ignore -Count 1
        if ($history) {
            $ts = New-TimeSpan $history.StartExecutionTime  $history.EndExecutionTime
            switch ($ts) {
                {$_.TotalMinutes -ge 1 } {
                    '[{0,5:f1} m]' -f $_.TotalMinutes | Write-Host -ForegroundColor Red -NoNewline
                }
                {$_.TotalMinutes -lt 1 -and $_.TotalSeconds -ge 1} {
                    '[{0,5:f1} s]' -f $_.TotalSeconds | Write-Host -ForegroundColor Yellow -NoNewline
                }
                default {
                    '[{0,5:f1}ms]' -f $_.Milliseconds | Write-Host -ForegroundColor Green -NoNewline
                }
            }
        } else {
            "[ PS{0}.{1} ]" -f $PSVersionTable.PSVersion.Major, $PSVersionTable.PSVersion.Minor | Write-Host -ForegroundColor Gray -NoNewline
        }
    } catch { }
    Write-Host " $($pwd.path.Split('\')[-2..-1] -join '\')" -NoNewline
    "> "
}

Function dba {
    #This function (re)loads the dbatools module in development mode with internal functions exposed
    param (
        [Parameter(Mandatory = $false)]
        [string]$targetModule = "dbatools"
    )
    Write-Host "Force reloading mdule $targetModule" -ForegroundColor Green
    $DBAModule = Get-module $targetModule
    If (!$DBAModule) {
        Import-Module $targetModule
        $DBAModule = Get-module $TargetModule
    } else {
        Write-Host "Module was already loaded." -ForegroundColor Gray
    }
    Write-Host "Found $targetModule to be $($DBAModule.Name) - $([string]$DBAModule.Version)" -ForegroundColor Green
    Write-Host "Reloading module with internal functions exposed" -ForegroundColor Gray
    If (!(Test-Path "$($DBAModule.ModuleBase)\.git" -ErrorAction SilentlyContinue)) {
        New-Item "$($DBAModule.ModuleBase)\.git" -ItemType Directory
    }
    Import-Module $DBAModule.Path -Force
    Write-Host "Done" -ForegroundColor Gray
}
