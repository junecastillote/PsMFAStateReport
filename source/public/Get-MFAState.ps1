Function Get-MFAState {
    [cmdletbinding()]
    param (
        # Use this parameter to connect to MS Online if you have not connected yet.
        [parameter()]
        [PSCredential]
        $Credential,
        # Use this parameter is you want to get the MFA state for specific UserPrincipalNames only
        [parameter()]
        [string[]]
        $UserPrincipalName,

        # Use this parameter is you want to get the MFA state for all users (excluding Guest users)
        [parameter()]
        [switch]
        $AllUsers,

        # Use this parameter is you want to pass the list of users from the Get-MsolUser command.
        # Example: Get-MFAState -UserObject $(Get-MsolUser -MaxResults 10)
        [parameter()]
        [Microsoft.Online.Administration.User[]]
        $UserObject,

        # Use this parameter is you want to get the MFA state for all Admin users only.
        [parameter()]
        [switch]
        $AdminOnly
    )

    $alphaTime = $(Get-Date)

    if ($Credential) {
        try {
            Connect-MsolService -Credential $Credential -ErrorAction Stop
        }
        catch {
            Write-Warning "$($_.Exception.Message) Exiting script."
            return $null
        }
    }

    # Test connection to MSOL
    try {
        $company_info = Get-MsolCompanyInformation -ErrorAction Stop
        $AdminRoles = @((Get-MsolRole -ErrorAction Stop).Name)
    }
    catch {
        Write-Warning "$($_.Exception.Message) Exiting script."
        return $null
    }

    # If no user list is provided, exit script.
    if (!$UserPrincipalName -and !$AllUsers -and !$UserObject -and !$AdminOnly) {
        Write-Warning "The user list is empty. `n  -> Use the -UserPrincipalName to provide the list of UserPrincipalName values.`n  -> Use the -All switch to get all users.`n  -> Use the -UserObject to specify [Microsoft.Online.Administration.User] objects.`n  -> Use the -AdminOnly to get the administrator accounts only. Exiting script.)"
        return $null
    }

    # Check if using there are conflicting parameters
    $uniqueParamsCount = 0
    if ($PSBoundParameters.ContainsKey('UserPrincipalName')) { $uniqueParamsCount++ }
    if ($PSBoundParameters.ContainsKey('AllUsers')) { $uniqueParamsCount++ }
    if ($PSBoundParameters.ContainsKey('UserObject')) { $uniqueParamsCount++ }
    if ($PSBoundParameters.ContainsKey('AdminOnly')) { $uniqueParamsCount++ }
    if ($uniqueParamsCount -gt 1) {
        Write-Warning "'Do not use the -UserPrincipalName, -AllUsers, -UserObject, and -AdminOnly parameters simultaneously.' `n  -> Use the -UserPrincipalName to provide the list of UserPrincipalName values.`n  -> Use the -All switch to get all users.`n  -> Use the -UserObject to specify [Microsoft.Online.Administration.User] objects.`n  -> Use the -AdminOnly to get the administrator accounts only. Exiting script.)"
        return $null
    }

    Write-Information "$(Get-Date) : Getting all users with administrator roles. Please wait."
    $Admin_Users = @(Get-AdminRoleMember -RoleName $AdminRoles)

    # Build the user list.
    # If -UserPrincipalName is used
    if ($UserPrincipalName) {
        $msolUserList = [System.Collections.ArrayList]@()
        $UserPrincipalName | ForEach-Object {
            try {
                $null = $msolUserList.Add($( Get-MsolUser -UserPrincipalName $_ -ErrorAction STOP | Select-Object ObjectID, UserPrincipalName, DisplayName, BlockCredential, StrongAuth*, IsLicensed))
            }
            catch {
                Write-Information "$(Get-Date) : $($_.Exception.Message)"
            }
        }
    }

    # If the -AllUsers switch is used, get all users (non-guests)
    if ($AllUsers) {
        $SnapTime = Get-Date
        Write-Information "$(Get-Date) : Getting all users. Please wait."
        $msolUserList = [System.Collections.ArrayList]@(Get-MsolUser -All | Where-Object { $_.UserType -eq 'Member' } | Select-Object ObjectID, UserPrincipalName, DisplayName, BlockCredential, StrongAuth*, IsLicensed)
        Write-Information "$(Get-Date) : There are $($msolUserList.Count) users retrieved. [Task Time = $(TimeSpan $SnapTime)]; Run time = [$(TimeSpan $alphaTime)]."
    }

    # If the -UserObject switch is used, get all users (non-guests)
    if ($UserObject) {
        $SnapTime = Get-Date
        Write-Information "$(Get-Date) : Filtering the user list to include non-Guest accounts only."
        $msolUserList = [System.Collections.ArrayList]@($UserObject | Where-Object { $_.UserType -eq 'Member' } | Select-Object ObjectID, UserPrincipalName, DisplayName, BlockCredential, StrongAuth*, IsLicensed)
        Write-Information "$(Get-Date) : There are $($msolUserList.Count) users filtered. [Task Time = $(TimeSpan $SnapTime)]; Run time = [$(TimeSpan $alphaTime)]."
    }

    # If the -AdminOnly is used, retrieve the list of admin user accounts.
    if ($AdminOnly) {
        $SnapTime = Get-Date
        Write-Information "$(Get-Date) : Filtering the user list to include Administrators only."
        $msolUserList = [System.Collections.ArrayList]@()
        ( $Admin_Users | Sort-Object -Property ObjectID | Select-Object -Property ObjectID -Unique  ) | ForEach-Object {
            try {
                $null = $msolUserList.Add(@(Get-MsolUser -ObjectId ($_.ObjectID) -ErrorAction STOP | Select-Object ObjectID, UserPrincipalName, DisplayName, StrongAuth*, IsLicensed))
            }
            catch {
                Write-Information "$(Get-Date) : $($_.Exception.Message)"
            }
        }
        Write-Information "$(Get-Date) : There are $($msolUserList.Count) users retrieved. [Task Time = $(TimeSpan $SnapTime)]; Run time = [$(TimeSpan $alphaTime)]."
    }

    $TotalUsers = ($msolUserList.Count)

    # If user list is not empty, built the report.
    if ($msolUserList) {
        # Create empty placeholder for the final result.
        $Final_Result = [System.Collections.ArrayList]@()
        $SnapTime = Get-Date
        Write-Information "$(Get-Date) : Start checking MFA state."
        $userIndex = 0
        foreach ($msolUser in ($msolUserList | Sort-Object -Property UserPrincipalName) ) {
            $percentComplete = [math]::Round((($userIndex / $TotalUsers) * 100))
            Write-Progress -Activity "Checking user MFA details... $($msolUser.UserPrincipalName)" -Status "($userIndex of $TotalUsers) $percentComplete%" -PercentComplete $percentComplete

            # Check if user is a member of any role groups.
            $isAdmin = (($Admin_Users.ObjectID) -contains ($msolUser.ObjectID))
            $Admin_Role = if ($isAdmin) {
                ($Admin_Users | Where-Object { $_.ObjectID -eq ($msolUser.ObjectID) }).RoleGroup -join ';'
            }
            $MFA_Method = $(($msolUser.StrongAuthenticationMethods | Where-Object { $_.IsDefault }).MethodType)

            # Determine if MFA is enabled per user or via Conditional Access
            $User_MFA_State = $msolUser.StrongAuthenticationRequirements.State
            if ($User_MFA_State) {
                $MFA_Type = 'Per User'
                $MFA_Enabled = $true
            }
            elseif ($MFA_Method -and !$User_MFA_State) {
                $MFA_Type = 'Conditional Access'
                $MFA_Enabled = $true
            }
            else {
                $MFA_Type = $null
                $MFA_Enabled = $false
            }

            # Determine if user account is enabled
            $User_Enabled = $(
                if (($msolUser.BlockCredential) -eq $true) {
                    $false
                }
                else {
                    $true
                }
            )

            $newMFAUserObject = [PSCustomObject]@{
                PSTypeName           = "PS.AzAd.User.MFAState.$(($company_info.DisplayName) -replace ' ','_')"
                'User ID'            = $msolUser.UserPrincipalName
                'Display Name'       = $msolUser.DisplayName
                'User Enabled'       = ($User_Enabled -as [boolean])
                'Is Admin'           = ($isAdmin -as [boolean])
                'Admin Roles'        = $Admin_Role
                'Is Licensed'        = ($msolUser.IsLicensed -as [boolean])
                'MFA Enabled'        = ($MFA_Enabled -as [boolean])
                'MFA Type'           = $MFA_Type
                'Default MFA Method' = $MFA_Method
            }
            # Add user details to the final result.
            $null = $Final_Result.Add($newMFAUserObject)
            $userIndex++
        }
        Write-Information "$(Get-Date) : MFA status check done. [Task Time = $(TimeSpan $SnapTime)]; Run time = [$(TimeSpan $alphaTime)]."
        # Write-Information "$(Get-Date) : Total runtime = [$(TimeSpan $alphaTime)]."
        return $Final_Result
    }
}