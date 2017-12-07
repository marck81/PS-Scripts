# #############################################################################
# Generate Excel with info about build in VSTS
# AUTHOR: marcosfri@youforce.net
# Description: Generate Reporting VSTS with info using VSTS API .
#NOTES: https://docs.microsoft.com/en-us/azure/virtual-machines/windows/managed-disks-overview#managed-disk-snapshots

# #############################################################################



Param(
   [string]$vstsAccount = "raet",
   [string]$projectName = "HRSelfService",  
   [string]$user = "marcosfri@youforce.net",
   [string]$token = "q2xs27mnim5jvi4sautkqi57dxpnhwjb5vxur7liftsxwyvvilda"
)

#Create a Base64-encoded Basi authorization header to authenticate with the API call.
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))
$global:totalXamlBuilds = 0
$global:totalVnextBuilds = 0
$global:totalXamlBuildsRun = 0
$global:totalVnextBuildsRun = 0
$global:results = @()


function ShowTeamProjectBuildInfo([string] $teamproy)
{
    Write-Host $teamproy
    #Construct the URL to make the desired API call
    $uri = "https://$($vstsAccount).visualstudio.com/defaultcollection/$($teamproy)/_apis/build/definitions?api-version=2.0"
    #Sends an HTTP(S) request to a RESTful web service and returns the results 
    $result = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}
    if ($result.count -eq 0)
    {        
         Write-host "--->Not build definitions present in $($teamproy): " $result.count -ForegroundColor Yellow         

    }
    else
    {
        Write-host "--->Number of build in $($teamproy): " $result.count -ForegroundColor Magenta
        $vnextBldNumber = 0;$xamlBldNumber = 0
        foreach ($item in $result.value)
        {
            #Write-host $item.name    
            if ($item.type -match 'build') {$vnextBldNumber++} else {$xamlBldNumber++}
        }
        Write-host "   ......Number of VNext builds in $($teamproy): " $vnextBldNumber
        Write-host "   ......Number of xaml builds in $($teamproy): "  $xamlBldNumber
        Set-Variable -Name totalXamlBuilds -Value ($totalXamlBuilds += $xamlBldNumber) -Scope 1
        Set-Variable -Name totalVnextBuilds -Value ($totalVnextBuilds += $vnextBldNumber) -Scope 1  

         #Add to excel
        $global:row++
        $col=1
        $cells.item($Row,$col)=$teamproy    
        $col++
        $cells.item($Row,$col)=$xamlBldNumber
        $cells.item($Row,$col).NumberFormat="0"
        $col++
        $cells.item($Row,$col)=$vnextBldNumber
        $cells.item($Row,$col).NumberFormat="0"
        #Add style
        $range=$ws.range("A1")
        $range.Style="Title"       
        $ws.Range("A3:F3").Style = "Heading 2"
        $ws.columns.item("C:C").EntireColumn.AutoFit()    | out-null      
        $ws.columns.item("A:A").EntireColumn.AutoFit() | out-null  
        $ws.columns.item("B:B").EntireColumn.AutoFit()  | out-null   

           
        
     
    }  

}

function ShowTeamProjectBuildRunInfo([string] $teamproy)
{
   
    #Construct the URL to make the desired API call
    $dateFrom = "{0:yyyy-MM-dd}" -f (get-date).AddDays(-7)
    $vnextBldNumberRun = 0;$xamlBldNumberRun = 0   
    $uri = "https://$($vstsAccount).visualstudio.com/defaultcollection/$($teamproy)/_apis/build/builds?type=xaml&minFinishTime=$($dateFrom)&api-version=2.0"
    $result = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}
    $xamlBldNumberRun = $result.count

    
    $uri = "https://$($vstsAccount).visualstudio.com/defaultcollection/$($teamproy)/_apis/build/builds?type=build&minFinishTime=$($dateFrom)&api-version=2.0"
    $result = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}
    $vnextBldNumberRun = $result.count
      
    
    Set-Variable -Name totalXamlBuildsRun -Value ($totalXamlBuildsRun += $xamlBldNumberRun) -Scope 1
    Set-Variable -Name totalVnextBuildsRun -Value ($totalVnextBuildsRun += $vnextBldNumberRun) -Scope 1  

   
    #Add to excel
    $global:row++
    $col=1
    $cells.item($Row,$col)=$teamproy    
    $col++
    $cells.item($Row,$col)=$xamlBldNumberRun
    $cells.item($Row,$col).NumberFormat="0"
    $col++
    $cells.item($Row,$col)=$vnextBldNumberRun
    $cells.item($Row,$col).NumberFormat="0"
    #Add style
    $range=$ws.range("A1")
    $range.Style="Title"       
    $ws.Range("A3:F3").Style = "Heading 2"
    $ws.columns.item("C:C").EntireColumn.AutoFit()    | out-null      
    $ws.columns.item("A:A").EntireColumn.AutoFit() | out-null  
    $ws.columns.item("B:B").EntireColumn.AutoFit()  | out-null  
      

}


