# Signing a PowerShell Script Before Emailing It

This guide creates a personal code-signing certificate, signs a PowerShell script, exports only the public certificate, and verifies/trusts the script after receiving it by email.

The procedure is appropriate for your own machines and Windows user profiles. A self-signed certificate proves that the script has not changed since **you** signed it, but it is not publicly trusted. For distribution to other people, use an organization-issued or commercial code-signing certificate.

> [!IMPORTANT]
> Sign the script only after its final edit. Any modification after signing, including whitespace changes, invalidates its Authenticode signature.

## Prerequisites

- Windows PowerShell 5.1 or PowerShell 7 running on Windows.
- Your completed script, for example `install-qompass-msys2.ps1`.
- The script is saved locally before signing.

Open PowerShell and confirm the script exists:

```powershell
$scriptPath = 'C:\Users\phaedrus\Scripts\install-qompass-msys2.ps1'
Test-Path -LiteralPath $scriptPath -PathType Leaf
```

Expected output:

```text
True
```

## Step 1: Create a personal code-signing certificate

Run this once on the Windows account that will sign scripts:

```powershell
$params = @{
    Subject           = 'CN=Qompass AI Personal PowerShell Code Signing'
    Type              = 'CodeSigningCert'
    CertStoreLocation = 'Cert:\CurrentUser\My'
    KeyAlgorithm      = 'RSA'
    KeyLength         = 3072
    HashAlgorithm     = 'SHA256'
    KeyExportPolicy   = 'NonExportable'
    NotAfter          = (Get-Date).AddYears(3)
}

$cert = New-SelfSignedCertificate @params
```

Inspect the certificate:

```powershell
$cert | Format-List `
    Subject,
    Thumbprint,
    NotBefore,
    NotAfter,
    HasPrivateKey,
    EnhancedKeyUsageList
```

Confirm the output includes both of these properties:

```text
HasPrivateKey         : True
EnhancedKeyUsageList  : Code Signing
```

The certificate and its private key are now stored in your Windows user certificate store:

```text
Cert:\CurrentUser\My
```

The private key is intentionally non-exportable. Keep it private and do not email a `.pfx`, `.p12`, or private-key file.

## Step 2: Find the certificate later

After opening a new PowerShell session, retrieve the signing certificate with:

```powershell
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert |
    Where-Object {
        $_.Subject -eq 'CN=Qompass AI Personal PowerShell Code Signing' -and
        $_.HasPrivateKey -and
        $_.NotAfter -gt (Get-Date)
    } |
    Sort-Object NotAfter -Descending |
    Select-Object -First 1

if (-not $cert) {
    throw 'No valid Qompass AI code-signing certificate with a private key was found.'
}

$cert | Format-List Subject, Thumbprint, NotAfter, HasPrivateKey
```

## Step 3: Test the script before signing

Perform your normal review and testing before adding a signature.

Parse the script without executing it:

```powershell
$scriptPath = 'C:\Users\phaedrus\Scripts\install-qompass-msys2.ps1'

[scriptblock]::Create(
    (Get-Content -LiteralPath $scriptPath -Raw)
) | Out-Null

'PowerShell syntax is valid.'
```

Run the non-destructive dry run from your script:

```powershell
& $scriptPath -Profile Dev -DryRun
```

For your MSYS2 installer, review that output carefully before signing. In particular, review package resolution, bootstrap behavior, installation targets, and PATH changes.

## Step 4: Sign the finalized script

Set the script path and retrieve the certificate:

```powershell
$scriptPath = 'C:\Users\phaedrus\Scripts\install-qompass-msys2.ps1'

$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert |
    Where-Object {
        $_.Subject -eq 'CN=Qompass AI Personal PowerShell Code Signing' -and
        $_.HasPrivateKey -and
        $_.NotAfter -gt (Get-Date)
    } |
    Sort-Object NotAfter -Descending |
    Select-Object -First 1

if (-not $cert) {
    throw 'No valid private signing certificate was found.'
}
```

Sign the script and request a trusted timestamp:

```powershell
Set-AuthenticodeSignature `
    -FilePath $scriptPath `
    -Certificate $cert `
    -TimestampServer 'http://timestamp.digicert.com'
```

A timestamp records that the signature existed while the certificate was valid. It is recommended, but a self-signed certificate still needs to be trusted on each receiving Windows profile.

