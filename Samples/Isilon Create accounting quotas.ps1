$ToolName="Create accounting quotas"
$ToolVer="1.0"
$ToolDate="17th February 2015"
$ToolAuthor="Stephen Fearns"

$Cluster="Isilon"
$ClusterUserID="root"
$ClusterPassword="password"

$TodaysDate=Get-Date
$CSVFile = 'Isilon Create accounting quotas.csv'
$ReportTitle="Quota Usage for Isilon Cluster ($Cluster)"

$ifsConnection = Connect-IsilonCluster -ClusterName $Cluster -Username $ClusterUserID -Password $ClusterPassword

if ($ifsConnected -like "Unable to connect to*") {return $ifsConnected;break}
if ($ifsConnected -like "No SSH session found*") {return $ifsConnected;break}

# Get the current SMB shares
$CurrentSMB = Get-IsilonListSMBShares -ClusterName $Cluster

if (Test-Path ($CSVFile)){Write-Output 'CSV file found'} else {Write-Error 'CSV File not found';break}

$CSV = Import-Csv -Path $CSVFile
for ($i=0;$i -lt $CSV.count;$i++) {
    $NewPath = ($CurrentSMB | Where-Object name -eq $CSV[$i].Division).path + '/' + $CSV[$i].Path
    Write-Output "Creating user account for : $NewPath"
    New-IsilonQuotaUserAccounting -ClusterName $Cluster -Path $NewPath
}