#***************************************************************
#********************* MAIN ************************************
#***************************************************************

Write-Verbose "Creating Excel application" 
$global:xl=New-Object -ComObject "Excel.Application" 
$global:wb=$xl.Workbooks.Add()
#Excl constants.
$xlTheme=[Microsoft.Office.Interop.Excel.XLThemeColor]
$xlChart=[Microsoft.Office.Interop.Excel.XLChartType]
$xlIconSet=[Microsoft.Office.Interop.Excel.XLIconSet]
$xlDirection=[Microsoft.Office.Interop.Excel.XLDirection]
#Get the team projects build info.
$uri = "https://$($vstsAccount).visualstudio.com/defaultCollection/_apis/projects?api-version=2.0&stateFilter=All"
$result = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}
if ($result.count -eq 0)
{
     throw "Unable to retrive build info from $($vstsAccount) account"
}
Write-host "Number of team proyects in $($vstsAccount).visualstudio.com: " $result.count -ForegroundColor Green

#region NUMBER OF BUILD DEFINITIONS


    #Creating a Worksheets
    $global:ws=$wb.Worksheets.Add()
    $global:cells=$ws.Cells
    $cells.item(1,1)="Build Report for $($vstsAccount).visualstudio.com"
    #control navigation
    $global:row=3
    $global:col=1


                    "Team Proyect Name","NUm XAML Builds","Num VNext BUilds" | foreach {
        $cells.item($row,$col)=$_
        $cells.item($row,$col).font.bold=$True
        $col++
    }
    #Adding build info data.

    $result.value | foreach { ShowTeamProjectBuildInfo $_.name}

    #Add summary
    $global:row++
    $ws.Range("A$row:F$row").Style = "Heading 3"

    $col=1
    $cells.item($Row,$col)="Summary"
    $cells.item($Row,$col).Font.Size = 16
    $col++
    $cells.item($Row,$col)=$totalXamlBuilds
    $cells.item($Row,$col).NumberFormat="0"
    $cells.item($Row,$col).Font.Bold = $True 
    $col++
    $cells.item($Row,$col)=$totalVnextBuilds
    $cells.item($Row,$col).NumberFormat="0"
    $cells.item($Row,$col).Font.Bold = $True 

    #INSET A GRAPH **************
    $chart=$ws.Shapes.AddChart().Chart
    $chart.ChartType = 70 
    $chart.Elevation = 40 
    $ws.Shapes.Item("Chart 1").Fill.ForeColor.TintAndShade = .34 
    $ws.Shapes.Item("Chart 1").Fill.ForeColor.ObjectThemeColor = 5 
    $ws.Shapes.Item("Chart 1").Fill.BackColor.TintAndShade = .765 
    $ws.Shapes.Item("Chart 1").Fill.ForeColor.ObjectThemeColor = 5 
    $ws.Shapes.Item("Chart 1").Fill.TwoColorGradient(1,1) 

    $beginChartRow = $Row 
    $endChartRow = $row 
    $chartRange = $ws.Range(("A{0}" -f $beginChartRow),("C{0}" -f $endChartRow)) 
 
    #Set the location of the chart 
    $ws.Shapes.Item("Chart 1").Placement = 3 
    $ws.Shapes.Item("Chart 1").Top = 30 
    $ws.Shapes.Item("Chart 1").Left = 600 
    $chart.SetSourceData($chartRange) 
    $chart.seriesCollection(1).Select() | Out-Null
    $chart.SeriesCollection(1).ApplyDataLabels() | out-Null
    $chart.HasTitle = $True 


    $chart.chartType=$xlChart::xlBarClustered
    $chart.HasTitle = $true
    $chart.ChartTitle.Text = "Build Definitions Usage"
    $ws.Name="Build Definitions"


