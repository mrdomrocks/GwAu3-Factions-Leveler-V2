#include-once

; Wine / Linux (wine-gw prefix) compatibility helpers for attach + GUI.
; Native Windows stays on the same code paths unless ForceWineCompat=1.
;
; The patched GwAu3 API (GwAu3_Core_Scanner.au3 / GwAu3_Core.au3) reads:
;   $g_b_IsWine, $g_b_ForceWineCompat, $g_b_ScannerUseLocal, $g_i_ScannerTimeoutMs
; Set those before any Scanner_* / Core_Initialize call.
;
; Wine attach is READ-ONLY: 8-byte .text probe, then 4KB RPM for five critical
; patterns. No VirtualAllocEx, no WriteProcessMemory, no Assembler_ModifyMemory.

If Not IsDeclared("g_b_IsWine") Then Global $g_b_IsWine = False
If Not IsDeclared("g_b_WineChecked") Then Global $g_b_WineChecked = False
If Not IsDeclared("g_s_WineVersion") Then Global $g_s_WineVersion = ""
If Not IsDeclared("g_b_ForceWineCompat") Then Global $g_b_ForceWineCompat = False
If Not IsDeclared("g_b_ScannerUseLocal") Then Global $g_b_ScannerUseLocal = False
If Not IsDeclared("g_i_ScannerTimeoutMs") Then Global $g_i_ScannerTimeoutMs = 15000
If Not IsDeclared("g_b_SkipUpdater") Then Global $g_b_SkipUpdater = True
If Not IsDeclared("g_s_ResumeIni") Then Global $g_s_ResumeIni = @ScriptDir & "\Config\leveler.ini"
If Not IsDeclared("g_b_StartRequested") Then Global $g_b_StartRequested = False
If Not IsDeclared("g_b_WineReadOnlyAttach") Then Global $g_b_WineReadOnlyAttach = False

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

Func Wine_ClearScanCacheFlags()
	Local $asFlags[8] = [ _
			"g_b_LocalScanDone", "g_b_LocalScanRecorded", "g_b_TimedScanDone", _
			"g_b_TimedScanRecorded", "g_b_ScanSitesRecorded", "g_b_SkipCriticalRescan", _
			"g_i_LocalScanFound", "g_i_LocalScanHits"]
	Local $i = 0
	For $i = 0 To UBound($asFlags) - 1
		If IsDeclared($asFlags[$i]) Then Assign($asFlags[$i], 0, 2)
	Next
EndFunc

Func Wine_ResetScannerState()
	If IsDeclared("g_b_SectionsInitialized") Then $g_b_SectionsInitialized = False
	If IsDeclared("g_p_GwAu3Header") Then $g_p_GwAu3Header = 0
	If IsDeclared("g_p_GwAu3Scan") Then $g_p_GwAu3Scan = 0
	If IsDeclared("g_p_GwAu3Cmd") Then $g_p_GwAu3Cmd = 0
	If IsDeclared("g_ap_ScanResults") Then $g_ap_ScanResults = 0
	If IsDeclared("g_p_ASMMemory") Then $g_p_ASMMemory = 0
	$g_b_WineReadOnlyAttach = False
	Wine_ClearScanCacheFlags()
	If $g_h_GWProcess <> 0 Then Memory_Close()
EndFunc

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

Func Wine_ReadBytesHex($a_p_Addr, $a_i_Count)
	If $g_h_GWProcess = 0 Or $a_p_Addr = 0 Or $a_i_Count < 1 Then Return ""
	Local $dBuf = DllStructCreate("byte[" & $a_i_Count & "]")
	If @error Then Return ""
	Local $av = DllCall($g_h_Kernel32, "int", "ReadProcessMemory", _
			"int", $g_h_GWProcess, _
			"int", $a_p_Addr, _
			"ptr", DllStructGetPtr($dBuf), _
			"int", $a_i_Count, _
			"int", "")
	If @error Or Not IsArray($av) Or $av[0] = 0 Then Return ""
	Local $sHex = ""
	Local $k = 1
	For $k = 1 To $a_i_Count
		If $sHex <> "" Then $sHex &= " "
		$sHex &= Hex(DllStructGetData($dBuf, 1, $k), 2)
	Next
	Return $sHex
EndFunc

Func Wine_IsUserPtr($a_p)
	Local $p = BitAND(Number($a_p), 0xFFFFFFFF)
	If $p < 0x00400000 Then Return False
	If $p > 0x7FFEFFFF Then Return False
	Return True
EndFunc

Func Wine_TextFirst8Live()
	Local $pText0 = 0
	If IsDeclared("g_ai2_Sections") And IsArray($g_ai2_Sections) Then
		$pText0 = $g_ai2_Sections[$GC_I_SECTION_TEXT][0]
	EndIf
	If $pText0 = 0 Then Return False
	Local $sBytes = Wine_ReadBytesHex($pText0, 8)
	If $sBytes = "" Then Return False
	If StringReplace(StringReplace($sBytes, "00", ""), " ", "") = "" Then Return False
	Return True
