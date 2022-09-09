Function Send-MFAReport {
    [cmdletbinding()]
    param (
        [parameter(Mandatory)]
        [string]
        $SmtpServer,

        [parameter()]
        [int]
        $Port = 25,

        [parameter()]
        [pscredential]
        $Credential,

        [parameter()]
        [switch]
        $UseSSL,

        [parameter(Mandatory)]
        [string]
        $From,

        [parameter(Mandatory)]
        [string[]]
        $To,

        [parameter()]
        [string[]]
        $Cc,

        [parameter()]
        [string[]]
        $Bcc,

        [parameter(Mandatory)]
        [string]
        $ReportDirectory,

        [parameter()]
        [boolean]
        $AttachCSV = $true,

        [parameter()]
        [int]
        $ZipCsvSizeinMB = 2
    )

    try {
        $ReportDirectory = "$(Resolve-Path $ReportDirectory -ErrorAction STOP)"
    }
    catch {
        Write-Warning "Error resolving the ReportDirectory path. Make sure that the folder exist and it contains the report files."
        Write-Warning $_.Exception.Message
        return $null
    }

    # Compose Message

    $MailMessage = [System.Net.Mail.MailMessage]::New()

    # $MailMessage.Headers.Add('X-Mailer','PsMFAStateReport')

    $MailMessage.IsBodyHtml = $true

    # Replace the image source paths to content id
    try {
        $mailBody = (Get-Content "$($ReportDirectory)\MFA_State_Report.html" -Raw -ErrorAction Stop).Replace('src="','src="cid:')
    }
    catch {
        Write-Warning "$($_.Exception.Message) Abort send."
        return $null
    }


    if (!$AttachCSV) {
        $mailBody = $mailBody.Replace(
            '<td class="SubHeader1">*See the included CSV file for the details.</td>',
            ''
            )
    }

    $MailMessage.Body = ($mailBody)

    # Insert the email subject
    $MailMessage.Subject = (((Get-Content "$($ReportDirectory)\MFA_State_Report.html")[2]).Replace('<title>','').Replace('</title>',''))

    # Set the From and Reply-To addresses
    $MailMessage.From = $From
    $MailMessage.ReplyTo = $From

    # Add all the To recipients
    $To | ForEach-Object {
        $MailMessage.To.Add($_)
    }

    # Add all the Cc recipients
    if ($Cc) {
        $Cc | ForEach-Object {
            $MailMessage.Cc.Add($_)
        }
    }

    # Add all the Bcc recipients
    if ($Bcc) {
        $Bcc | ForEach-Object {
            $MailMessage.Bcc.Add($_)
        }
    }

    Get-ChildItem "$($ReportDirectory)\*" -Include "MFA_Chart*.png","MFA_icon*.png" | ForEach-Object {
        $Attachment = [System.Net.Mail.Attachment]::New(($_.FullName).ToString())
        if ($_.Name -like "*.png") {
            $Attachment.ContentDisposition.Inline = $true
            $Attachment.ContentDisposition.DispositionType = 'Inline'
            $Attachment.ContentType.MediaType = 'image/png'
            $Attachment.ContentId = $_.Name
        }
        $MailMessage.Attachments.Add($Attachment)
    }

    if ($AttachCSV) {
        $csvSizeInMB = [int]((Get-ChildItem "$($ReportDirectory)\MFA_State_Details.csv").Length / 1MB)
        if ($csvSizeInMB -ge $ZipCsvSizeinMB) {
            Compress-Archive -Path "$($ReportDirectory)\MFA_State_Details.csv" -DestinationPath "$($ReportDirectory)\MFA_State_Details.zip" -Force
            $csvFile = "$($ReportDirectory)\MFA_State_Details.zip"
        }
        else {
            $csvFile = "$($ReportDirectory)\MFA_State_Details.csv"
        }
        $MailMessage.Attachments.Add([System.Net.Mail.Attachment]::New($csvFile))
    }

    # SMTP Client
    $MailServer = [System.Net.Mail.SmtpClient]::New()
    $MailServer.Host = $SmtpServer
    $MailServer.Port = $Port
    $MailServer.DeliveryMethod = 'Network'

    if ($Credential) {
        $MailServer.Credentials = $Credential
    }
    if ($UseSSL) {
        $MailServer.EnableSsl = $true
    }

    $MailServer.Send($MailMessage)
    $Attachment.Dispose()
    $MailMessage.Dispose()
}