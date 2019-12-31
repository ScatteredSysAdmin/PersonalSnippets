#Requires -Version 5 

function Invoke-SSACommand {
    <#
    .SYNOPSIS
    An alternative to Invoke-Command that has a built-in pre-check if the remote computer accepts WS-MAN
    .DESCRIPTION
    Invoke-SSACommand will run a scriptblock multithreaded on all online computernames that you specify.
    It was build to be able to run commands remotely without the need of first checking if we can connect to it.
    .PARAMETER ComputerName
    Name or names of the nodes to connect to
    .PARAMETER ScriptBlock
    The scriptblock that should be executed on the nodes
    .PARAMETER Argumentlist
    The arguments that should be passed on to the scriptblock
    -> no support for named parameters at this moment
    .PARAMETER Credential
    Optional: specify credentials to be used on all the targeted nodes
    .EXAMPLE
    PS C:\> Invoke-SSACommand -ComputerName localhost -ScriptBlock { get-process } 
    
    Connect to machine localhost using default credentials and return all processes

    .EXAMPLE
    PS C:\> Invoke-SSACommand -ComputerName localhost,127.0.0.1,$ENV:Computername -ScriptBlock { param($proc) get-process $proc } -Credential $cred -Argumentlist "svchost"

    Connect to 3 machine using specified credentials and run a scriptblock that accepts a parameter


    .NOTES
    Author:     Ron Peeters
    Date:       December 31, 2019
    Website:    https://scatteredsysadmin.com
    CopyRight:  ?
    License:    ?
    Version:    0.9
    .LINK
        https://scatteredsysadmin.com/??

    #>
    [CmdletBinding(SupportsPaging = $false)]
    [Alias("Invoke-remoteCommand")]
    Param (           
        [Alias("Server", "ServerName", "Computer")]
        [parameter(Mandatory = $true, 
            ValueFromPipeline = $True,
            Position = 0,
            HelpMessage = "The targets to run.")]            
        [string[]]$ComputerName,
        [parameter(Mandatory = $false, 
            ValueFromPipeline = $True,
            HelpMessage = "Specify credentials to connect to the remote machines.")]            
        [System.Management.Automation.PSCredential]$Credential,
        # [parameter(Mandatory = $false, 
        #     ValueFromPipeline = $True,
        #     HelpMessage = "Specify the function will not use runspaces.")]         
        # [switch] $singleThreaded,
        [parameter(Mandatory = $true, 
            ValueFromPipeline = $True,
            Position = 1,
            HelpMessage = "The scriptblock that will be executed on the remote machine")]            
        [scriptblock]$ScriptBlock,
        [parameter(Mandatory = $false, 
            ValueFromPipeline = $True,
            Position = 2,
            HelpMessage = "Optional argumentlist for the scriptblock.")]            
        [object[]]$Argumentlist
  
    )
    
    begin {


        #region HelperFunctions

        #Creating Write-PSFMessage if it does not exist...
        If (-NOT (Get-Command -Name Write-PSFMessage -ErrorAction SilentlyContinue)) {
            #start Write-PSFMessage
            Write-Warning -Message "Unable to use Write-PSFMessage. :-("
            Write-Warning -Message "Module PSFramework not found. You really should try it!"
            Write-Warning -Message "Visit https://psframework.org for more info!"
            Write-Output " "
            Write-Output " "

            Function private:Write-PSFMessage {
                [CmdletBinding()]
                param (
                    [parameter(Mandatory = $true)]          
                    [string]$Message,
                    [parameter(Mandatory = $false)]
                    [ValidateSet('Critical', 'Output', 'Verbose', 'Debug', 'Warning')]
                    [string]$Level
                )

                switch ($Level) {
                    'Critical' { Write-Error -Message $Message }
                    'Output' { Write-Output $Message }
                    'Verbose' { Write-Verbose -Message $Message }
                    'Debug' { Write-Debug $Message }
                    'Warning' { Write-Warning -Message $Message }
                    Default { Write-Output $Message }
                }

            }
        } #end Write-PSFMessage
        #endregion HelperFunctions

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
                [object[]]$Argumentlist
            )

            #region Configure Splats
            $defaultcommandArgs = @{
                Computername = $ComputerName
            }
            If ($Credential) {
                $defaultcommandArgs.Credential = $Credential
                $defaultcommandArgs.Authentication = 'Default' #Maybe this needs improvement
            }
            If ($Argumentlist) {
                $extracommandArgs = @{
                    ArgumentList = $Argumentlist
                } 
            }
            Else {
                $extracommandArgs = @{ }
            }
            #endregion Configure Splats

            #Checking if the computer is reachable for invoke-command
            $isOnline = [boolean](Test-WSMan @defaultcommandArgs)

            If ($isOnline -eq $True) {
                #It is reachable, lets Rock!
                Try {
                    $scriptblockResults = Invoke-Command @defaultcommandArgs -ScriptBlock $ScriptBlock -ErrorAction Stop @extracommandArgs
                    $Errored = $False
                }
                Catch {
                    $scriptblockResults = $_
                    Write-Error $_
                    $Errored = $true
                }
            }
            else {
                #Computer is offline, lets put that in the feedback
                $scriptblockResults = 'Offline'
                $Errored = $False
            }

            #Gather all the results in a object
            $commandResults = [PSCustomObject]@{
                ComputerName  = $ComputerName
                isOnline      = $isOnline
                scriptblock   = $ScriptBlock
                results       = $scriptblockResults
                ErrorOccurred = $Errored
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

            Write-PSFMessage -Level Output -Message "Processing $Computer"

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

            Write-PSFMessage -Level Verbose -Message "Preparing runspace object"
            #region Create Runspace Objects
            $runspaceObject = [PSCustomObject]@{
                Runspace = [PowerShell]::Create()
                invoker  = $null #This object captures all the output of the current object
            }
            #add object to current runspace pool
            $runspaceObject.Runspace.RunSpacePool = $runSpacePool
            Write-PSFMessage -Level Verbose -Message "Adding codeContainer to runspace object"
            [void]$runspaceObject.Runspace.AddScript($codeContainer)
            #$runspaceObject.Runspace.AddParameter($codeArgs)
            Foreach ($codeArgKey in $CodeArgs.Keys) {
                Write-PSFMessage -Level Verbose -Message "Adding parameter $($codeArgKey) to runspace object"
                [void]$runspaceObject.Runspace.AddParameter($codeArgKey, $codeArgs[$codeArgKey])
            }
            #$runspaceObject.Runspace.AddParameter("Computername", $Computer)
            #$runspaceObject.Runspace.AddParameter("Scriptblock", $ScriptBlock)
            Write-PSFMessage -Level Verbose -Message "Starting runspace object"
            $runspaceObject.Invoker = $runspaceObject.Runspace.BeginInvoke()
            #Add runspace objects to thread list object
            $threads += $runspaceObject
            #endregion Create Runspace Objects
        }
        
    }
    
    end {

        #Waiting untill all the threads have finished
        Write-PSFMessage -Level Output -Message "Waiting untill runspaces are all finished"
        while ($threads.Invoker.IsCompleted -contains $false) { }

        #Capture all the results
        Write-PSFMessage -Level Verbose -Message "Fetching results from runspace threads"
        $threadResults = @()
        Foreach ($t in $threads) {
            $threadResults += $t.Runspace.EndInvoke($t.Invoker)
            $t.Runspace.Dispose() #Clean up this thread
        }

        #Cleaning up
        Write-PSFMessage -Level Verbose -Message "Cleaning up all the runspace remnants"
        $runSpacePool.Close()
        $runSpacePool.Dispose()

        return $threadResults
    }
}