function Get-AzureMetricsReport {
    param(
        [Parameter(
            Mandatory = $true,
            Position = 0)]
        [string]
        [string]    $ResponseBodyFile,
        [Parameter(
            Mandatory = $true,
            Position = 1
        )]
        [string]
        [string]    $subscriptionId,
        [Parameter(
            Mandatory = $true,
            Position = 2
        )]
        [string]
        [string]    $resourceGroups,
        [Parameter(
            Mandatory = $true,
            Position = 3
        )]
        [string]
        [string]    $virtualMachines,
        [Parameter(
            Mandatory = $true,
            Position = 4
        )]
        [DateTime]
        [DateTime]  $startTime,
        [Parameter(
            Mandatory = $true,
            Position = 5
        )]
        [DateTime]
        [DateTime]  $endTime,
        [Parameter(
            Mandatory = $true,
            Position = 6
        )]
        [string]
        [string]    $metricnames,
        [Parameter(
            Mandatory = $true,
            Position = 6
        )]
        [string]
        [string]    $aggregation,
        [Parameter(
            Mandatory = $true,
            Position = 7
        )]
        [string]
        [string]    $AuthorizationHeader,
        [Parameter(
            Mandatory = $true,
            Position = 8)]
        [string]
        [string]    $sessionId
    )
    
    [DateTime]$_startTime     = $startTime;
    [DateTime]$_endTime       = $endTime;



    if (!(Get-Date -Date $_startTime).IsDaylightSavingTime()) {
        $_startTime = $_startTime.AddHours(-1);
    }

    if (!(Get-Date -Date $_endTime).IsDaylightSavingTime()) {
        $_endTime   = $_endTime.AddHours(-1);
    }

    [string]$startTime_ISO  = [string](Get-Date -Date $_startTime.ToUniversalTime() -UFormat '+%Y-%m-%dT%H:%M:%S.000Z');
    [string]$endTime_ISO    = [string](Get-Date -Date $_endTime.ToUniversalTime() -UFormat '+%Y-%m-%dT%H:%M:%S.000Z');

    $body = '{"requests":[{"relativeUrl":"/subscriptions/' + $subscriptionId + '/resourceGroups/' + $resourceGroups + '/providers/Microsoft.Compute/virtualMachines/' + $virtualMachines + '/providers/microsoft.Insights/metrics?timespan='+$startTime_ISO+'/'+$endTime_ISO+'&interval=PT5M&metricnames='+$metricnames+'&aggregation='+$aggregation+'&metricNamespace=microsoft.compute/virtualmachines&autoadjusttimegrain=true&api-version=2018-01-01","httpMethod":"GET"}]}'

    $header = @{
        "Host"                   = "management.azure.com" 
        "Content-Type"           = "application/json" 
        "Accept-Encoding"        = "none"
        "x-ms-client-session-id" = $sessionId
        "Authorization"          = $AuthorizationHeader
    }

    $Url = "https://management.azure.com/batch?api-version=2017-03-01";
   
    Invoke-RestMethod -UseBasicParsing -Uri $Url -Method 'Post' -Body $body -Headers $header -OutFile $ResponseBodyFile;
}

Set-StrictMode -Version 1.0;

[Flags()] enum AzureMetricsPropertyType {
    AutoDetectFieldNames = 0
    FirstFieldHasColumnNames = 1
    UsePropertyNames = 2
}

