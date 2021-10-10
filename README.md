# PsMFAStateReport - PowerShell Module
`PsMFAStateReport` is a PowerShell module you can use to retrieve and report the MFA registration status of your Azure AD users. This module generates a summary email showing several MFA-related statistics.

## Requirements

- [`MSOnline`](https://www.powershellgallery.com/packages/MSOnline) module. This module retrieves the Azure AD user details using the `Get-MsolUser` cmdlet.
- An admin account with atleast the [*User Administrator*](https://docs.microsoft.com/en-us/azure/active-directory/roles/permissions-reference#user-administrator) role assigned. This account is what you'll use to connect to Azure AD and is the required minimum to read MFA related user properties.

  > **REMINDER!!!** - ***If you plan to run this module unattended, such as with the Task Scheduler, your admin account should not be MFA-enabled.***

- An SMTP or mailbox account for sending the email report. Unless you have an SMTP relay that does not require and account to send external emails. In Microsoft 365, you could use a shared mailbox account as the sender mailbox.

## How to Install



