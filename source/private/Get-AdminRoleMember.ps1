Function Get-AdminRoleMember {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string[]]
        $RoleName
    )
    # Create empty array to hold the final result
    $Final_Result = @()

    if ($RoleName) {
        # Get selected admin roles
        $roles = Get-MsolRole | Where-Object { $RoleName -contains $_.Name } | Sort-Object -Property Name
    }
    else {
        # Get all admin role groups
        $roles = Get-MsolRole | Sort-Object -Property Name
    }

    foreach ($role in $roles) {
        # Get members of the role group
        $RoleMembers = @(Get-MsolRoleMember -RoleObjectId $($role.ObjectId) | Where-Object { $_.RoleMemberType -eq 'User' } | Select-Object ObjectID, EmailAddress, DisplayName)
        SayInfo "[$($role.Name)] members = $($RoleMembers.Count)."
        if ($RoleMembers) {
            # Add each role group member to the final result
            foreach ($member in $RoleMembers) {
                $Final_Result += (
                    $([PSCustomObject]@{
                            ObjectID     = $member.ObjectId
                            EmailAddress = $member.EmailAddress
                            DisplayName  = $member.DisplayName
                            RoleGroup    = $(if (($role.Name) -eq ("Company Administrator".Trim())) {'Global Administrator'} else {("$($role.Name)".Trim())})
                        })
                )
            }
        }
    }
    return $Final_Result
}