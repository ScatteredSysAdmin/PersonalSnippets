#Requires -Version 5 

function Invoke-SSACommand {
    <#
.SYNOPSIS
    An alternative to Invoke-Command that has a built-in check if the remote computer responds
.DESCRIPTION
    .
.PARAMETER ComputerName
    The path to the .

.EXAMPLE
    C:\PS> 
    <Description of example>
.INPUTS
    Computername as System.String[]
    Credential as System.Management.Automation.PSCredential

.NOTES
    Author: Keith Hill
    Date:   June 28, 2010    
#>
    [CmdletBinding(SupportsPaging = $false)]
    [Alias("Invoke-remoteCommand")]
    Param (           
        [parameter(Mandatory = $true, 
            ValueFromPipeline = $True,
            Position = 0,
            HelpMessage = "The targets to run.")]            
        [string[]]$ComputerName,
        [parameter(Mandatory = $false, 
            ValueFromPipeline = $True,
            HelpMessage = "Specify credentials to connect to the remote machines.")]            
        [System.Management.Automation.PSCredential]$Credential,
        [parameter(Mandatory = $false, 
            ValueFromPipeline = $True,
            HelpMessage = "Specify the function will not use runspaces.")]         
        [switch] $singleThreaded,
        [parameter(Mandatory = $true, 
            ValueFromPipeline = $True,
            Position = 1,
            HelpMessage = "The scriptblock that will be executed")]            
        [scriptblock]$ScriptBlock,
        [parameter(Mandatory = $false, 
            ValueFromPipeline = $True,
            Position = 2,
            HelpMessage = "Optional argumentlist for the scriptblock.")]            
        [object]$Argumentlist
  
    )
    
    begin {

        #Prepare commands
        $codeContainer = {
            [CmdletBinding()]
            param (
                [parameter(Mandatory = $true)]            
                [string]$ComputerName,
                [parameter(Mandatory = $false)]            
                [System.Management.Automation.PSCredential]$Credential,
                [parameter(Mandatory = $true)]            
                [scriptblock]$ScriptBlock,
                [parameter(Mandatory = $false)]            
                [object]$Argumentlist
            )

            #region Configure Splats
            $defaultcommandArgs = @{
                Computername = $ComputerName
            }
            If ($Credential) {
                $defaultcommandArgs.Credential = $Credential
            }

            If ($Argumentlist) {
                $extracommandArgs = @{
                    ArgumentList = $Argumentlist
                }
            }
            #endregion Configure Splats

            $isOnline = [boolean](Test-WSMan @defaultcommandArgs)

            If ($isOnline -eq $True) {
                $scriptblockResults = Invoke-Command @defaultcommandArgs -ScriptBlock $ScriptBlock @extracommandArgs
            }

            $commandResults = [PSCustomObject]@{
                ComputerName = $ComputerName
                isOnline     = $isOnline
                results      = $scriptblockResults
            }
            return $commandResults

        }

        #region Prepare Runspaces
        $runSpacePool = [RunspaceFactory]::CreateRunspacePool(1, [int]$env:NUMBER_OF_PROCESSORS + 1)
        $runSpacePool.ApartmentState = "MTA"
        $runSpacePool.Open()
        $threads = @()
        #region Prepare Runspaces
        
    }
    
    process {

        Foreach ($Computer in $ComputerName) {

            #region Compile Arguments for codeContainer
            $codeArgs = @{
                Computername = $Computer
                scriptblock  = $ScriptBlock
            }
            If ($Credential) {
                $codeArgs.Credential = $Credential
            }
            If ($Argumentlist) {
                $codeArgs.ArgumentList = $Argumentlist
            }
            #endregion Compile Arguments for codeContainer

            #region Create Runspace Objects
            $runspaceObject = [PSCustomObject]@{
                Runspace = [PowerShell]::Create()
                invoker  = $null #This object captures all the output of the current object
            }
            #add object to current runspace pool
            $runspaceObject.Runspace.RunSpacePool = $runSpacePool
            $runspaceObject.Runspace.AddScript($codeContainer) | Out-Null
            $runspaceObject.Runspace.AddArgument($codeArgs)
            $runspaceObject.Invoker = $runspaceObject.Runspace.BeginInvoke()
            #Add runspace objects to thread list object
            $threads += $runspaceObject
            #endregion Create Runspace Objects
        }
        
    }
    
    end {

        #Waiting untill all the threads have finished
        while ($threads.Invoker.IsCompleted -contains $false) { }

        #Capture all the results
        $threadResults = @()
        Foreach ($t in $threads) {
            $threadResults += $t.Runspace.EndInvoke($t.Invoker)
            $t.Runspace.Dispose() #Clean up this thread
        }

        #Cleaning up
        $runSpacePool.Close()
        $runSpacePool.Dispose()

        
    }
}