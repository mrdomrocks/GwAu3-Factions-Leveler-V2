#include-once

; Wine / Linux (wine-gw prefix) compatibility helpers for attach + GUI.
; Native Windows stays on the same code paths unless ForceWineCompat=1.
;
; The patched GwAu3 API (GwAu3_Core_Scanner.au3 / GwAu3_Core.au3) reads:
;   $g_b_IsWine, $g_b_ForceWineCompat, $g_b_ScannerUseLocal, $g_i_ScannerTimeoutMs
; Set those before any Scanner_* / Core_Initialize call.
;
; Wine attach is read-only first: 8-byte .text probe, then 4KB RPM for five
; critical patterns (AgentBase/MyID/Engine/Move/BasePointer). After that bind,
; Wine_TryMinimalEngineHook may VirtualAllocEx one RWX page and plant exactly
; one Engine JMP. It never calls Assembler_ModifyMemory and never plants the
; Render / LoadFinished / Trader / TradePartner detours.

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
If Not IsDeclared("g_b_WineMinimalHook") Then Global $g_b_WineMinimalHook = False
If Not IsDeclared("g_p_WineAsmAlloc") Then Global $g_p_WineAsmAlloc = 0

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
	If IsDeclared("g_amx2_Labels") Then
		ReDim $g_amx2_Labels[1][2]
		$g_amx2_Labels[0][0] = 0
	EndIf
	If IsDeclared("g_p_QueueBase") Then $g_p_QueueBase = 0
	If IsDeclared("g_i_QueueCounter") Then $g_i_QueueCounter = 0
	If IsDeclared("g_i_QueueSize") Then $g_i_QueueSize = 0
	If IsDeclared("g_p_MapIsLoaded") Then $g_p_MapIsLoaded = 0
	If IsDeclared("g_i_ASMSize") Then $g_i_ASMSize = 0
	If IsDeclared("g_i_ASMCodeOffset") Then $g_i_ASMCodeOffset = 0
	If IsDeclared("g_s_ASMCode") Then $g_s_ASMCode = ""
	$g_b_WineReadOnlyAttach = False
	$g_b_WineMinimalHook = False
	$g_p_WineAsmAlloc = 0
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
; No charname full-section RPM. Writes happen only later in Wine_TryMinimalEngineHook.
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
	If Not Wine_TryMinimalEngineHook($aResults) Then
		Out("Wine: single Engine JMP inject aborted; command queue not live. Render/LoadFinished/Trader/TradePartner JMPs were not planted.")
	EndIf
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

; Map_Move, Ui_Dialog, and Core_SendPacket all Core_Enqueue into $g_p_QueueBase.
; That buffer is VirtualAllocEx'd inside Gw and drained by a JMP at Engine.
; Read-only AgentBase/MyID is not a command path. QueueBase stays 0 on Wine.
Func Wine_CommandsReady()
	If Not IsDeclared("g_p_QueueBase") Then Return False
	If $g_p_QueueBase = 0 Then Return False
	If Not Wine_IsUserPtr($g_p_QueueBase) Then Return False
	Return True
EndFunc

Func Wine_LogCommandGap()
	Out("Wine command queue is not live (single Engine JMP inject did not succeed).")
	Out("Map_Move / Ui_Dialog / Core_SendPacket were not armed. Render/LoadFinished/Trader/TradePartner JMPs were not planted.")
EndFunc

; Extra 4KB needles for the inject only. First scan stays the proven five.
Func Wine_RegisterInjectPatterns()
	Scanner_AddPattern('PacketSend', 'C747540000000081E6', -0x4F, 'Func')
	Scanner_AddPattern('PacketLocation', '83C40433C08BE55DC3A1', 0xB, 'Ptr')
	Scanner_AddPattern('Dialog', '894B248B4B2883E900', 0x16, 'Func')
	Scanner_AddPattern('Interact', '894B248B4B2883E900', 0x26, 'Func')
	Scanner_AddPattern('InstanceInfo', '6A2C50E80000000083C408C7', 0xE, 'Ptr')
	Scanner_AddPattern('Region', '6A548D46248908', -0x3, 'Ptr')