EndFunc

Func Wine_ProbeGwMemory()
	Local $sHandle = "0"
	If IsDeclared("g_h_GWProcess") Then $sHandle = String($g_h_GWProcess)
	Local $pText0 = 0, $pText1 = 0
	If IsDeclared("g_ai2_Sections") And IsArray($g_ai2_Sections) Then
		$pText0 = $g_ai2_Sections[$GC_I_SECTION_TEXT][0]
		$pText1 = $g_ai2_Sections[$GC_I_SECTION_TEXT][1]
	EndIf
	Local $sBytes = ""
	If $g_h_GWProcess <> 0 And $pText0 <> 0 Then $sBytes = Wine_ReadBytesHex($pText0, 8)
	Out("Wine probe: handle=" & $sHandle & " text=" & Hex($pText0) & "-" & Hex($pText1) & _
			" size=" & ($pText1 - $pText0) & " first8=" & $sBytes)
EndFunc

Func Wine_EnsureGwOpen($a_i_Pid)
	If $a_i_Pid <= 0 Then $a_i_Pid = Number($g_i_GWProcessId)
	If $g_h_GWProcess = 0 Then
		If $a_i_Pid <= 0 Then Return False
		Memory_Open($a_i_Pid)
		$g_i_GWProcessId = $a_i_Pid
	EndIf
	If $g_h_GWProcess = 0 Then Return False
	If Not $g_b_SectionsInitialized Then
		If Not Scanner_InitializeSections() Then Return False
	EndIf
	Return True
EndFunc

; Open process, map PE sections (4KB header read), require live .text first8.
; No charname full-section RPM, no VirtualAllocEx, no writes.
Func Wine_PreparePid($a_i_Pid)
	$g_b_WineReadOnlyAttach = False
	If Not Wine_EnsureGwOpen($a_i_Pid) Then Return False
	If $g_h_GWWindow = 0 Or $g_h_GWWindow = "" Then
		$g_h_GWWindow = Wine_FindGwHwnd($a_i_Pid)
		If $g_h_GWWindow = 0 Then $g_h_GWWindow = Scanner_GetHwnd($a_i_Pid)
	EndIf
	Wine_ProbeGwMemory()
	If Not Wine_TextFirst8Live() Then
		Out("Wine: .text first8 is empty or unreadable; aborting before any further RPM.")
		Return False
	EndIf
	Wine_RegisterCriticalPatterns()
	Return ($g_h_GWProcess <> 0 And $g_amx2_Patterns[0][0] >= 1)
EndFunc

Func Wine_RegisterCriticalPatterns()
	Scanner_ClearPatterns()
	Scanner_AddPattern('BasePointer', '506A0F6A00FF35', 0x8, 'Ptr')
	Scanner_AddPattern('AgentBase', '8B0C9085C97419', -0x3, 'Ptr')
	Scanner_AddPattern('MyID', '83EC08568BF13B15', -0x3, 'Ptr')
	Scanner_AddPattern('Move', '558BEC83EC208D45F0', 0x1, 'Func')
	Scanner_AddPattern('Engine', '568B3085F67478EB038D4900D9460C', -0x22, 'Hook')
	Return $g_amx2_Patterns[0][0] >= 5
EndFunc

; Read-only 4KB scan of five critical patterns. Never writes into Gw.
Func Wine_TrySalvageInit($a_b_ChangeTitle = False)
	#forceref $a_b_ChangeTitle
	If Not Wine_EnsureGwOpen($g_i_GWProcessId) Then
		Out("Wine attach: no process handle")
		Return False
	EndIf
	If Not Wine_TextFirst8Live() Then
		Out("Wine attach: refusing scan; .text first8 is not live")
		Return False
	EndIf
	If Not IsArray($g_amx2_Patterns) Or $g_amx2_Patterns[0][0] < 1 Then
		Wine_RegisterCriticalPatterns()
	EndIf
	Local $aResults = Wine_ScanPatternsChunked()
	If Not IsArray($aResults) Then Return False
	If Not Wine_HasCriticalPatterns($aResults) Then
		Out("Wine attach: 4KB scan missed AgentBase/MyID/Engine/Move/BasePointer")
		Return False
	EndIf
	$g_ap_ScanResults = $aResults
	If Not Wine_BindReadOnly($aResults) Then Return False
	$g_b_WineReadOnlyAttach = True
	Return True
EndFunc

