$ToolName="Quota Usage (CSV / XML)"
$ToolVer="1.0"
$ToolDate="22nd January 2015"
$ToolAuthor="Stephen Fearns"

# Live Environment
$Cluster="Isilon"
$ClusterUserID="root"
$ClusterPassword="password"

# Count must be greater than 0
$TodaysDate=Get-Date
$ReportFolder='C:\WorkFolder\Reports\'
$ReportFileName=[string](Get-Date -Format yyyyMMdd)+"_"+[string](Get-Date -Format HHmmss)+" - Quota Usage for Isilon Cluster ($Cluster)"
$XMLReport=$ReportFolder+$ReportFileName+'.xml'
$CSVReport=$ReportFolder+$ReportFileName+'.csv'

$ifsConnection = Connect-IsilonCluster -ClusterName $Cluster -Username $ClusterUserID -Password $ClusterPassword
if ($ifsConnected -like "Unable to connect to*") {return $ifsConnected}
if ($ifsConnected -like "No SSH session found*") {return $ifsConnected}

$t=Get-IsilonListQuotas -ClusterName $Cluster

"# 'thresholds.hard' is the User or Directory Limit" | Set-Content $CSVReport
"# 'usage_derived' is the User or Directory Usage" | Add-Content $CSVReport
"# Used Percentage = Usage/(Limit/100)" | Add-Content $CSVReport
"# Used = Limit - Usage" | Add-Content $CSVReport
"# 'Type' can be user, directory" | Add-Content $CSVReport
"# 'AppliesTo' SamAccountName" | Add-Content $CSVReport
"# 'Path' location for the results" | Add-Content $CSVReport
"# Other columns can be ignored - added if needed in the future" | Add-Content $CSVReport
"#" | Add-Content $CSVReport

$t | Select-Object Type,AppliesTo,Path,include_snapshots,thresholds_include_overhead,thresholds.hard,thresholds.soft,thresholds.advisory,usage_derived | Sort-Object Path | ConvertTo-Csv | Add-Content $CSVReport
$t | Export-Clixml -Depth 30 -Path $XMLReport
