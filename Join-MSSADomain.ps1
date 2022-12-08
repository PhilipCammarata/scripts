function Join-MSSADomain {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DomainName,

        [Parameter(Mandatory)]
        [string]$NetBiosName
    )

    Add-Computer -DomainName "mssa.cammarata.me" -Credential "pcammarata"
}

Join-MSSADomain