## Step 5: Verify the signature locally

Immediately verify the exact file you are about to email:

```powershell
Get-AuthenticodeSignature -FilePath $scriptPath |
    Format-List `
        Status,
        StatusMessage,
        Path,
        SignerCertificate,
        TimeStamperCertificate
```

You want this result:

```text
Status : Valid
```

If it is not `Valid`, do not email or run the script as a trusted signed artifact.

## Step 6: Export the public certificate

Export the public certificate only:

```powershell
$certificatePath = 'C:\Users\phaedrus\Scripts\QompassAI-PowerShell-CodeSigning.cer'

Export-Certificate `
    -Cert $cert `
    -FilePath $certificatePath |
    Format-List FilePath, Thumbprint
```

You should now have these two files:

```text
C:\Users\phaedrus\Scripts\install-qompass-msys2.ps1
C:\Users\phaedrus\Scripts\QompassAI-PowerShell-CodeSigning.cer
```

## Step 7: Email the correct files

Email these files to yourself:

```text
install-qompass-msys2.ps1
QompassAI-PowerShell-CodeSigning.cer
```

It is also reasonable to put both into a ZIP archive before emailing:

```powershell
Compress-Archive `
    -Path `
        'C:\Users\phaedrus\Scripts\install-qompass-msys2.ps1',
        'C:\Users\phaedrus\Scripts\QompassAI-PowerShell-CodeSigning.cer' `
    -DestinationPath 'C:\Users\phaedrus\Scripts\qompass-msys2-signed.zip' `
    -Force
```

Do **not** email any private-key-bearing artifact:

```text
.pfx
.p12
.pem containing a private key
private-key.key
```

Do not email the contents of `Cert:\CurrentUser\My` as an exportable key backup. A recipient with your private key could create scripts that appear to be signed by you.

## Step 8: Receive the files safely

On the receiving Windows machine or user profile:

1. Save or extract both files into a local directory.
2. Import the `.cer` before attempting to run the script.
3. Verify the script signature.
4. Run the script with `-DryRun` first.

Example receiving directory:

```text
C:\Users\phaedrus\Downloads\qompass-msys2\
```

## Step 9: Trust your personal certificate

On the receiving Windows profile, open PowerShell and set the certificate path:

```powershell
$certificatePath = 'C:\Users\phaedrus\Downloads\qompass-msys2\QompassAI-PowerShell-CodeSigning.cer'

Test-Path -LiteralPath $certificatePath -PathType Leaf
```

Import the public certificate into the current user’s Root store:

```powershell
Import-Certificate `
    -FilePath $certificatePath `
    -CertStoreLocation 'Cert:\CurrentUser\Root'
```

Import it into the current user’s Trusted Publishers store:

```powershell
Import-Certificate `
    -FilePath $certificatePath `
    -CertStoreLocation 'Cert:\CurrentUser\TrustedPublisher'
```

No administrator session is required because these commands modify only the current user’s certificate stores.

Why both stores are used:

| Store | Purpose |
|---|---|
| `Cert:\CurrentUser\Root` | Trusts your self-signed certificate as its own root certificate authority |
| `Cert:\CurrentUser\TrustedPublisher` | Trusts the certificate as an approved PowerShell script publisher |

## Step 10: Verify the received script

On the receiving machine, verify before executing:

```powershell
$scriptPath = 'C:\Users\phaedrus\Downloads\qompass-msys2\install-qompass-msys2.ps1'

Get-AuthenticodeSignature -FilePath $scriptPath |
    Format-List `
        Status,
        StatusMessage,
        Path,
        SignerCertificate,
        TimeStamperCertificate
```

Only continue when the result includes:

```text
Status : Valid
```

## Step 11: Run the safe dry run first

Run the script’s dry-run profile first:

```powershell
& 'C:\Users\phaedrus\Downloads\qompass-msys2\install-qompass-msys2.ps1' `
    -Profile Dev `
    -DryRun
```

After reviewing the output, run the chosen real installation profile. For example:

```powershell
& 'C:\Users\phaedrus\Downloads\qompass-msys2\install-qompass-msys2.ps1' `
    -Profile Dev
```

Or, for the full package-discovery profile:

```powershell
& 'C:\Users\phaedrus\Downloads\qompass-msys2\install-qompass-msys2.ps1' `
    -Profile Full
```

