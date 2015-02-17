$ToolName="NFS Configuration"
$ToolVer="1.0"
$ToolDate="17th February 2015"
$ToolAuthor="Stephen Fearns"

# Live Environment
$Cluster="Isilon"
$ClusterUserID="root"
$ClusterPassword="password"

# Count must be greater than 0
$TodaysDate=Get-Date
$ReportFolder='C:\WorkFolder\Reports\'
$ReportFileName=[string](Get-Date -Format yyyyMMdd)+"_"+[string](Get-Date -Format HHmmss)+" - $Cluster - NFS Configuration"
$XMLReport=$ReportFolder+$ReportFileName+'.xml'

$ifsConnection = Connect-IsilonCluster -ClusterName $Cluster -Username $ClusterUserID -Password $ClusterPassword
if ($ifsConnected -like "Unable to connect to*") {return $ifsConnected}
if ($ifsConnected -like "No SSH session found*") {return $ifsConnected}

$t=Get-IsilonListNFSShares -ClusterName $Cluster
$t | Export-Clixml -Depth 30 -Path $XMLReport