EndFunc

Func Wine_CompactHex($a_s_Hex)
	Return StringUpper(StringReplace(StringStripWS(String($a_s_Hex), 8), " ", ""))
EndFunc

Func Wine_PatternMatchesHex($a_s_Hay, $a_s_Pat)
	Local $sHay = Wine_CompactHex($a_s_Hay)
	Local $sPat = Wine_CompactHex($a_s_Pat)
	If $sHay = "" Or $sPat = "" Then Return False
	If Mod(StringLen($sPat), 2) = 1 Then Return False
	If StringLen($sHay) < StringLen($sPat) Then Return False
	Local $i = 1
	For $i = 1 To StringLen($sPat) Step 2
		Local $sWant = StringMid($sPat, $i, 2)
		If $sWant = "00" Then ContinueLoop
		If StringMid($sHay, $i, 2) <> $sWant Then Return False
	Next
	Return True
EndFunc

Func Wine_ResolveFuncStart($a_p_Site)
	If $a_p_Site = 0 Then Return 0
	Local $aiOff[3] = [0, -1, 1]
	Local $i = 0
	For $i = 0 To 2
		Local $p = $a_p_Site + $aiOff[$i]
		If Wine_CompactHex(Wine_ReadBytesHex($p, 3)) = "558BEC" Then Return $p
	Next
	If Wine_IsUserPtr($a_p_Site) Then Return $a_p_Site
	Return 0
EndFunc

Func Wine_ResolveCallTarget($a_p_Site)
	If $a_p_Site = 0 Then Return 0
	Local $aiOff[3] = [0, -1, 1]
	Local $i = 0
	For $i = 0 To 2
		Local $p = $a_p_Site + $aiOff[$i]
		If Wine_CompactHex(Wine_ReadBytesHex($p, 1)) <> "E8" Then ContinueLoop
		Local $pT = Scanner_GetCallTargetAddress($p)
		If Wine_IsUserPtr($pT) Then Return $pT
	Next
	Return 0
EndFunc

Func Wine_FreeAsmAlloc($a_p)
	If $a_p = 0 Or $g_h_GWProcess = 0 Then Return
	DllCall($g_h_Kernel32, "bool", "VirtualFreeEx", "handle", $g_h_GWProcess, "ptr", $a_p, "ulong_ptr", 0, "dword", 0x8000)
EndFunc

Func Wine_InjectAbort($a_s_Reason, $a_p_Alloc = 0)
	Out("Wine inject abort: " & $a_s_Reason)
	If $a_p_Alloc <> 0 Then Wine_FreeAsmAlloc($a_p_Alloc)
	$g_p_WineAsmAlloc = 0
	$g_b_WineMinimalHook = False
	If IsDeclared("g_p_QueueBase") Then $g_p_QueueBase = 0
	Return False
EndFunc

; Verify Engine hook site: pattern 568B3085F67478... at candidate+0x22, and the
; 5 bytes at the candidate match the MainExit epilogue (8B EC D9 45 08).
; Try scan result, result-1, result+1 (Wine 4KB scan has no ASM P-1).
Func Wine_FindEngineHookSite($a_p_Engine)
	If $a_p_Engine = 0 Then Return 0
	Local Const $sPat = "568B3085F67478EB038D4900D9460C"
	Local Const $sEpi = "8BECD94508"
	Local $aiOff[3] = [0, -1, 1]
	Local $pPatOnly = 0
	Local $sPatFive = ""
	Local $i = 0
	For $i = 0 To 2
		Local $pCand = $a_p_Engine + $aiOff[$i]
		Local $sFive = Wine_ReadBytesHex($pCand, 5)
		Local $sAt22 = Wine_ReadBytesHex($pCand + 0x22, 15)
		Out("Wine Engine candidate " & Hex($pCand) & " d=" & $aiOff[$i] & " site5=" & $sFive & " +22=" & $sAt22)
		If Not Wine_PatternMatchesHex($sAt22, $sPat) Then ContinueLoop
		Local $sFiveC = Wine_CompactHex($sFive)
		If StringLeft($sFiveC, 2) = "E9" Then
			Out("Wine inject abort: Engine site already starts with E9 at " & Hex($pCand))
			Return 0
		EndIf
		If $sFiveC = $sEpi Then Return $pCand
		If $pPatOnly = 0 Then
			$pPatOnly = $pCand
			$sPatFive = $sFive
		EndIf
	Next
	If $pPatOnly <> 0 Then
		Out("Wine inject abort: Engine pattern matched at " & Hex($pPatOnly) & " but site 5 bytes are " & $sPatFive & " (expected 8B EC D9 45 08)")
		Return 0
	EndIf
	Out("Wine inject abort: Engine pattern 568B3085F67478... not found at result/result-1/result+1")
	Return 0
