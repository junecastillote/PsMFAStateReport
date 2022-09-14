Function New-MFAReport {
    [cmdletbinding()]
    param (
        [parameter(
            ValueFromPipeline = $true
        )]
        [ValidateNotNullOrEmpty()]
        $InputObject,

        [parameter()]
        [string]
        $ReportDirectory
    )

    begin {


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

        if (!(Test-Path -Path $ReportDirectory)) {
            try {
                SayInfo "Attempting to create the output directory $ReportDirectory."
                $null = New-Item -ItemType Directory -Path $ReportDirectory -Force -ErrorAction Stop
                SayInfo "Success: Output directory creation"
            }
            catch {
                SayInfo "Fail: There was an error creating the output directory.`n$($_.Exception.Message)."
                return $null
            }
        }
        else {
            SayInfo "Output directory already exists [$ReportDirectory]."
        }
        $HtmlFilename = "$($ReportDirectory)\MFA_State_Report.html"

        $isPipeline = $true
        $dataObject = [System.Collections.ArrayList]@()
        If ($PSBoundParameters.ContainsKey('InputObject')) {
            $dataObject.AddRange($InputObject)
            $isPipeline = $false
        }

    }
    process {
        If ($isPipeline) {
            # $null = $dataObject.Add($_)
            if ($_.'User Enabled' -eq $true) {
                $null = $dataObject.Add($_)
            }
        }
    }
    end {

        #Validate the InputObject type shpuld be "PS.AzAd.User.MFAState.Company_Name"
        # $ObjectTypeName = ($dataObject | Get-Member)[0].TypeName
        # if ($ObjectTypeName -notlike "*PS.AzAd.User.MFAState.*") {
        #     SayWarning "The object type you are trying to process does not match the type [PS.AzAd.User.MFAState.Company_Name]. The object may be corrupted."
        #     return $null
        # }

        # $Organization = (($ObjectTypeName).Split('.')[-1])
        $Organization = $dataObject[0].Organization

        $ThisFunction = ($MyInvocation.MyCommand)
        $ThisModule = Get-Module ($ThisFunction.Source)
        $ResourceFolder = [System.IO.Path]::Combine((Split-Path ($ThisModule.Path) -Parent), 'resource')
        # $ReportDirectory = "$($ReportDirectory)\$($Organization)"

        #Region Summary Object
        SayInfo "Creating the report summary object."

        $mfa_summary = @(
            ([PSCustomObject]@{Name = 'Total Accounts'; Value = $dataObject.Count ; Type = 'Overview' }),
            ([PSCustomObject]@{Name = 'Total with MFA'; Value = @($dataObject | Where-Object { ($_.'MFA Enabled') -eq $true }).Count ; Type = 'Overview,MFA On' }),
            ([PSCustomObject]@{Name = 'Total without MFA'; Value = @($dataObject | Where-Object { ($_.'MFA Enabled') -eq $false }).Count ; Type = 'Overview,MFA Off' }),
            ([PSCustomObject]@{Name = 'Admin Accounts'; Value = @($dataObject | Where-Object { ($_.'Is Admin') -eq $true }).Count ; Type = 'Overview' }),
            ([PSCustomObject]@{Name = 'Admins with MFA'; Value = @($dataObject | Where-Object { ($_.'Is Admin') -eq $true -and ($_.'MFA Enabled') -eq $true }).Count ; Type = 'Overview,MFA On' }),
            ([PSCustomObject]@{Name = 'Admins without MFA'; Value = @($dataObject | Where-Object { ($_.'Is Admin') -eq $true -and ($_.'MFA Enabled') -eq $false }).Count ; Type = 'Overview,MFA Off' }),
            ([PSCustomObject]@{Name = 'User Accounts'; Value = @($dataObject | Where-Object { ($_.'Is Admin') -eq $false }).Count ; Type = 'Overview' }),
            ([PSCustomObject]@{Name = 'Users with MFA'; Value = @($dataObject | Where-Object { ($_.'Is Admin') -eq $false -and ($_.'MFA Enabled') -eq $true }).Count ; Type = 'Overview,MFA On' }),
            ([PSCustomObject]@{Name = 'Users without MFA'; Value = @($dataObject | Where-Object { ($_.'Is Admin') -eq $false -and ($_.'MFA Enabled') -eq $false }).Count ; Type = 'Overview,MFA Off' }),
            ([PSCustomObject]@{Name = 'Per User'; Value = @($dataObject | Where-Object { $_.'MFA Type' -eq 'Per User' }).Count  ; Type = 'Activation Type' }),
            ([PSCustomObject]@{Name = 'Conditional Access'; Value = @($dataObject | Where-Object { $_.'MFA Type' -eq 'Conditional Access' }).Count  ; Type = 'Activation Type' })
        )

        # add method types
        $mfa_method_types = @(($dataObject | Where-Object { $_.'Default MFA Method' }).'Default MFA Method' | Group-Object | Sort-Object Count -Descending | Select-Object Name, Count)
        if ($mfa_method_types.count -gt 0) {
            foreach ($item in $mfa_method_types) {
                $mfa_summary += ([PSCustomObject]@{Name = $item.Name; Value = $Item.Count ; Type = 'Method Type' })
            }
        }

        # add admin roles without MFA
        if (($mfa_summary | Where-Object { $_.Name -eq 'Admins without MFA' }).Value -gt 0) {
            $admins_without_mfa_per_role = @(($dataObject | Where-Object { ($_.'Is Admin' -eq $true) -and ($_.'MFA Enabled' -eq $false) }).'Admin Roles' -join ';').split(';') | Group-Object | Sort-Object Count -Descending | Select-Object Name, Count
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
            InputObject  = $mfa_summary | Where-Object { $_.Type -eq 'Activation Type' }
            FooterText   = '*Count of user MFA enabled via Conditional Access Policy and User-Level'
            Width        = 600
            Height       = 400
            SaveToFile   = "$($ReportDirectory)\MFA_Chart_Types.png"
            RandomColors = $true
        }
        New-SummaryPieChart @splat

        # Create MFA Default Method Chart
        $splat = @{
            InputObject   = $mfa_summary | Where-Object { $_.Type -eq 'Method Type' }
            ColorSequence = @("#2a9d8f", "#8ab17d", "#babb74", "#e9c46a", "#f4a261", "#ee8959", "#e76f51", "#e97c61")
            FooterText    = '*Total user Default MFA Methods per type'
            Width         = 600
            Height        = 400
            IsReversed    = $true
            SaveToFile    = "$($ReportDirectory)\MFA_Chart_Methods.png"
            # RandomColors = $true
        }
        New-SummaryColumnChart @splat

        # Create Critical Admins without MFA Chart
        $splat = @{
            InputObject   = $mfa_summary | Where-Object { $_.Type -like "*Critical Admin Role*" } | Sort-Object -Property Value -Descending
            ColorSequence = @("#a23216", "#c6573c", "#cb664e", "#d0745e", "#d4816d", "#d88c7a", "#dc9686", "#dfa091", "#e2a99b", "#e5b1a4")
            FooterText    = '*Critical admin roles without MFA. (https://bit.ly/3iHEy25)'
            Width         = 600
            Height        = 400
            IsReversed    = $true
            SaveToFile    = "$($ReportDirectory)\MFA_Chart_Admins.png"
        }

        New-SummaryBarChart @splat

        # Create MFA Overview Chart
        # Accounts with MFA
        $mfa_On_Overview = @(
            ([PSCustomObject]@{Name = 'Total Accounts'; Value = ($mfa_summary | Where-Object { $_.Name -eq 'Total with MFA' }).Value ; Type = 'Accounts with MFA' })
        )
        if (($mfa_summary | Where-Object { $_.Name -eq 'Admin Accounts' }).Value -gt 0) {
            $mfa_On_Overview += ([PSCustomObject]@{Name = 'Admin Accounts'; Value = ($mfa_summary | Where-Object { $_.Name -eq 'Admins with MFA' }).Value ; Type = 'Accounts with MFA' })
        }
        if (($mfa_summary | Where-Object { $_.Name -eq 'User Accounts' }).Value -gt 0) {
            $mfa_On_Overview += ([PSCustomObject]@{Name = 'User Accounts'; Value = ($mfa_summary | Where-Object { $_.Name -eq 'Users with MFA' }).Value ; Type = 'Accounts with MFA' })
        }

        # Accounts without MFA
        $mfa_Off_Overview = @(
            ([PSCustomObject]@{Name = 'Total Accounts'; Value = ($mfa_summary | Where-Object { $_.Name -eq 'Total without MFA' }).Value ; Type = 'Accounts without MFA' })
        )
        if (($mfa_summary | Where-Object { $_.Name -eq 'Admin Accounts' }).Value -gt 0) {
            $mfa_Off_Overview += ([PSCustomObject]@{Name = 'Admin Accounts'; Value = ($mfa_summary | Where-Object { $_.Name -eq 'Admins without MFA' }).Value ; Type = 'Accounts without MFA' })
        }

        if (($mfa_summary | Where-Object { $_.Name -eq 'User Accounts' }).Value -gt 0) {
            $mfa_Off_Overview += ([PSCustomObject]@{Name = 'User Accounts'; Value = ($mfa_summary | Where-Object { $_.Name -eq 'Users without MFA' }).Value ; Type = 'Accounts without MFA' })
        }

        $splat = @{
            InputObject = @($mfa_On_Overview, $mfa_Off_Overview)
            FooterText  = '*MFA state overview of admin and non-admin accounts'
            Width       = 600
            Height      = 400
            IsReversed  = $true
            SaveToFile  = "$($ReportDirectory)\MFA_Chart_Overview.png"
            # RandomColors = $true
        }
        New-SummaryStackedBarChart @splat

        # Create the HTML and CSV reports
        try {
            # Export details to CSV
            $dataObject | Export-Csv -NoTypeInformation -Path "$($ReportDirectory)\MFA_State_Details.csv" -Force -ErrorAction Stop
            # Copy resource files to output directory
            Copy-Item -Path ("$($ResourceFolder)\*") -Include "MFA_*.png", "MFA_*.html" -Destination $ReportDirectory -Force -ErrorAction Stop

            $HEADER_TEXT1 = ($Organization.replace('_', ' '))
            $HEADER_TEXT2 = ("Multifactor Authentication Status Report as of $(Get-Date -Format "yyyy-MMM-dd HH:mm tt")")
            $TITLE_TEXT1 = "[$HEADER_TEXT1] $HEADER_TEXT2"
            $MODULE_INFO = '<a href="' + $ThisModule.ProjectURI + '">' + $ThisModule.Name + ' v' + $ThisModule.Version + '</a>'

            $html = (Get-Content -Raw $HtmlFilename)
            $html = $html.Replace('TITLE_TEXT1', $TITLE_TEXT1)
            $html = $html.Replace('HEADER_TEXT1', $HEADER_TEXT1)
            $html = $html.Replace('HEADER_TEXT2', $HEADER_TEXT2)
            $html = $html.Replace('MODULE_INFO', $MODULE_INFO)
            $html | Out-File $HtmlFilename -Force -Encoding utf8
            SayInfo "HTML report saved to $($HtmlFilename)."
        }
        catch {
            SayWarning ($_.Exception.Message)
        }
        return $mfa_summary
    }
}