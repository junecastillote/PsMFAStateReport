[CmdletBinding()]
param (
    [string]$ModulePath
)
$moduleManifest = Get-ChildItem -Path $PSScriptRoot -Filter *.psd1
$Moduleinfo = Test-ModuleManifest -Path ($moduleManifest.FullName)

Remove-Module ($Moduleinfo.Name) -ErrorAction SilentlyContinue

if (!$ModulePath) {
    # Get all PSModulePath
    $paths = ($env:PSModulePath -split ";")

    do {
        Clear-Host
        # Display selection menu
        Write-Output "====== Module Install Location ======"
        Write-Output ""
        $i = 1
        $paths | ForEach-Object {
            Write-Output "$($i): $_"
            $i = $i + 1
        }
        Write-Output "Q: QUIT"
        Write-Output ""
        # AS for input
        $userInput = Read-Host "Select the installation path"
    }
    until ($userInput -eq 'Q' -or ($userInput -lt ($paths.count + 1) -and $userInput -gt 0))

    if ($userInput -eq 'Q') {
        Write-Output ""
        Write-Output "QUIT"
        Write-Output ""
        return $null
    }
    $ModulePath = $paths[($userInput - 1)]
}
$ModulePath = $ModulePath + "\$($Moduleinfo.Name.ToString())\$($Moduleinfo.Version.ToString())"

if (!(Test-Path $ModulePath)) {
    try {
        $null = New-Item -Path $ModulePath -ItemType Directory -Force -ErrorAction stop
    }
    catch {
        Write-Output ""
        Write-Output "Failed"
        Write-Output $_.Exception.Message
        Write-Output ""
        return $null
    }
}

try {
    Copy-Item -Path $PSScriptRoot\* -Include *.psd1, *.psm1 -Destination $ModulePath -Force -Confirm:$false -ErrorAction Stop
    Copy-Item -Path $PSScriptRoot\source -Recurse -Destination $ModulePath -Force -Confirm:$false -ErrorAction Stop
    Copy-Item -Path $PSScriptRoot\resource -Recurse -Destination $ModulePath -Force -Confirm:$false -ErrorAction Stop
    Write-Output ""
    Write-Output "Success. Installed to $ModulePath"
    Write-Output ""
    Get-ChildItem -Recurse $ModulePath | Unblock-File -Confirm:$false
}
catch {
    Write-Output ""
    Write-Output "Failed"
    Write-Output $_.Exception.Message
    Write-Output ""
    return $null
}
