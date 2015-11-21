workflow Install-ADK8_1
{
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$VMName,
		[Parameter(Mandatory=$true)]
		[PSCredential] $VMCredential,
        [Parameter(Mandatory=$true,HelpMessage="Default is datadisk on d:\Source")]
        [string]$SourceFilesParentDir
    )    
    
    inlinescript {
        $SourceFilesParentDir = $using:SourceFilesParentDir
                        
        try {
            Write-Verbose "Starting ADK8.1 installation"
            if (Test-Path "$SourceFilesParentDir\ADK\ADK8.1\adksetup.exe") {
                $ADK81UnattendArg = @("/Features","OptionId.DeploymentTools","OptionId.WindowsPreinstallationEnvironment","OptionId.UserStateMigrationTool","/norestart","/quiet","/ceip","off")
                # Call adksetup.exe with arguments for unattended installation
                & "$SourceFilesParentDir\ADK\ADK8.1\adksetup.exe" $ADK81UnattendArg
                # Verify ADK8.1 installation
                if (($LASTEXITCODE = '0') -or ($LASTEXITCODE = '3010')) {
                    Write-Output "ADK8.1 installed successfully"
                }
                else {
                    Write-Error "ADK 8.1 Installation failed"
                    Throw "ADK8.1 installation failed"
                }
            }
            else {
                Write-Error "Could not find $SourceFilesParentDir\ADK\ADK8.1\adksetup.exe , unable to install ADK8.1"
                Throw "Unable to locate ADK8.1 adksetup.exe"
            }
        }
        catch {
            Write-Verbose "Failed to install ADK8.1"
            Write-Error $_.Exception
        }
    } -PSComputerName $VMName -PSCredential $VMCredential
}