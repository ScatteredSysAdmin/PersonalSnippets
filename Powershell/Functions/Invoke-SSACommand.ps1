#Requires -Version 5 

function Invoke-SSACommand {
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
            Position = 1,
            HelpMessage = "Specify credentials to connect to the remote machine.")]            
        [string[]]$ComputerName,
        [parameter(Mandatory = $false, 
            ValueFromPipeline = $True,
            HelpMessage = "Specify the function will not use runspaces.")]         
        [switch] $singleThreaded
  
    )
    
    begin {
        
    }
    
    process {
        
    }
    
    end {
        
    }
}