﻿<#
.SYNOPSIS
    Creates a Windows Azure Website with settings:
    - Always on: true
    - PHP: off
    - 64bit: true

    Create Application Insights.

    Add app settings:
    WEBSITE_TIME_ZONE = Central Europe Standard Time
    APPINSIGHTS_INSTRUMENTATIONKEY = Application Insights Instrumentation Key
.DESCRIPTION 
   Creates a new website and a new Application Insight.  
.EXAMPLE
   .\create-website.ps1 -WebSiteName "myWebSiteName" [-ServicePlan] "ServicePlan" [-Location] "Location" 
#>
param(
    [CmdletBinding( SupportsShouldProcess=$true)]
         
    # The webSite Name you want to create
    [Parameter(Mandatory = $true)] 
    [string]$WebSiteName,
    
    [string]$ResourceGroup = "Default-Web-WestEurope",
     
    [string]$ServicePlan = "CellONE",

    [string]$Location = "West Europe"
    )

#$VerbosePreference = "Continue"

# Check if Windows Azure Powershell is avaiable
if ((Get-Module -ListAvailable Azure) -eq $null)
{
    throw "Windows Azure Powershell not found! Please install from http://www.windowsazure.com/en-us/downloads/#cmd-line-tools"
}
   
# Create the website 
$website = Get-AzureWebsite | Where-Object {$_.Name -eq $WebSiteName }
if ($website -eq $null) 
{   
    Write-Host "Creating website '$WebSiteName' in '$ResourceGroup' for '$ServicePlan'." 
    $website = New-AzureRMWebApp -ResourceGroupName $ResourceGroup -Name $WebSiteName -Location $Location -AppServicePlan $ServicePlan

    Write-Host "Setting PHP off"
    $website = Set-AzureRmWebApp -ResourceGroupName $ResourceGroup -Name $WebSiteName -PhpVersion "Off" 
    
    Write-Host "64bit mode on"
    $website = Set-AzureRmWebApp -ResourceGroupName $ResourceGroup -Name $WebSiteName -Use32BitWorkerProcess $false
    
    Write-Host "Setting always on"
    $Properties = @{"siteConfig" = @{"AlwaysOn" = $true}}
    $website = Set-AzureRmResource -PropertyObject $Properties -ResourceGroupName $ResourceGroup -ResourceType Microsoft.Web/sites -ResourceName $WebSiteName -ApiVersion 2015-08-01 -Force    
    
    Write-Host "Creating Application Insights"
    $ai = New-AzureRmResource -ResourceName $WebSiteName -ResourceGroupName $ResourceGroup -Tag @{ applicationType = "web"; applicationName = $webSiteName} -ResourceType "Microsoft.Insights/components" -Location $Location  -PropertyObject @{"Application_Type" = "web"} -Force
    Write-Host "IKey = " $ai.Properties.InstrumentationKey

    Write-Host "Adding app settings"
    $webApp = Get-AzureRmWebApp -ResourceGroupName $ResourceGroup -Name $WebSiteName 
    $appSettingList = $webApp.SiteConfig.AppSettings    
    
    $hash = @{}
    ForEach ($kvp in $appSettingList) {
        $hash[$kvp.Name] = $kvp.Value        
    }

    $hash['WEBSITE_TIME_ZONE'] = "Central Europe Standard Time"
    $hash['APPINSIGHTS_INSTRUMENTATIONKEY'] = $ai.Properties.InstrumentationKey
    $website = Set-AzureRMWebApp -ResourceGroupName $ResourceGroup -Name $WebSiteName -AppSettings $hash                
}
else 
{        
    throw "Website already exists. Please try a different website name."
}

Write-Host "Complete!"

