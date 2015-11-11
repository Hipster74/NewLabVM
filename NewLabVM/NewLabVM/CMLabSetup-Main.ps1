
$Params = @{"Sourcefile"='C:\MDTBuildLab\Captures\REFWS2012R2-001.wim';"VMName"='LabADSrv';"VMLocation"='c:\VMs';"VMMemory"="2048";"IPAddress"='10.96.130.120';"DifforCreate"="CREATE";"VMType"="UEFI";"DomainOrWorkGroup"="WORKGROUP"}

$NewLabSrvjob = New-LabSrv $Params