## Signature status reference

| Signature status | Meaning | Action |
|---|---|---|
| `Valid` | The file has not changed since signing and the signer is trusted | You may proceed after reviewing what it does |
| `NotTrusted` | The file is signed, but the certificate is not trusted on this profile | Import the `.cer` into `Root` and `TrustedPublisher` |
| `HashMismatch` | The file contents changed after it was signed | Do not run it; obtain the original signed file again |
| `NotSigned` | The file has no Authenticode signature | Do not treat it as the signed artifact |
| `UnknownError` | Trust, certificate-chain, timestamp, or validation issue | Inspect `StatusMessage`; do not bypass it blindly |

## Re-sign after every edit

Any edit invalidates the signature. Follow this workflow every time:

```powershell
# 1. Edit the script.
notepad 'C:\Users\phaedrus\Scripts\install-qompass-msys2.ps1'

# 2. Check syntax.
[scriptblock]::Create(
    (Get-Content -LiteralPath 'C:\Users\phaedrus\Scripts\install-qompass-msys2.ps1' -Raw)
) | Out-Null

# 3. Test without changes.
& 'C:\Users\phaedrus\Scripts\install-qompass-msys2.ps1' -Profile Dev -DryRun

# 4. Sign the final version.
Set-AuthenticodeSignature `
    -FilePath 'C:\Users\phaedrus\Scripts\install-qompass-msys2.ps1' `
    -Certificate $cert `
    -TimestampServer 'http://timestamp.digicert.com'

# 5. Verify the exact file you will send.
Get-AuthenticodeSignature `
    -FilePath 'C:\Users\phaedrus\Scripts\install-qompass-msys2.ps1'
```

Never manually edit the signature block at the end of the script:

```text
# SIG # Begin signature block
...
# SIG # End signature block
```

## Optional reusable signing helper

Save this helper as:

```text
C:\Users\phaedrus\Scripts\sign-qompass-script.ps1
```

```powershell
#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $Path,

    [string] $Subject = 'CN=Qompass AI Personal PowerShell Code Signing',

    [string] $TimestampServer = 'http://timestamp.digicert.com'
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$resolvedPath = (Resolve-Path -LiteralPath $Path).Path

$certificate = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert |
    Where-Object {
        $_.Subject -eq $Subject -and
        $_.HasPrivateKey -and
        $_.NotAfter -gt (Get-Date)
    } |
    Sort-Object NotAfter -Descending |
    Select-Object -First 1

if (-not $certificate) {
    throw "No valid private code-signing certificate was found for subject: $Subject"
}

$signature = Set-AuthenticodeSignature `
    -FilePath $resolvedPath `
    -Certificate $certificate `
    -TimestampServer $TimestampServer

if ($signature.Status -ne 'Valid') {
    throw "Signing failed: $($signature.Status) - $($signature.StatusMessage)"
}

Get-AuthenticodeSignature -FilePath $resolvedPath |
    Format-List Status, StatusMessage, Path, SignerCertificate, TimeStamperCertificate
```

Use the helper:

```powershell
& 'C:\Users\phaedrus\Scripts\sign-qompass-script.ps1' `
    -Path 'C:\Users\phaedrus\Scripts\install-qompass-msys2.ps1'
```

## Execution-policy note

Do not use `-ExecutionPolicy Bypass` merely to run this script. A correctly trusted and validly signed script should work with normal `RemoteSigned` policy. `AllSigned` is stricter and requires every script to be signed by a trusted publisher.

Inspect the current effective execution-policy list:

```powershell
Get-ExecutionPolicy -List
```

If the received script is signed and reports `Valid`, do not use `Unblock-File` as a shortcut. Trust and validate the signing certificate instead.

## Security checklist

Before sending:

- [ ] The script has completed its local dry run.
- [ ] The final script reports `Status : Valid`.
- [ ] You exported a `.cer` public certificate.
- [ ] You did not export or attach a `.pfx`, `.p12`, or private key.
- [ ] You did not edit the script after signing.

Before running on the receiving machine:

- [ ] The public `.cer` is imported into `CurrentUser\Root`.
- [ ] The public `.cer` is imported into `CurrentUser\TrustedPublisher`.
- [ ] `Get-AuthenticodeSignature` reports `Status : Valid`.
- [ ] You ran the installer with `-DryRun` before a real install.
