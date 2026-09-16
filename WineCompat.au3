#include-once

; Wine / Linux (wine-gw prefix) compatibility helpers for attach + GUI.
; Native Windows stays on the same code paths unless ForceWineCompat=1.
;
; The patched GwAu3 API (GwAu3_Core_Scanner.au3 / GwAu3_Core.au3) reads:
;   $g_b_IsWine, $g_b_ForceWineCompat, $g_b_ScannerUseLocal, $g_i_ScannerTimeoutMs
; Set those before any Scanner_* / Core_Initialize call.

If Not IsDeclared("g_b_IsWine") Then Global $g_b_IsWine = False
If Not IsDeclared("g_b_WineChecked") Then Global $g_b_WineChecked = False
If Not IsDeclared("g_s_WineVersion") Then Global $g_s_WineVersion = ""
If Not IsDeclared("g_b_ForceWineCompat") Then Global $g_b_ForceWineCompat = False
If Not IsDeclared("g_b_ScannerUseLocal") Then Global $g_b_ScannerUseLocal = False
If Not IsDeclared("g_i_ScannerTimeoutMs") Then Global $g_i_ScannerTimeoutMs = 15000
If Not IsDeclared("g_b_SkipUpdater") Then Global $g_b_SkipUpdater = True
If Not IsDeclared("g_s_ResumeIni") Then Global $g_s_ResumeIni = @ScriptDir & "\Config\leveler.ini"
If Not IsDeclared("g_b_StartRequested") Then Global $g_b_StartRequested = False

Func Wine_IsWine()
	If $g_b_WineChecked Then Return $g_b_IsWine
	$g_b_WineChecked = True
	$g_b_IsWine = False

	If $g_b_ForceWineCompat Then
		$g_b_IsWine = True
		Return True
	EndIf

	Local $aVer = DllCall("ntdll.dll", "str", "wine_get_version")
	If Not @error And IsArray($aVer) And $aVer[0] <> "" Then
		$g_b_IsWine = True
		$g_s_WineVersion = $aVer[0]
		Return True
	EndIf

	RegRead("HKCU\Software\Wine", "")
	If Not @error Then
		$g_b_IsWine = True
		Return True
	EndIf

	If EnvGet("WINEPREFIX") <> "" Then
		$g_b_IsWine = True
		Return True
	EndIf

	Return False
EndFunc

Func Wine_LoadConfig()
	$g_b_ForceWineCompat = (IniRead($g_s_ResumeIni, "Wine", "ForceWineCompat", "0") = "1")
	$g_b_SkipUpdater = (IniRead($g_s_ResumeIni, "Wine", "SkipUpdater", "1") = "1")
	Local $iIniTimeout = Number(IniRead($g_s_ResumeIni, "Wine", "ScannerTimeoutMs", "0"))
	If $iIniTimeout >= 1000 Then
		$g_i_ScannerTimeoutMs = $iIniTimeout
	Else
		$g_i_ScannerTimeoutMs = 15000
	EndIf

	Wine_IsWine()

	If $g_b_SkipUpdater Or $g_b_IsWine Then
		If IsDeclared("g_b_AutoUpdate") Then $g_b_AutoUpdate = False
		If IsDeclared("g_b_Verbose") Then $g_b_Verbose = False
	EndIf

	If $g_b_IsWine Then
		$g_b_ScannerUseLocal = True
		If IsDeclared("g_b_AutoUpdate") Then $g_b_AutoUpdate = False
		If IsDeclared("g_b_Verbose") Then $g_b_Verbose = False
		; 15s is the old default, but the patched local scan then skips the
		; injected rescan after recording 0 sites. Floor so one pass of .text can finish.
		If $g_i_ScannerTimeoutMs < 60000 Then $g_i_ScannerTimeoutMs = 60000
	EndIf
EndFunc

Func Wine_ApplyRuntimeGuards()
	Wine_LoadConfig()
	If $g_b_SkipUpdater Or $g_b_IsWine Then
		If IsDeclared("g_b_AutoUpdate") Then $g_b_AutoUpdate = False
		If IsDeclared("g_b_Verbose") Then $g_b_Verbose = False
	EndIf
EndFunc

Func Wine_RuntimeLabel()
	If Wine_IsWine() Then
		If $g_s_WineVersion <> "" Then Return "Wine " & $g_s_WineVersion
		Return "Wine"
	EndIf
	If $g_b_ForceWineCompat Then Return "Wine-compat (forced)"
	Return "Windows"
EndFunc