Func Wine_HasCriticalPatterns($aResults)
	If Not IsArray($aResults) Then Return False
	Local $asNeed[5] = ["ScanAgentBasePtr", "ScanMyIDPtr", "ScanEngineHook", "ScanMoveFunc", "ScanBasePointerPtr"]
	Local $sMiss = ""
	Local $n = 0
	For $n = 0 To 4
		Local $bOk = False
		Local $i = 1
		For $i = 1 To $g_amx2_Patterns[0][0]
			If $g_amx2_Patterns[$i][0] = $asNeed[$n] Then
				If $i <= $aResults[0] And $aResults[$i] <> 0 Then $bOk = True
				ExitLoop
			EndIf
		Next
		If Not $bOk Then $sMiss &= " " & $asNeed[$n]
	Next
	If $sMiss <> "" Then
		Out("Wine attach missing:" & $sMiss)
		Return False
	EndIf
	Return True
EndFunc

; Read a dword at site and site-1 (ASM off-by-one). Pick a user-space pointer.
; Reads only.
Func Wine_ReadLivePtr($a_p_Site)
	If $a_p_Site = 0 Then Return 0
	Local $d = 0
	For $d = 0 To 1
		Local $p = Memory_Read($a_p_Site - $d)
		If Wine_IsUserPtr($p) Then Return $p
	Next
	Return 0
EndFunc

Func Wine_BindReadOnly($aResults)
	Local $pBaseSite = Scanner_GetScanResult('BasePointer', $aResults, 'Ptr')
	Local $pAgentSite = Scanner_GetScanResult('AgentBase', $aResults, 'Ptr')
	Local $pMySite = Scanner_GetScanResult('MyID', $aResults, 'Ptr')
	Local $pMove = Scanner_GetScanResult('Move', $aResults, 'Func')
	Local $pEngine = Scanner_GetScanResult('Engine', $aResults, 'Hook')
	Out("Wine sites: BasePointer=" & Hex($pBaseSite) & " AgentBase=" & Hex($pAgentSite) & _
			" MyID=" & Hex($pMySite) & " Move=" & Hex($pMove) & " Engine=" & Hex($pEngine))

	$g_p_BasePointer = Wine_ReadLivePtr($pBaseSite)
	$g_p_AgentBase = Wine_ReadLivePtr($pAgentSite)
	$g_i_MyID = Wine_ReadLivePtr($pMySite)
	If $g_p_AgentBase <> 0 Then $g_i_MaxAgents = $g_p_AgentBase + 0x8

	Out("Wine deref: BasePointer=" & Hex($g_p_BasePointer) & " AgentBase=" & Hex($g_p_AgentBase) & _
			" MyIDPtr=" & Hex($g_i_MyID))

	If $g_p_BasePointer = 0 Or $g_p_AgentBase = 0 Then
		Out("Wine attach: deref did not look like a live user pointer; not writing anything.")
		Return False
	EndIf

	Memory_SetValue('BasePointer', Ptr($g_p_BasePointer))
	Memory_SetValue('AgentBase', Ptr($g_p_AgentBase))
	Memory_SetValue('MaxAgents', Ptr($g_i_MaxAgents))
	Memory_SetValue('MyID', Ptr($g_i_MyID))
	Return True
EndFunc