#endregion



#region NUMBER OF BUILD RUN LAST WEEK

    $global:ws=$wb.Worksheets.Add()
    $global:cells=$ws.Cells
    $cells.item(1,1)="Build Run Report for $($vstsAccount).visualstudio.com"
    #control navigation
    $global:row=3
    $global:col=1;


    "Team Proyect Name","NUm XAML Builds Run","Num VNext BUilds Run" | foreach {
            $cells.item($row,$col)=$_
            $cells.item($row,$col).font.bold=$True
            $col++
        }

    $result.value | foreach { ShowTeamProjectBuildRunInfo $_.name}

    #Add summary
    $global:row++
    $ws.Range("A$row:F$row").Style = "Heading 3"

    $col=1
    $cells.item($Row,$col)="Summary"
    $cells.item($Row,$col).Font.Size = 16
    $col++
    $cells.item($Row,$col)=$totalXamlBuildsRun
    $cells.item($Row,$col).NumberFormat="0"
    $cells.item($Row,$col).Font.Bold = $True 
    $col++
    $cells.item($Row,$col)=$totalVnextBuildsRun
    $cells.item($Row,$col).NumberFormat="0"
    $cells.item($Row,$col).Font.Bold = $True 

    #INSERT A GRAPH **************
    $chart=$ws.Shapes.AddChart().Chart
    $chart.ChartType = 70 
    $chart.Elevation = 40 
    $ws.Shapes.Item("Chart 1").Fill.ForeColor.TintAndShade = .34 
    $ws.Shapes.Item("Chart 1").Fill.ForeColor.ObjectThemeColor = 6 
    $ws.Shapes.Item("Chart 1").Fill.BackColor.TintAndShade = .765 
    $ws.Shapes.Item("Chart 1").Fill.ForeColor.ObjectThemeColor = 6 
    $ws.Shapes.Item("Chart 1").Fill.TwoColorGradient(1,1)

    $beginChartRow = $Row 
    $endChartRow = $row 
   
   
    $chartRange = $ws.Range(("A{0}" -f $beginChartRow),("C{0}" -f $endChartRow)) 
 
    #Set the location of the chart 
    $ws.Shapes.Item("Chart 1").Placement = 3 
    $ws.Shapes.Item("Chart 1").Top = 30 
    $ws.Shapes.Item("Chart 1").Left = 600 
    
    $chart.SetSourceData($chartRange) 
    $chart.seriesCollection(1).Select() | Out-Null
    $chart.SeriesCollection(1).ApplyDataLabels() | out-Null
    $chart.HasTitle = $True 


    $chart.chartType=$xlChart::xlBarClustered
    $chart.HasTitle = $true
    $chart.ChartTitle.Text = "Builds Run Last Week"
    $ws.Name="Build Run Info" 



#endregion

echo ""
echo "/**********************************************************/"
echo " ********   summary $vstsAccount.visualstudio.com"
echo "/**********************************************************/"
echo ""


Write-host " Number of VNext builds in $($vstsAccount).visualstudio.com: " $totalVnextBuilds
Write-host " Number of xaml builds in $($vstsAccount).visualstudio.com: "  $totalXamlBuilds
echo ""
#Write-host " Number of VNext builds run last week in $($vstsAccount).visualstudio.com: " $VNextBldRun
Write-host " Number of xaml builds run last week in $($vstsAccount).visualstudio.com: "  $totalXamlBuildsRun
Write-host " Number of vnext builds run last week in $($vstsAccount).visualstudio.com: "  $totalVnextBuildsRun

#Show the excel
#rename the worksheet
$name='Builds Run'
$ws.Name=$name

#$ws.Range("A1").Select() | Out-Null
$xl.Visible=$True
