function Get-AzureMetricsPropertys {
    param (
        [Parameter(
            Mandatory = $false,
            Position = 0)
        ]
        [System.Object[]]               $ContentValue,
        [Parameter(
            Mandatory = $false,
            Position = 1)
        ]
        [AzureMetricsPropertyType]      $AzureMetricsPropertyType,
        [Parameter(
            Mandatory = $false,
            Position = 2)
        ]
        [System.Object[]]               $Propertys
    )
    $private:_Propertys =  @();
    $private:_Propertys += @{Label = "subscriptionId"; Expression = ([Scriptblock]::Create("`$subscriptionId")) };
    $private:_Propertys += @{Label = "ResourceGroup"; Expression = ([Scriptblock]::Create("`$ResourceGroup")) };
    $private:_Propertys += @{Label = "ResourceName"; Expression = ([Scriptblock]::Create("`$ResourceName")) };

    #Warning:
    #This will iterate through the whole result set to determine what the available fields are.
    switch ($AzureMetricsPropertyType) {
        ([AzureMetricsPropertyType]::FirstFieldHasColumnNames) {
            #Warning:
            #If you lied, and the first field does not have the column names you need, ya'll gonna be missing data.
            
            $ContentValue.responses.content.value[0].timeseries.data[0].psobject.properties.name | ForEach-Object {
                $private:_Propertys += @{Label = $_.ToString(); Expression = ([Scriptblock]::Create("`$_." + $_ + "")) };
            }
            continue;
        }

        ([AzureMetricsPropertyType]::UsePropertyNames) {
            #Warning:
            #These property names have to exist.
            if ($null -ne $Propertys){
            $Propertys | ForEach-Object {
                $private:_Propertys += @{Label = $_.ToString(); Expression = ([Scriptblock]::Create("`$_." + $_ + "")) };
            }
            }
            continue;
        }

        #AzureMetricsPropertyType.AutoDetectFieldNames {
        default {
            <#
            #https://stackoverflow.com/questions/14731782/powershell-how-to-use-select-object-to-get-a-dynamic-set-of-properties
            #>
            $FieldList = @();
            #$ContentValue.responses.content.value[0].timeseries.data[0].psobject.properties.name
            $ContentValue.responses.content.value[0].timeseries.data | ForEach-Object {
            #$ContentValue[0].timeseries.data | ForEach-Object {
                $_.psobject.properties.name | ForEach-Object {
                    if (-Not $FieldList.Contains($_)) {
                        $FieldList += $_;
                        $private:_Propertys += @{Label = $_.ToString(); Expression = ([Scriptblock]::Create("`$_." + $_ + "")) };
                    }
                }
            }
            continue;
        }
    }
    return $private:_Propertys;
}

<#
#Test Notes:
#Use this to test that the properties don't have compile errors.
1 | Select-Object -Property $private:Propertys

#
#Use this to verify the Properties work against a sample data set.
$MetricDataContent.responses.content.value[0].timeseries.data[0] | Select-Object -Property $private:Propertys
#>

function Get-AzureMetricsFromContentValue {
    #We are using PSScriptAnalyzer(PSUseDeclaredVarsMoreThanAssignments)
    #To remove the error: The variable 'subscriptionId/ResourceGroup/ResourceName' is assigned but never used.
    #It's used in the $private:Propertys section
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
    param (
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true)
        ]
        $Propertys,
        #[System.Object[]]               $Propertys,
        [Parameter(
            Mandatory = $true,
            Position = 1)
        ]
        [System.Object[]]               $ContentValue
    )
    #[object[]]$Properties = @();

    #$Properties = Get-AzureMetricsPropertys -ContentValue $ContentValue -AzureMetricsPropertyType $AzureMetricsPropertyType -Properties $Propertys;

    $TimeSeries = @();
    [string]$ResourceInformation = '';
    [string]$subscriptionId = "";
    [string]$ResourceGroup = "";
    [string]$ResourceName = "";
    #$ContentValue;
    $ContentValue.responses.content.value | ForEach-Object {
        $ResourceInformation = [string]($_.id);
        $subscriptionId = $ResourceInformation.Split('/')[2];
        $ResourceGroup = $ResourceInformation.Split('/')[4];
        $ResourceName = $ResourceInformation.Split('/')[8];
        $TimeSeries += $_.timeseries.data | Select-Object -Property $Propertys;

        return $TimeSeries;
    }
    Remove-Variable ResourceInformation;
    Remove-Variable subscriptionId;
    Remove-Variable ResourceGroup;
    Remove-Variable ResourceName;
}


#$MetricDataContent = '';
#$MetricDataContent = Get-Content $MetricDataFile | ConvertFrom-Json;
<#
$MetricDataFile = 'GetBatch_001.json';
$ContentValue = Get-Content $MetricDataFile | ConvertFrom-Json;
#>

#$Propertys =    Get-AzureMetricsPropertys                  -ContentValue $MetricDataContent.responses.content.value
#$Propertys =    Get-AzureMetricsPropertys                  -AzureMetricsPropertyType AzureMetricsPropertyType.UsePropertyNames -Properties "timeStamp","maximum"
#                Get-AzureMetricsFromContentValue           -ContentValue $MetricDataContent.responses.content.value -Propertys $Propertys;

<#
Remove-Variable TimeSeries;
Remove-Variable MetricDataContent;
Remove-Variable ResourceInformation;
#>