EndFunc

Func Wine_AssembleMinimalEngine()
	_('SavedIndex/4')
	_('QueueCounter/4')
	_('MapIsLoaded/4')
	_('QueueBase/' & (256 * 256))

	_('MainProc:')
	_('pushad')
	_('pushfd')
	_('RegularFlow:')
	_('mov eax,dword[QueueCounter]')
	_('mov ecx,eax')
	_('shl eax,8')
	_('add eax,QueueBase')
	_('mov ebx,dword[eax]')
	_('test ebx,ebx')
	_('jz MainExit')
	_('mov dword[SavedIndex],ecx')
	_('mov dword[eax],0')
	_('jmp ebx')

	_('CommandReturn:')
	_('mov ecx,dword[SavedIndex]')
	_('mov edx,dword[QueueCounter]')
	_('cmp edx,ecx')
	_('jnz MainExit')
	_('mov eax,ecx')
	_('inc eax')
	_('cmp eax,QueueSize')
	_('jnz MainSkipReset')
	_('xor eax,eax')
	_('MainSkipReset:')
	_('mov dword[QueueCounter],eax')

	_('MainExit:')
	_('popfd')
	_('popad')
	_('mov ebp,esp')
	_('fld st(0),dword[ebp+8]')
	_('ljmp MainReturn')

	_('CommandPacketSend:')
	_('lea edx,dword[eax+8]')
	_('push edx')
	_('mov ebx,dword[eax+4]')
	_('push ebx')
	_('mov eax,dword[PacketLocation]')
	_('push eax')
	_('call PacketSend')
	_('pop eax')
	_('pop ebx')
	_('pop edx')
	_('ljmp CommandReturn')

	_('CommandMove:')
	_('lea eax,dword[eax+4]')
	_('push eax')
	_('call Move')
	_('pop eax')
	_('ljmp CommandReturn')

	_('CommandDialog:')
	_('push dword[eax+4]')
	_('call Dialog')
	_('add esp,4')
	_('ljmp CommandReturn')

	_('CommandInteract:')
	_('push dword[eax+4]')
	_('call Interact')
	_('add esp,4')
	_('ljmp CommandReturn')
EndFunc

