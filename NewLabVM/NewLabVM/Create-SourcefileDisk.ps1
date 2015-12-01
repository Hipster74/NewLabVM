Workflow Create-SourcefileDisk {
	param(
		[Parameter(Mandatory=$True)]
		[string] $VMName,
		[Parameter(Mandatory=$true)]
		[PSCredential] $VMCredential,
		[parameter(mandatory=$True)]
		[string]$SourcefilesDir,
		[parameter(mandatory=$True)]
		[int]$DiskSizeInGB
	)
	Inlinescript {
		$VMName = $using:VMName
		$SourcefilesDir = $using:SourcefilesDir
		$DiskSizeInGB = $using:DiskSizeInGB
		$DiskSizeInBytes = $DiskSizeInGB *1024*1024*1024

		# VHDfunctions from http://www.padisetty.com/2013/11/creating-data-vhd-using-powershell.html
		function CreateVHD ($VHDPath, $Size) {
			$Drive = (New-VHD -path $VHDPath -SizeBytes $Size -Dynamic | `
			Mount-VHD -Passthru | `
			Get-Disk -number {$_.DiskNumber} | `
			Initialize-Disk -PartitionStyle MBR -PassThru | `
			New-Partition -UseMaximumSize -AssignDriveLetter:$false -MbrType IFS | `
			Format-Volume -Confirm:$false -FileSystem NTFS -NewFileSystemLabel 'Data' -Force | `
			Get-Partition | `
			Add-PartitionAccessPath -AssignDriveLetter -PassThru | `
			get-volume).DriveLetter

			Dismount-VHD $VHDPath
		}
		function MountVHD ($VHDPath) {
			Mount-VHD $VHDPath
			$Drive = (Get-DiskImage -ImagePath $VHDPath | `
			Get-Disk | `
			Get-Partition).DriveLetter
			"$($Drive):\"
			Get-PSDrive | Out-Null # Work around. some times the drive is not mounted
		}
  
		function DismountVHD ($VHDPath) {
			Dismount-VHD $VHDPath
		}
	
		# Main
		# Get path to VM harddrives
		Write-Verbose "Getting path to $VMName harddrives"
		$VM = Get-VM -Name $VMName
		$VMDiskLocation = $VM.HardDrives.path | Split-Path
		Write-Verbose "Path to $VMName VHDdisk is $VMDiskLocation"
		# Create a VHDX file
		Write-Verbose "Creating $VMDiskLocation\$VMName-DataDisk.vhdx"
		CreateVHD -VHDPath "$VMDiskLocation\$VMName-DataDisk.vhdx" -Size $DiskSizeInBytes
 
		# Mount the VHD, copy data to it and finally dismount it
		Write-Verbose "Mounting VHDx and copy data from $SourcefilesDir to it"
		$VHDXPath = MountVHD -VHDPath "$VMDiskLocation\$VMName-DataDisk.vhdx"
 
		# This will create a timestamp like yyyy-mm-yy
		$TimeStamp = Get-Date -uformat "%Y-%m%-%d"
		$RoboCopyParams = @("$SourcefilesDir","$VHDXPath\Source","/MIR","/LOG+:$env:SystemRoot\Temp\SourcefilesRobocopy-$TimeStamp.log","/R:3","/W:30")
		Write-Verbose "Copying sourcefiles to VHDx with robocopy params $RoboCopyParams"
		& Robocopy $RoboCopyParams
		Write-Verbose "Robocopy operation exitcode is $LASTEXITCODE, more info can be found in logfile $env:SystemRoot\Temp\SourcefilesRobocopy-$TimeStamp.log"
 
		DismountVHD -VHDPath "$VMDiskLocation\$VMName-DataDisk.vhdx"

		#Attach Disk to vm
		Add-VMHardDiskDrive -VM $VM -Path "$VMDiskLocation\$VMName-DataDisk.vhdx" -ControllerType SCSI
	}
	
	Inlinescript {
		Write-Verbose "Remotely connected to $env:COMPUTERNAME" -Verbose
		Write-Verbose "Setting disk in online mode and disables readonly" -Verbose
		Get-Disk | Where {$_.OperationalStatus -eq 'offline'} | Set-Disk -IsReadOnly:$false
		Get-Disk | Where {$_.OperationalStatus -eq 'offline'} | Set-Disk -IsOffline:$false 
	
	} -PSComputerName $VMName -PSCredential $VMCredential
}