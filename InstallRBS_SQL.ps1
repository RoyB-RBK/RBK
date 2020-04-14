<#
.SYNOPSIS
Install the Rubrik Backup Service on remote machines and register to Rubrik Cluster

.DESCRIPTION
Script will download the Rubrik Backup Service from the RubrikCluster provided. The script will then push the msi, perform a quiet install 
and then configure the service to start under a specific service account. 

.PARAMETER RubrikCluster
Requires the Name or IP Address of the Rubrik Cluster

.PARAMETER RubrikCreds
Requires an input for Credentials of the Rubrik Cluster you want to Log in to for joining RBS Hosts to Rubrik

.PARAMETER CSV
Optional - Location of the CSV file (which lists hosts for RBS deploy) for import through the script

.PARAMETER LogOnAsCreds
Optional - Credentials for changing the Log On As account for RBS (specifically for registering SQL Databases through Rubrik)

.EXAMPLE
.\ InstallRBS_SQL.ps1 -RubrikCluster 172.24.17.13
Enter in Credentials for the Rubrik Cluster first
Then enter in Credentials used for the RBS LogOn As (Note that credentials should be entered in the DOMAIN\username format)

.NOTES
    Name:               Install and Register RBS
    Created:            4/1/2020
    Author:             Roy Berkowitz
#>

Param(
    # Rubrik Cluster name or ip address
    [Parameter(Mandatory=$true)]
    [string]$RubrikCluster,

    # Credential to log into Rubrik Cluster
    [Parameter(Mandatory=$true)]
    [pscredential]$RubrikCreds,

    # Location of CSV file for import
    [Parameter(Mandatory=$false)]
    [string]$CSVLoc = "C:\hosts.csv",
    
    # Parameter for changing Log On As Account for RBS Installation
    [Parameter(Mandatory=$true)]
    [pscredential]$LogOnAsCreds
      )

Start-Transcript -Path C:\output.txt -Append
      
##########################
# Set External Variables #
##########################

$csv = Import-Csv $CSVLoc
$Out = "C:\RubrikBackupService.zip"

<#$RubrikConnection = @{
    Server = $RubrikCluster
    RubrikCreds = $RubrikCreds
                     } #>
         
$ReadPass = (New-Object PSCredential $LogOnAsCreds.Username,$LogOnAsCreds.Password).GetNetworkCredential().Password


$url =  "https://$($RubrikCluster)/connector/RubrikBackupService.zip"

add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "Grabbing the RBS Installer Package from $RubrikCluster and Saving it in $Out." -ForegroundColor Green
Invoke-WebRequest -Uri $url -Outfile $Out

Write-Host "Reading the Host CSV File." -ForegroundColor Green
foreach ($line in $csv)
{

##########################
# Set Internal Variables #
##########################
    
    $computer = $line.ComputerName
    $session = New-PSSession -ComputerName $computer
    $file = 'C:\RubrikBackupService.zip'
    
############################
# Copy RBS to New Computer #
############################    

Write-Host "Copying RBS Installer to $computer at Location $file." -ForegroundColor Green
Copy-Item -Path $file -ToSession $session -Destination 'C:\'

#######################################################
# Enter into New PSSession and Perform the Following: #
#    - Unzip RBS.zip File in C:\RubrikBackupService\  #
#    - Silently Install RBS                           #
#    - Change the Log On As Account in Services       #
#    - Restart the Rubrik Backup Service              #
#######################################################

Write-Host "Unzipping RBS Files and Starting the Install Process." -ForegroundColor Green
Invoke-Command -Session $session -ScriptBlock {
    Expand-Archive C:\RubrikBackupService.zip -DestinationPath C:\RubrikBackupService\;
    Start-Process msiexec.exe -Wait -ArgumentList '/I C:\RubrikBackupService\RubrikBackupService.msi /quiet';
    $service = gwmi win32_service -filter "name='Rubrik Backup Service'";
    $service.change($null,$null,$null,$null,$null,$null,$Using:LogOnAsCreds.Username,$Using:ReadPass); 
    #Get-Service -Name "Rubrik Backup Service" | Restart-Service 
                                               }
                                              
###########################################################
# Exit Specific Session Before Moving on to Next Computer #
###########################################################

Write-Host "Exiting out of the Current Session." -ForegroundColor Green
Get-PSSession | Remove-PSSession
    
##########################
# Add the host to Rubrik #
##########################  

Write-Host "Connecting to $RubrikCluster and Registering $computer." -ForegroundColor Green
Import-Module Rubrik
Connect-Rubrik -Server $RubrikCluster -Credential $RubrikCreds | Out-Null
New-RubrikHost -Name $computer -Confirm:$false
Disconnect-Rubrik 
Write-Host "The Copy and Installation Process will now start again for any other machines in the CSV. It will exit if not." -ForegroundColor Blue
}

Stop-Transcript

<# 
 Additions for the future:
 Error check if host does not exist or typo
 Check against existing machines/VM/RBS installed
#> 


