# RBK

.NOTES
    Name:               Install and Register RBS on SQL
    Created:            4/1/2020
    Author:             Roy Berkowitz

.SYNOPSIS
Install the Rubrik Backup Service on remote machines and register to Rubrik Cluster

.DESCRIPTION
Script will download the Rubrik Backup Service from the RubrikCluster provided. The script will then push the msi, perform a quiet install and then configure the service to start under a specific service account. 

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


