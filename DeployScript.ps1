#
# Script.ps1
#

[CmdletBinding(SupportsShouldProcess=$True)]
Param(
	[Parameter(Mandatory=$True,Position=1)][ValidateSet("deploy","info","copyFiles","start","stop","stopAndCopy")][string]$Action,
	[ValidateScript({Test-Path $_})][string]$SourceDir =".\"
)
#list of files in source dir which will be deployed
$filesToDeploy =@("afwCoreServ.dll")

#set to false if you can't handle service by the script
#in this case you have to specify $dirToDeploy value too
#$serviceDeployment = $false
$serviceDeployment = $true 

#Name of the service as registered in the system
$serviceName = "avast! Firewall"
#$serviceName = "aswbIDSAgent"

#set the $deployToServiceDir to false, and $dirToDeploy to directory where you can deploy files
#if you don't want to deploy to the service binary folder
#this flag makes sense only when $serviceDeployment is set to true
$deployToServiceDir = $true


$dirToDeploy = "E:\xxx"

function TestBool ($VALUE) {
	if ($VALUE) {
		Write-Host -ForegroundColor GREEN “TRUE”
	} else {
		Write-Host -ForegroundColor RED   “FALSE”
	}
}

function IsServiceRunning {
	param($ServiceName)

	$arrService = Get-Service -Name $ServiceName
	if ($arrService.Status -eq "Running"){ 
		return $true
	}
	return $false
}
function StartService {
	param($ServiceName)
	if( IsServiceRunning($ServiceName) ){
		return $true
	}
	Start-Service -Name $ServiceName -ErrorAction SilentlyContinue #| Out-Null
	if( IsServiceRunning($ServiceName) ){
		return $true
	}
	return $false
}

function StopService{
	param($ServiceName)
	if( IsServiceRunning($ServiceName) ){
		Stop-Service -Name $ServiceName -ErrorAction SilentlyContinue | Out-Null
		if( IsServiceRunning($ServiceName) ){
			return $false
		}else{
			return $true
		}
	} else{
		return $true
	}

}

function GetSvcDir{
	param($ServiceName, [ref]$svcBinDir)

	$srvObj = Get-WmiObject win32_service -filter "Name='$ServiceName'"
	if(!$srvObj){
		Write-Host "Service ""$ServiceName"" is not installed" -ForegroundColor Red
		return $false
	}
	$svcPath = $srvObj.PathName
	#extract directory - remove quotations, if any
	$pure =  $svcPath -replace '"', ""
	$index = $pure.IndexOf('/SVC')
	if ($index -ge 0) {
		$pure = $pure.Substring(0, $pure.IndexOf('/SVC'))
	}
	$svcDir = Split-Path $pure
	Write-Host "Service binary folder is: $svcDir" -ForegroundColor Green
	$svcBinDir.Value = $svcDir
	return $true
}

function ServiceInfo{

	param($ServiceName, [ref]$svcBinDir)
	

	Write-Host "Checking Service ""$ServiceName"" status..."
	$srvObj = Get-WmiObject win32_service -filter "Name='$ServiceName'"
	if(!$srvObj){
		Write-Host "Service ""$ServiceName"" is not installed" -ForegroundColor Red
		return $false
	}
	Write-Host "Service ""$ServiceName"" is  installed" -ForegroundColor green
	$userName = $srvObj.StartName
	$mode = $srvObj.StartMode
	Write-Host "Service account is: ""$userName"" account" -ForegroundColor green
	Write-Host "Service start mode is: ""$mode""" -ForegroundColor green
	if(IsServiceRunning($ServiceName)){
		Write-Host "Service state is running" -ForegroundColor green
	}else{
		Write-Host "Service state is stopped" -ForegroundColor green
	}
	$svcPath = $srvObj.PathName
	Write-Host "Service path is: $svcPath" -ForegroundColor Green
	#extract directory - remove quotations, if any
	$pure =  $svcPath -replace '"', ""
	$index = $pure.IndexOf('/SVC')
	if ($index -ge 0) {
		$pure = $pure.Substring(0, $pure.IndexOf('/SVC'))
	}
	$svcDir = Split-Path $pure
	Write-Host "Service binary folder is: $svcDir" -ForegroundColor Green
	return $true

}
function DeployFiles
{
	param([String] $destDir, [String] $sourceDirParam, $fileNamesArray)
	#param([String] $destDir, [String] $sourceDirParam, [String[]] $fileNamesArray)
	foreach ($element in $fileNamesArray) {
		Write-Host "Deploying the file ""$element""..." 
		$srcFile =  Join-Path -Path $sourceDirParam -ChildPath $element
		if(-Not (Test-Path -Path $srcFile -ErrorAction SilentlyContinue) ) {
			Write-Host "Source file ""$element"" doesn't exist in folder ""$sourceDirParam""!" -foregroundcolor red	
			Write-Host "Unable to continue with depoying" -foregroundcolor red	
			return $false
		}
		$dstFile =  Join-Path -Path $destDir -ChildPath $element
		$dstFileBkp =  $dstFile + ".orig"
		if(Test-Path -Path $dstFile -ErrorAction SilentlyContinue) {
			if(-Not (Test-Path -Path $dstFileBkp -ErrorAction SilentlyContinue) ) {
				#create backup of the original file
				Write-Host "Creating backup of the file ""$element""." -foregroundcolor yellow
				Copy-Item $dstFile $dstFileBkp
				if(-Not (Test-Path -Path $dstFileBkp -ErrorAction SilentlyContinue) ) {
					Write-Host "Creating backup of the file ""$element"" failed!" -foregroundcolor red
					Write-Host "Unable to continue with depoying" -foregroundcolor red	
					return $false
				}
			}
			#now remove old file and copy the new one
			for ( $n = 6; $n -ge 1; $n-- ) {
				Remove-Item –path $dstFile -force -ErrorAction SilentlyContinue | Out-Null
				if(Test-Path -Path $dstFile -ErrorAction SilentlyContinue) {
					Start-Sleep -Milliseconds 500
				}else{
					break 
				}
			}
			if(Test-Path -Path $dstFile -ErrorAction SilentlyContinue) {
				Write-Host "Unable to delete ""$element"" in destination!!" -foregroundcolor red	
				Write-Host "Unable to continue with depoying" -foregroundcolor red	
				return $false
			}
		}else{
			Write-Host "The original file ""$element"" doesn't exist in destination ""$destDir""" -foregroundcolor yellow
			Write-Host "Deploying new ""$element"" file from scratch" -foregroundcolor yellow
		}
		#copy new file
		Copy-Item $srcFile $dstFile
		if(Test-Path -Path $dstFile -ErrorAction SilentlyContinue) {
			Write-Host "The ""$element"" file successfully deployed" -foregroundcolor green	
		} else {
			Write-Host "Unable to copy ""$element"" to destination ""$destDir""" -foregroundcolor red
			Write-Host "Unable to continue with depoying" -foregroundcolor red	
			return $false
		}
	}
	Write-Host "All files sucesfully deployed." -foregroundcolor green	
	return $true
}