Func Wine_ScanPatternsChunked()
	Local $pStart = $g_ai2_Sections[$GC_I_SECTION_TEXT][0]
	Local $pEnd = $g_ai2_Sections[$GC_I_SECTION_TEXT][1]
	Local $iTextSize = $pEnd - $pStart
	Local $iCount = $g_amx2_Patterns[0][0]
	If $iTextSize <= 0 Or $iCount < 1 Or $g_h_GWProcess = 0 Then Return 0

	Local $aResults[$iCount + 1]
	$aResults[0] = $iCount
	Local $aBytes[$iCount + 1][64]
	Local $abWild[$iCount + 1][64]
	Local $aLen[$iCount + 1]
	Local $aOff[$iCount + 1]
	Local $aNeedle[$iCount + 1]
	Local $aNeedleAt[$iCount + 1]
	Local $iUsable = 0
	Local $iMaxPat = 1
	Local $i = 1
	For $i = 1 To $iCount
		$aResults[$i] = 0
		$aOff[$i] = Number($g_amx2_Patterns[$i][2])
		$aNeedle[$i] = ""
		$aNeedleAt[$i] = 0
		Local $sPat = StringStripWS(String($g_amx2_Patterns[$i][1]), 8)
		$sPat = StringReplace($sPat, "??", "00")
		$sPat = StringReplace($sPat, " ", "")
		If $sPat = "" Or StringRegExp($sPat, "[^0-9A-Fa-f]") Then
			$aLen[$i] = 0
			ContinueLoop
		EndIf
		If Mod(StringLen($sPat), 2) = 1 Then $sPat = "0" & $sPat
		Local $iLen = Int(StringLen($sPat) / 2)
		If $iLen > 63 Then $iLen = 63
		$aLen[$i] = $iLen
		If $iLen > $iMaxPat Then $iMaxPat = $iLen
		Local $b = 0
		For $b = 0 To $iLen - 1
			Local $iVal = Dec(StringMid($sPat, $b * 2 + 1, 2))
			$aBytes[$i][$b] = $iVal
			$abWild[$i][$b] = ($iVal = 0)
		Next
		Local $iBest = 0, $iBestAt = 0, $iRun = 0, $iRunAt = 0
		For $b = 0 To $iLen - 1
			If Not $abWild[$i][$b] Then
				If $iRun = 0 Then $iRunAt = $b
				$iRun += 1
				If $iRun > $iBest Then
					$iBest = $iRun
					$iBestAt = $iRunAt
				EndIf
			Else
				$iRun = 0
			EndIf
		Next
		If $iBest > 0 Then
			Local $sNeedle = ""
			Local $n = 0
			For $n = 0 To $iBest - 1
				$sNeedle &= Chr($aBytes[$i][$iBestAt + $n])
			Next
			$aNeedle[$i] = $sNeedle
			$aNeedleAt[$i] = $iBestAt
		EndIf
		$iUsable += 1
	Next

	Out("Wine 4KB scan: .text " & $iTextSize & " bytes, " & $iUsable & " critical patterns (read-only)")
	Local $hScan = TimerInit()
	Local $iChunk = 4096
	Local $iOverlap = $iMaxPat
	If $iOverlap < 32 Then $iOverlap = 32
	Local $p = $pStart
	Local $iFound = 0
	Local $iN = 0
	While $p < $pEnd And $iFound < $iUsable
		Local $iRead = $iChunk
		If $p + $iRead > $pEnd Then $iRead = $pEnd - $p
		If $iRead <= 0 Then ExitLoop
		Local $dBuf = DllStructCreate("byte[" & $iRead & "]")
		If @error Then ExitLoop
		Local $av = DllCall($g_h_Kernel32, "int", "ReadProcessMemory", _
				"int", $g_h_GWProcess, _
				"int", $p, _
				"ptr", DllStructGetPtr($dBuf), _
				"int", $iRead, _
				"int", "")
		If @error Or Not IsArray($av) Or $av[0] = 0 Then
			Out("Wine 4KB scan: ReadProcessMemory failed at " & Hex($p) & "; stopping.")
			ExitLoop
		EndIf
		Local $sHay = BinaryToString(DllStructGetData($dBuf, 1), 1)
		For $i = 1 To $iCount
			If $aResults[$i] <> 0 Or $aLen[$i] < 1 Or $aNeedle[$i] = "" Then ContinueLoop
			Local $iHit = Wine_MatchInHay($sHay, $i, $aBytes, $abWild, $aLen[$i], $aNeedle[$i], $aNeedleAt[$i])
			If $iHit >= 0 Then
				; Match start + AddPattern offset. BindReadOnly also tries site-1.
				$aResults[$i] = $p + $iHit + $aOff[$i]
				$iFound += 1
			EndIf
		Next
		$iN += 1
		If Mod($iN, 8) = 0 Then Sleep(1)
		If Mod($p - $pStart, 262144) < $iRead Then
			Out("Wine 4KB scan: " & ($p - $pStart + $iRead) & "/" & $iTextSize & " (" & $iFound & " hits)")
		EndIf
		If $p + $iRead >= $pEnd Then ExitLoop
		$p += $iRead - $iOverlap
		If $iOverlap >= $iRead Then ExitLoop
	WEnd
	Out("Wine 4KB scan: found " & $iFound & "/" & $iCount & " in " & Round(TimerDiff($hScan)) & " ms")
	Return $aResults
EndFunc

Func Wine_MatchInHay($sHay, $iPat, ByRef $aBytes, ByRef $abWild, $iPatLen, $sNeedle, $iNeedleAt)
	If $iPatLen < 1 Or $sNeedle = "" Then Return -1
	Local $iHay = StringLen($sHay)
	If $iHay < $iPatLen Then Return -1
	Local $iPos = 1
	While True
		$iPos = StringInStr($sHay, $sNeedle, 1, 1, $iPos)
		If $iPos = 0 Then Return -1
		Local $iHit = $iPos - 1 - $iNeedleAt
		If $iHit >= 0 And $iHit + $iPatLen <= $iHay Then
			Local $bOk = True
			Local $k = 0
			For $k = 0 To $iPatLen - 1
				If $abWild[$iPat][$k] Then ContinueLoop
				If Asc(StringMid($sHay, $iHit + $k + 1, 1)) <> $aBytes[$iPat][$k] Then
					$bOk = False
					ExitLoop
				EndIf
			Next
			If $bOk Then Return $iHit
		EndIf
		$iPos += 1
	WEnd
	Return -1
EndFunc
