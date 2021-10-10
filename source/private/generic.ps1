Function TimeSpan {
    param (
        [parameter(
            Mandatory,
            Position = 0
        )]
        [datetime]$Start
    )
    $([math]::Round(((New-TimeSpan -Start $Start -End (Get-Date)).TotalMinutes), 2) -as [string]) + "min"
}

Function ConvertTo-Hashtable {
    param([string]$key, $value)

    Begin {
        $hash = [ordered]@{}
    }
    Process {
        $thisKey = $_.$Key
        $hash.$thisKey = $_.$Value
    }
    End {
        $hash
    }
}

Function Get-ColorPalette {
    param()
    Get-Content -Path "$((Get-Module ((Get-Command Get-MFAState).Source)).ModuleBase)\resource\palette.txt"
}