; After read-only bind: one RWX page for queue + Move/PacketSend/Dialog stubs,
; then exactly one Engine JMP. No Assembler_ModifyMemory. No five-JMP fallback.
Func Wine_TryMinimalEngineHook($a_ap_FirstResults)
	$g_b_WineMinimalHook = False
	If IsDeclared("g_p_QueueBase") Then $g_p_QueueBase = 0
	Out("Wine inject: resolving PacketSend/PacketLocation/Dialog/Interact (still read-only 4KB).")
	Wine_RegisterInjectPatterns()
	Local $aExtra = Wine_ScanPatternsChunked()
	If Not IsArray($aExtra) Then Return Wine_InjectAbort("extra 4KB scan failed")

	Local $pMove = Wine_ResolveFuncStart(Scanner_GetScanResult('Move', $a_ap_FirstResults, 'Func'))
	Local $pPacketSend = Wine_ResolveFuncStart(Scanner_GetScanResult('PacketSend', $aExtra, 'Func'))
	Local $pPacketLoc = Wine_ReadLivePtr(Scanner_GetScanResult('PacketLocation', $aExtra, 'Ptr'))
	Local $pDialog = Wine_ResolveCallTarget(Scanner_GetScanResult('Dialog', $aExtra, 'Func'))
	Local $pInteract = Wine_ResolveCallTarget(Scanner_GetScanResult('Interact', $aExtra, 'Func'))
	Local $pInst = Wine_ReadLivePtr(Scanner_GetScanResult('InstanceInfo', $aExtra, 'Ptr'))
	Local $pRegion = Wine_ReadLivePtr(Scanner_GetScanResult('Region', $aExtra, 'Ptr'))
	Out("Wine inject targets: Move=" & Hex($pMove) & " PacketSend=" & Hex($pPacketSend) & _
			" PacketLocation=" & Hex($pPacketLoc) & " Dialog=" & Hex($pDialog) & " Interact=" & Hex($pInteract))

	If $pMove = 0 Then Return Wine_InjectAbort("Move func not resolved")
	If $pPacketSend = 0 Then Return Wine_InjectAbort("PacketSend func not resolved")
	If $pPacketLoc = 0 Then Return Wine_InjectAbort("PacketLocation ptr not resolved")
	If $pDialog = 0 Then Return Wine_InjectAbort("Dialog call target not resolved")
	If $pInteract = 0 Then Return Wine_InjectAbort("Interact call target not resolved")

	If $pInst <> 0 Then
		$g_p_InstanceInfo = $pInst
		Memory_SetValue('InstanceInfo', Ptr($pInst))
		Out("Wine inject: InstanceInfo=" & Hex($pInst))
	Else
		Out("Wine inject: InstanceInfo not found (map-type reads may be wrong; not aborting inject)")
	EndIf
	If $pRegion <> 0 Then
		$g_p_Region = $pRegion
		Memory_SetValue('Region', Ptr($pRegion))
	EndIf

	Local $pEngine = Scanner_GetScanResult('Engine', $a_ap_FirstResults, 'Hook')
	Out("Wine Engine scan result=" & Hex($pEngine))
	Local $pHook = Wine_FindEngineHookSite($pEngine)
	If $pHook = 0 Then Return False

	Local $sBefore = Wine_ReadBytesHex($pHook, 5)
	Out("Wine Engine site before JMP: " & Hex($pHook) & " bytes=" & $sBefore)

	Memory_SetValue('Move', Ptr($pMove))
	Memory_SetValue('PacketSend', Ptr($pPacketSend))
	Memory_SetValue('PacketLocation', Ptr($pPacketLoc))
	Memory_SetValue('Dialog', Ptr($pDialog))
	Memory_SetValue('Interact', Ptr($pInteract))
	Memory_SetValue('MainStart', Ptr($pHook))
	Memory_SetValue('MainReturn', Ptr($pHook + 5))
	Memory_SetValue('QueueSize', 0x100)
	$g_p_PacketLocation = $pPacketLoc

	$g_i_ASMSize = 0
	$g_i_ASMCodeOffset = 0
	$g_s_ASMCode = ""
	Wine_AssembleMinimalEngine()
	Local $iAlloc = Int($g_i_ASMSize) + 0x1000
	If $iAlloc < 0x11000 Then $iAlloc = 0x11000
	Out("Wine inject: VirtualAllocEx " & $iAlloc & " bytes RWX for queue+stubs (ASMSize=" & Int($g_i_ASMSize) & ")")

	Local $avAlloc = DllCall($g_h_Kernel32, "ptr", "VirtualAllocEx", _
			"handle", $g_h_GWProcess, _
			"ptr", 0, _
			"ulong_ptr", $iAlloc, _
			"dword", 0x3000, _
			"dword", 0x40)
	If @error Or Not IsArray($avAlloc) Or $avAlloc[0] = 0 Then
		Return Wine_InjectAbort("VirtualAllocEx failed")
	EndIf
	Local $pAlloc = $avAlloc[0]
	If Not Wine_IsUserPtr($pAlloc) Then Return Wine_InjectAbort("VirtualAllocEx returned non-user ptr " & Hex($pAlloc), $pAlloc)
	$g_p_WineAsmAlloc = $pAlloc
	$g_p_ASMMemory = $pAlloc
	Out("Wine inject: Queue/ASM page at " & Hex($pAlloc))

	Assembler_CompleteASMCode()
	If $g_s_ASMCode = "" Then Return Wine_InjectAbort("Assembler_CompleteASMCode produced no bytes", $pAlloc)
	Memory_WriteBinary($g_s_ASMCode, $g_p_ASMMemory + $g_i_ASMCodeOffset)

	Local $pQueue = Memory_GetValue('QueueBase')
	Local $pMain = Memory_GetValue('MainProc')
	Local $pCmdMove = Memory_GetValue('CommandMove')
	Local $pCmdPkt = Memory_GetValue('CommandPacketSend')
	Local $pCmdDlg = Memory_GetValue('CommandDialog')
	If Not Wine_IsUserPtr($pQueue) Then Return Wine_InjectAbort("QueueBase label is not a user ptr", $pAlloc)
	If Not Wine_IsUserPtr($pMain) Then Return Wine_InjectAbort("MainProc label is not a user ptr", $pAlloc)
	If Not Wine_IsUserPtr($pCmdMove) Then Return Wine_InjectAbort("CommandMove label is not a user ptr", $pAlloc)
	If Not Wine_IsUserPtr($pCmdPkt) Then Return Wine_InjectAbort("CommandPacketSend label is not a user ptr", $pAlloc)
	If Not Wine_IsUserPtr($pCmdDlg) Then Return Wine_InjectAbort("CommandDialog label is not a user ptr", $pAlloc)
	Out("Wine inject: QueueBase=" & Hex($pQueue) & " MainProc=" & Hex($pMain))

	; Re-check site after writing the new page only (must still be original bytes).
	Local $sMid = Wine_ReadBytesHex($pHook, 5)
	If Wine_CompactHex($sMid) <> Wine_CompactHex($sBefore) Then
		Return Wine_InjectAbort("Engine site bytes changed before JMP (have " & $sMid & ", want " & $sBefore & ")", $pAlloc)
	EndIf
	If Not Wine_PatternMatchesHex(Wine_ReadBytesHex($pHook + 0x22, 15), "568B3085F67478EB038D4900D9460C") Then
		Return Wine_InjectAbort("Engine +0x22 pattern no longer matches; not planting JMP", $pAlloc)
	EndIf

	Memory_WriteDetour('MainStart', 'MainProc')
	Local $sAfter = Wine_ReadBytesHex($pHook, 5)
	Out("Wine Engine site after JMP: " & Hex($pHook) & " bytes=" & $sAfter)
	If StringLeft(Wine_CompactHex($sAfter), 2) <> "E9" Then
		If Wine_CompactHex($sBefore) <> "" Then Memory_WriteBinary(Wine_CompactHex($sBefore), $pHook)
		Return Wine_InjectAbort("JMP did not stick (after=" & $sAfter & "); restored original site bytes", $pAlloc)
	EndIf

	$g_p_SavedIndex = Memory_GetValue('SavedIndex')
	$g_p_MapIsLoaded = Memory_GetValue('MapIsLoaded')
	$g_i_QueueCounter = 0
	$g_i_QueueSize = 0x100 - 1
	$g_p_QueueBase = $pQueue
	DllStructSetData($g_d_Packet, 1, Memory_GetValue('CommandPacketSend'))
	DllStructSetData($g_d_InviteGuild, 1, Memory_GetValue('CommandPacketSend'))
	DllStructSetData($g_d_Move, 1, Memory_GetValue('CommandMove'))
	DllStructSetData($g_d_Dialog, 1, Memory_GetValue('CommandDialog'))
	DllStructSetData($g_d_Interact, 1, Memory_GetValue('CommandInteract'))
	$g_b_WineMinimalHook = True
	Out("Wine: single Engine JMP planted. QueueBase=" & Hex($g_p_QueueBase) & " MainStart=" & Hex($pHook) & " MainProc=" & Hex($pMain))
	Out("Wine: skipped Render/LoadFinished/Trader/TradePartner detours (not Assembler_ModifyMemory).")
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

	Out("Wine 4KB scan: .text " & $iTextSize & " bytes, " & $iUsable & " patterns (read-only)")
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