; Clear cached 0/78 sites so a retry is allowed to scan again.
Func Wine_ResetScannerState()
	If IsDeclared("g_b_SectionsInitialized") Then $g_b_SectionsInitialized = False
	If IsDeclared("g_p_GwAu3Header") Then $g_p_GwAu3Header = 0
	If IsDeclared("g_p_GwAu3Scan") Then $g_p_GwAu3Scan = 0
	If IsDeclared("g_p_GwAu3Cmd") Then $g_p_GwAu3Cmd = 0
	If IsDeclared("g_ap_ScanResults") Then $g_ap_ScanResults = 0
	If IsDeclared("g_p_ASMMemory") Then $g_p_ASMMemory = 0
	Local $asFlags[8] = [ _
			"g_b_LocalScanDone", "g_b_LocalScanRecorded", "g_b_TimedScanDone", _
			"g_b_TimedScanRecorded", "g_b_ScanSitesRecorded", "g_b_SkipCriticalRescan", _
			"g_i_LocalScanFound", "g_i_LocalScanHits"]
	Local $i = 0
	For $i = 0 To UBound($asFlags) - 1
		If IsDeclared($asFlags[$i]) Then Assign($asFlags[$i], 0, 2)
	Next
	If $g_h_GWProcess <> 0 Then Memory_Close()
EndFunc

; Prefer the process that owns a Guild Wars window. ProcessList("gw.exe") PIDs
; are valid under Wine (even when small) but can disagree with WinGetProcess.
Func Wine_FindGwPid()
	Local $iWinPid = Wine_PidFromGwWindow()
	Local $aList = ProcessList("gw.exe")
	Local $iListPid = 0
	If Not @error And IsArray($aList) And $aList[0][0] >= 1 Then $iListPid = Number($aList[1][1])
	If $iListPid = 0 Then $iListPid = Number(ProcessExists("gw.exe"))

	If $iWinPid > 0 Then Return $iWinPid
	If $iListPid > 0 Then Return $iListPid
	Return 0
EndFunc

Func Wine_PidFromGwWindow()
	Local $aClassWins = WinList("[CLASS:" & $GC_S_CLASS_DX_WINDOW & "]")
	If IsArray($aClassWins) Then
		Local $i = 1
		For $i = 1 To $aClassWins[0][0]
			Local $iPid = Number(WinGetProcess($aClassWins[$i][1]))
			If $iPid > 0 Then Return $iPid
		Next
	EndIf

	Local $aWins = WinList()
	If Not IsArray($aWins) Then Return 0
	Local $j = 1
	For $j = 1 To $aWins[0][0]
		If $aWins[$j][0] = "" Then ContinueLoop
		If Not StringInStr($aWins[$j][0], "Guild Wars") Then ContinueLoop
		Local $iPid2 = Number(WinGetProcess($aWins[$j][1]))
		If $iPid2 > 0 Then Return $iPid2
	Next
	Return 0
EndFunc

Func Wine_FindGwHwnd($a_i_Pid)
	If $a_i_Pid <= 0 Then Return 0

	Local $aClassWins = WinList("[CLASS:" & $GC_S_CLASS_DX_WINDOW & "]")
	If IsArray($aClassWins) Then
		Local $i = 1
		For $i = 1 To $aClassWins[0][0]
			If WinGetProcess($aClassWins[$i][1]) = $a_i_Pid Then Return $aClassWins[$i][1]
		Next
	EndIf

	Local $aWins = WinList()
	If Not IsArray($aWins) Then Return 0
	Local $hAny = 0
	Local $j = 1
	For $j = 1 To $aWins[0][0]
		If $aWins[$j][0] = "" Then ContinueLoop
		If WinGetProcess($aWins[$j][1]) <> $a_i_Pid Then ContinueLoop
		If StringInStr($aWins[$j][0], "Guild Wars") Then Return $aWins[$j][1]
		If $hAny = 0 Then $hAny = $aWins[$j][1]
	Next
	Return $hAny
EndFunc

; After a failed Core_Initialize the process handle is often still open.
Func Wine_ProbeGwMemory()
	Local $sHandle = "0"
	If IsDeclared("g_h_GWProcess") Then $sHandle = String($g_h_GWProcess)
	Local $pText0 = 0, $pText1 = 0
	If IsDeclared("g_ai2_Sections") And IsArray($g_ai2_Sections) Then
		$pText0 = $g_ai2_Sections[$GC_I_SECTION_TEXT][0]
		$pText1 = $g_ai2_Sections[$GC_I_SECTION_TEXT][1]
	EndIf
	Local $sBytes = ""
	If $g_h_GWProcess <> 0 And $pText0 <> 0 Then
		Local $k = 0
		For $k = 0 To 7
			If $sBytes <> "" Then $sBytes &= " "
			$sBytes &= Hex(Memory_Read($pText0 + $k, "byte"), 2)
		Next
	EndIf
	Out("Wine probe: handle=" & $sHandle & " text=" & Hex($pText0) & "-" & Hex($pText1) & _
			" size=" & ($pText1 - $pText0) & " first8=" & $sBytes)
	Out("Wine probe: ScannerUseLocal=" & $g_b_ScannerUseLocal & " timeoutMs=" & $g_i_ScannerTimeoutMs & _
			" ForceWineCompat=" & $g_b_ForceWineCompat)
EndFunc
