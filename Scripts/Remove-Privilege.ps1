﻿Function Remove-Privilege {
    [cmdletbinding()]
    Param (
        [parameter(Mandatory=$True)]
        [string]$AccountName,
        [parameter(Mandatory=$True)]
        [Privileges[]]$Privilege
    )
   #region Main

    #region SID Information
    Write-Verbose "Gathering SID information"
    $AccountSID = ([System.Security.Principal.NTAccount]$AccountName).Translate([System.Security.Principal.SecurityIdentifier])
    $ByteBuffer = New-Object Byte[] -ArgumentList $AccountSID.BinaryLength
    $AccountSID.GetBinaryForm($ByteBuffer,0)
    $SIDPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($AccountSID.BinaryLength)
    [System.Runtime.InteropServices.Marshal]::Copy(
        $ByteBuffer, 
        0, 
        $SIDPtr, 
        $AccountSID.BinaryLength
    )
    #endregion SID Information

    #region LsaOpenPolicy
    $Computer = New-Object LSA_UNICODE_STRING
    $Computer.Buffer = $env:COMPUTERNAME
    $Computer.Length = ($Computer.buffer.length * [System.Text.UnicodeEncoding]::CharSize)
    $Computer.MaximumLength = (($Computer.buffer.length+1) * [System.Text.UnicodeEncoding]::CharSize)
    $PolicyHandle = [intptr]::Zero
    $ObjectAttributes = New-Object LSA_OBJECT_ATTRIBUTES
    [uint32]$Access = [LSA_AccessPolicy]::POLICY_CREATE_ACCOUNT -BOR [LSA_AccessPolicy]::POLICY_LOOKUP_NAMES
    Write-Verbose "Opening policy handle"
    $NTStatus = [PoShPrivilege]::LsaOpenPolicy(
        [ref]$Computer,
        [ref]$ObjectAttributes,
        $Access,
        [ref]$PolicyHandle
    )

    #region winErrorCode
    If ($NTStatus -ne 0) {
        $Win32ErrorCode = [PoShPrivilege]::LsaNtStatusToWinError($return)
        Write-Warning $(New-Object System.ComponentModel.Win32Exception -ArgumentList $Win32ErrorCode)
        BREAK
    }
    #endregion winErrorCode
    #endregion LsaOpenPolicy

    #region LsaAddAccountRights
    ForEach ($Priv in $Privilege) {
        $UserRights = New-Object LSA_UNICODE_STRING[] -ArgumentList 1
        $PrivilegeName = [privileges]::$Priv
        $_UserRights = New-Object LSA_UNICODE_STRING
        $_UserRights.Buffer = $Priv.ToString()
        $_UserRights.Length = ($_UserRights.Buffer.length * ([System.Runtime.InteropServices.Marshal]::SizeOf([type][char])))
        $_UserRights.MaximumLength = ($_UserRights.Length + ([System.Runtime.InteropServices.Marshal]::SizeOf([type][char])))        
        $UserRights[0] = $_UserRights
        Write-Verbose "Removing Privilege: $($PrivilegeName.ToString())"
        $NTStatus = [PoShPrivilege]::LsaRemoveAccountRights(
            $PolicyHandle,
            $SIDPtr,
            $True,
            $UserRights,
            1    
        )

        #region winErrorCode
        If ($NTStatus -ne 0) {
            $Win32ErrorCode = [PoShPrivilege]::LsaNtStatusToWinError($return)
            Write-Warning $(New-Object System.ComponentModel.Win32Exception -ArgumentList $Win32ErrorCode)
            BREAK
        }
    }
    #endregion winErrorCode

    #endregion LsaAddAccountRights

    #region Cleanup
    
    #region Close Policy Handle
    Write-Verbose "Closing policy handle"
    [void][PoShPrivilege]::LsaClose($PolicyHandle)
    #endregion Close Policy Handle

    #region Clear Pointers
    Write-Verbose "Clearing SID pointers"
    [void][System.Runtime.InteropServices.Marshal]::FreeHGlobal($SIDPtr)
    #endregion Clear Pointers

    #endregion Cleanup
    #endregion Main
}