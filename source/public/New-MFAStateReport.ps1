Function New-MFAStateReport {
    [cmdletbinding()]
    param (
        [parameter(
            Mandatory,
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        $InputObject,

        [parameter()]
        [string]
        $OutputDirectory = $(
            "$($env:temp)\$($($MyInvocation.MyCommand).Source)"
        )
    )

    #Validate the InputObject type shpuld be "PS.AzAd.User.MFAState.Company_Name"
    $ObjectTypeName = ($InputObject | Get-Member)[0].TypeName
    if ($ObjectTypeName -notlike "*PS.AzAd.User.MFAState.*") {
        Write-Warning "The object type you are trying to process does not match the type [PS.AzAd.User.MFAState.Company_Name]. The object may be corrupted."
        return $null
    }

    $Organization = (($ObjectTypeName).Split('.')[-1])

    $ThisFunction = ($MyInvocation.MyCommand)
    $ThisModule = Get-Module ($ThisFunction.Source)
    $ResourceFolder = [System.IO.Path]::Combine((Split-Path ($ThisModule.Path) -Parent), 'resource')
    $OutputDirectory = "$($OutputDirectory)\$($Organization)"

    # https://docs.microsoft.com/en-us/azure/active-directory/conditional-access/howto-conditional-access-policy-admin-mfa
    # https://bit.ly/3iHEy25
    $Critical_Admin_Roles = @(
        'Global administrator',
        'Application administrator',
        'Authentication administrator',
        'Billing administrator',
        'Cloud application administrator',
        'Conditional Access administrator',
        'Exchange administrator',
        'Helpdesk administrator',
        'Password administrator',
        'Privileged authentication administrator',
        'Privileged Role administrator',
        'Security administrator',
        'Sharepoint administrator',
        'User administrator'
    )

    # If path does not exist, create it.

    if (!(Test-Path -Path $OutputDirectory)) {
        try {
            Write-Information "$(Get-Date) : Attempting to create the output directory $OutputDirectory."
            $null = New-Item -ItemType Directory -Path $OutputDirectory -Force -ErrorAction Stop
            Write-Information "$(Get-Date) : Success: Output directory creation"
        }
        catch {
            Write-Information "$(Get-Date) : Fail: There was an error creating the output directory.`n$($_.Exception.Message)."
            return $null
        }
    }
    else {
        Write-Information "$(Get-Date) : Output directory already exists [$OutputDirectory]."
    }
    $HtmlFilename = "$($OutputDirectory)\MFA_State_Report.html"

    #Region Summary Object
    Write-Information "$(Get-Date) : Creating the report summary object."

    $mfa_summary = @(
        ([PSCustomObject]@{Name = 'Total Accounts'; Value = $InputObject.Count ; Type = 'Overview' }),
        ([PSCustomObject]@{Name = 'Total with MFA'; Value = @($InputObject | Where-Object { ($_.'MFA Enabled') -eq $true }).Count ; Type = 'Overview,MFA On' }),
        ([PSCustomObject]@{Name = 'Total without MFA'; Value = @($InputObject | Where-Object { ($_.'MFA Enabled') -eq $false }).Count ; Type = 'Overview,MFA Off' }),
        ([PSCustomObject]@{Name = 'Admin Accounts'; Value = @($InputObject | Where-Object { ($_.'Is Admin') -eq $true }).Count ; Type = 'Overview' }),
        ([PSCustomObject]@{Name = 'Admins with MFA'; Value = @($InputObject | Where-Object { ($_.'Is Admin') -eq $true -and ($_.'MFA Enabled') -eq $true }).Count ; Type = 'Overview,MFA On' }),
        ([PSCustomObject]@{Name = 'Admins without MFA'; Value = @($InputObject | Where-Object { ($_.'Is Admin') -eq $true -and ($_.'MFA Enabled') -eq $false }).Count ; Type = 'Overview,MFA Off' }),
        ([PSCustomObject]@{Name = 'User Accounts'; Value = @($InputObject | Where-Object { ($_.'Is Admin') -eq $false }).Count ; Type = 'Overview' }),
        ([PSCustomObject]@{Name = 'Users with MFA'; Value = @($InputObject | Where-Object { ($_.'Is Admin') -eq $false -and ($_.'MFA Enabled') -eq $true }).Count ; Type = 'Overview,MFA On' }),
        ([PSCustomObject]@{Name = 'Users without MFA'; Value = @($InputObject | Where-Object { ($_.'Is Admin') -eq $false -and ($_.'MFA Enabled') -eq $false }).Count ; Type = 'Overview,MFA Off' }),
        ([PSCustomObject]@{Name = 'Per User'; Value = @($InputObject | Where-Object { $_.'MFA Type' -eq 'Per User' }).Count  ; Type = 'Activation Type' }),
        ([PSCustomObject]@{Name = 'Conditional Access'; Value = @($InputObject | Where-Object { $_.'MFA Type' -eq 'Conditional Access' }).Count  ; Type = 'Activation Type' })
    )

    # add method types
    $mfa_method_types = @(($InputObject | Where-Object { $_.'Default MFA Method' }).'Default MFA Method' | Group-Object | Sort-Object Count -Descending | Select-Object Name, Count)
    if ($mfa_method_types.count -gt 0) {
        foreach ($item in $mfa_method_types) {
            $mfa_summary += ([PSCustomObject]@{Name = $item.Name; Value = $Item.Count ; Type = 'Method Type' })
        }
    }

    # add admin roles without MFA
    $admins_without_mfa_per_role = @(($InputObject | Where-Object { ($_.'Is Admin' -eq $true) -and ($_.'MFA Enabled' -eq $false) }).'Admin Roles' -join ';').split(';') | Group-Object | Sort-Object Count -Descending | Select-Object Name, Count
    if ($admins_without_mfa_per_role.count -gt 0) {
        foreach ($item in $admins_without_mfa_per_role) {
            # $mfa_summary += ([PSCustomObject]@{Name = $item.Name; Value = $Item.Count ; Type = 'Admin Role' })
            $mfa_summary += (
                [PSCustomObject]@{
                    Name  = $item.Name;
                    Value = $Item.Count;
                    Type  = $(
                        if ($Critical_Admin_Roles -contains ($item.Name)) {
                            'Critical Admin Role,MFA Off'
                        }
                        else {
                            'Admin Role,MFA Off'
                        }
                    )
                }
            )
        }
    }

    #EndRegion Summary Object

    # Create MFA Activation Type Chart
    $splat = @{
        InputObject = $mfa_summary | Where-Object { $_.Type -eq 'Activation Type' }
        FooterText  = '*Count of user MFA enabled via Conditional Access Policy and User-Level'
        Width       = 450
        Height      = 400
        IsReversed  = $true
        SaveToFile  = "$($OutputDirectory)\MFA_Type_Chart.png"
        # RandomColors = $true
    }
    New-SummaryPieChart @splat

    # Create MFA Default Method Chart
    $splat = @{
        InputObject   = $mfa_summary | Where-Object { $_.Type -eq 'Method Type' }
        ColorSequence = @("#2a9d8f", "#8ab17d", "#babb74", "#e9c46a", "#f4a261", "#ee8959", "#e76f51", "#e97c61")
        FooterText    = '*Total user Default MFA Methods per type'
        Width         = 450
        Height        = 400
        IsReversed    = $true
        SaveToFile    = "$($OutputDirectory)\MFA_Methods_Chart.png"
        # RandomColors = $true
    }
    New-SummaryColumnChart @splat

    # Create Critical Admins without MFA Chart
    $splat = @{
        InputObject   = $mfa_summary | Where-Object { $_.Type -like "*Critical Admin Role*" } | Sort-Object -Property Value -Descending
        ColorSequence = @("#a23216", "#c6573c", "#cb664e", "#d0745e", "#d4816d", "#d88c7a", "#dc9686", "#dfa091", "#e2a99b", "#e5b1a4")
        FooterText    = '*Critical admin roles without MFA. (https://bit.ly/3iHEy25)'
        Width         = 450
        Height        = 400
        IsReversed    = $true
        SaveToFile    = "$($OutputDirectory)\Critical_Admins_without_MFA_Chart.png"
    }
    New-SummaryBarChart @splat

    # Create MFA Overview Chart
    # Accounts with MFA
    $mfa_On_Overview = @(
        ([PSCustomObject]@{Name = 'Total Accounts'; Value = ($mfa_summary | Where-Object { $_.Name -eq 'Total with MFA' }).Value ; Type = 'Accounts with MFA' }),
        ([PSCustomObject]@{Name = 'Admin Accounts'; Value = ($mfa_summary | Where-Object { $_.Name -eq 'Admins with MFA' }).Value ; Type = 'Accounts with MFA' }),
        ([PSCustomObject]@{Name = 'User Accounts'; Value = ($mfa_summary | Where-Object { $_.Name -eq 'Users with MFA' }).Value ; Type = 'Accounts with MFA' })
    )

    # Accounts without MFA
    $mfa_Off_Overview = @(
        ([PSCustomObject]@{Name = 'Total Accounts'; Value = ($mfa_summary | Where-Object { $_.Name -eq 'Total without MFA' }).Value ; Type = 'Accounts without MFA' }),
        ([PSCustomObject]@{Name = 'Admin Accounts'; Value = ($mfa_summary | Where-Object { $_.Name -eq 'Admins without MFA' }).Value ; Type = 'Accounts without MFA' }),
        ([PSCustomObject]@{Name = 'User Accounts'; Value = ($mfa_summary | Where-Object { $_.Name -eq 'Users without MFA' }).Value ; Type = 'Accounts without MFA' })
    )

    $splat = @{
        InputObject = @($mfa_On_Overview, $mfa_Off_Overview)
        FooterText  = '*MFA state overview of admin and non-admin accounts'
        Width       = 450
        Height      = 400
        IsReversed  = $true
        SaveToFile  = "$($OutputDirectory)\MFA_Overview_Chart.png"
        # RandomColors = $true
    }
    New-SummaryStackedBarChart @splat

    try {
        # Export details to CSV
        $InputObject | Export-Csv -NoTypeInformation -Path "$($OutputDirectory)\MFA_State_Details.csv" -Force -ErrorAction Stop
        # Copy resource files to output directory
        Copy-Item -Path ("$($ResourceFolder)\*") -Include "icon*.png","*.html" -Destination $OutputDirectory -Force -ErrorAction Stop

        $HEADER_TEXT1 = ($Organization.replace('_', ' '))
        $HEADER_TEXT2 = ("Multifactor Authentication Status Report as of $(Get-Date)")
        $TITLE_TEXT1 = "[$HEADER_TEXT1] $HEADER_TEXT2"
        $MODULE_INFO = '<a href="' + $ThisModule.ProjectURI + '">' + $ThisModule.Name + ' v' + $ThisModule.Version + '</a>'

        $html = (Get-Content -Raw $HtmlFilename)
        $html = $html.Replace('TITLE_TEXT1', $TITLE_TEXT1)
        $html = $html.Replace('HEADER_TEXT1', $HEADER_TEXT1)
        $html = $html.Replace('HEADER_TEXT2', $HEADER_TEXT2)
        $html = $html.Replace('MODULE_INFO', $MODULE_INFO)
        $html | Out-File $HtmlFilename -Force -Encoding utf8
        Write-Information "$(Get-Date) : HTML report saved to $($HtmlFilename)."
    }
    catch {
        Write-Warning ($_.Exception.Message)
    }
    return $mfa_summary
}