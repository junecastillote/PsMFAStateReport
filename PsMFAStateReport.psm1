# $Path = [System.IO.Path]::Combine($PSScriptRoot, 'source\public')
# $Path = [System.IO.Path]::Combine($PSScriptRoot, 'source')
Get-ChildItem "$($PSScriptRoot)\source" -Filter *.ps1 -Recurse | ForEach-Object {
    . $_.Fullname
}
