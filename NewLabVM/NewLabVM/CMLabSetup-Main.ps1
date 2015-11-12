.\New-LabSrv.ps1 -SourceFile 'C:\MDTBuildLab\Captures\REFWS2012R2-001.wim' -VMName 'LabADSrv' -VMLocation 'd:\VMs' -VMMemory "2048" -IPAddress '10.96.130.120' -DifforCreate "CREATE" -VMType "UEFI" -DomainOrWorkGroup 'WORKGROUP'

# Configure Active Directory on new server


Write-output "klar med nested"