function StopFn
{
	Write-Host "Going to stop the service ""$ServiceName""..."
	if(IsServiceRunning($ServiceName)){
		StopService $ServiceName
		if(IsServiceRunning($ServiceName)){
			Write-Host "Unable to stop the service!" -ForegroundColor red
			return $false
		} else {
			Write-Host "Service state is stopped" -ForegroundColor green
		}
	}else{
		Write-Host "Service is already stopped." -ForegroundColor Yellow
	}
	return $true
}

function StartFn
{
	Write-Host "Going to start the service ""$ServiceName""..."
	if(IsServiceRunning($ServiceName)){
		Write-Host "Service is already running." -ForegroundColor Yellow
		return $true
	}
	StartService $ServiceName
	if(IsServiceRunning($ServiceName)){
		Write-Host "Service has been started successfully" -ForegroundColor Green	
	} else {
		Write-Host "Unable to start the service!" -ForegroundColor red
		return $false
	}
	return $true
}

function StopAndCopyFn
{
	if($serviceDeployment -eq $true){
		$rv = StopFn
	}else{
		Write-Host 'Service mode deploying is disabled by $serviceDeployment = $false'.
		$rv = $true;
	}
	if($rv -eq $true){
		Write-Host "Going to deploy files to ""$dirToDeploy""..."
		$rv = DeployFiles $dirToDeploy $SourceDir  $filesToDeploy
	}else{
		Write-Host "Unable to continue with depoying - service not stopped!" -foregroundcolor red	
		$rv = $false
	}
	return $rv
}
function DeployFn
{
	
	$rv = StopAndCopyFn
	if($rv -eq $true){
		if($serviceDeployment -eq $true){
			#start service again
			$rv = StartFn
		}
	}
	if($rv -eq $true){
		Write-Host "Deployment finished successfully." -ForegroundColor green
	}else{
		Write-Host "Deployment Failed." -ForegroundColor Red
	}
	return $rv
}




#first handle actions where we do not need service dir (if any). But check if service enabled first
if( @("info", "start", "stop", "stopAndCopy") -contains $action) {
	if($serviceDeployment -eq $false){
		Write-Host "Service mode is disabled.!!" -ForegroundColor Red
		Write-Host 'Set the variable $serviceDeployment to true if you can handle the service.' -ForegroundColor Yellow
		Exit
	}
	switch($Action)
	{

	"info"  {$tt = ServiceInfo $serviceName; Exit  }
	"start" {$tt = StartFn; Exit }
	"stop"  {$tt = StopFn $serviceName; Exit }
	}
}
#these 

if($serviceDeployment -eq $true){
	if ( $deployToServiceDir -eq $true){
		$rv = GetSvcDir $serviceName ([ref]$dirToDeploy)
		if($rv){
			Write-Host "Deployment to service dir ""$dirToDeploy"" enabled" -ForegroundColor green
		}else{
			Write-Host "Unable to get service ""$serviceName"" for deployment" -ForegroundColor red
			Write-Host "Unable to continue with depoying" -foregroundcolor red	
			return $false
		}
	}
}

if(-Not (Test-Path -Path $dirToDeploy -ErrorAction SilentlyContinue) ) {
	Write-Host "The deployment directory ""$dirToDeploy"" doesn't exist!" -foregroundcolor red	
	Write-Host "Unable to continue with depoying" -foregroundcolor red	
	return $false
}

foreach ($ee in $filesToDeploy){
	Write-Host "$ee"
}
switch($Action)
{
	"info" {$tt= ServiceInfo $serviceName; break	}
	"copyFiles" { $tt = DeployFiles $dirToDeploy $SourceDir  $filesToDeploy ; break }
	"stopAndCopy" { $tt = StopAndCopyFn ; break}
	"deploy" { $tt= DeployFn;  break}
}