Import-Module PSMfaStateReport

# The directory where you want to save the report files. Make sure you have write access to the directory.
$ReportDirectory = 'C:\temp\mfareport'

# Get the MFA data for all users and generate the report
Get-MFAState -AllUsers -InformationAction Continue | New-MFAReport -ReportDirectory $ReportDirectory -InformationAction Continue

# Send the MFA report via email
$mailProp = @{
    ReportDirectory = $ReportDirectory
    SmtpServer      = 'smtp.server.here'
    Port            = '25'
    From            = 'Sender name <sender@domain.com>'
    To              = @('recipient1@domain.com', 'recipient2@domain.com')
}
Send-MFAReport @mailProp