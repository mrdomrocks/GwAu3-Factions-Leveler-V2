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
		; API local scan is per-byte and hard-capped at 20s (~0.5MB of 5.4MB), then
		; skips the injected rescan. Start uses Wine_PreparePid + chunked RPM instead.
		If $g_i_ScannerTimeoutMs < 20000 Then $g_i_ScannerTimeoutMs = 20000
		If IsDeclared("g_i_LocalScanTimeoutMs") Then $g_i_LocalScanTimeoutMs = 300000
		If IsDeclared("g_i_ScanTimeoutMs") Then $g_i_ScanTimeoutMs = 300000
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

; Timed-scan miss flags only. Does not Memory_Close() — salvage needs the handle.
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

; Clear cached 0/78 sites so a retry is allowed to scan again.
Func Wine_ResetScannerState()
	If IsDeclared("g_b_SectionsInitialized") Then $g_b_SectionsInitialized = False
	If IsDeclared("g_p_GwAu3Header") Then $g_p_GwAu3Header = 0
	If IsDeclared("g_p_GwAu3Scan") Then $g_p_GwAu3Scan = 0
	If IsDeclared("g_p_GwAu3Cmd") Then $g_p_GwAu3Cmd = 0
	If IsDeclared("g_ap_ScanResults") Then $g_ap_ScanResults = 0
	If IsDeclared("g_p_ASMMemory") Then $g_p_ASMMemory = 0
	Wine_ClearScanCacheFlags()
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

Func Wine_EnsureGwOpen($a_i_Pid)
	If $a_i_Pid <= 0 Then $a_i_Pid = Number($g_i_GWProcessId)
	If $g_h_GWProcess = 0 Then
		If $a_i_Pid <= 0 Then Return False
		Memory_Open($a_i_Pid)
		$g_i_GWProcessId = $a_i_Pid
		If IsDeclared("g_p_GwAu3Header") Then $g_p_GwAu3Header = 0
		If IsDeclared("g_p_GwAu3Scan") Then $g_p_GwAu3Scan = 0
		If IsDeclared("g_p_GwAu3Cmd") Then $g_p_GwAu3Cmd = 0
		If IsDeclared("g_p_ASMMemory") Then $g_p_ASMMemory = 0
	EndIf
	If $g_h_GWProcess = 0 Then Return False
	If Not $g_b_SectionsInitialized Then
		If Not Scanner_InitializeSections() Then Return False
	EndIf
	Return True
EndFunc

; Open Gw.exe, map .text, register Core patterns, allocate the GwAu3 header.
; Used so Start never waits on the API's 20s per-byte local scan.
Func Wine_PreparePid($a_i_Pid)
	If Not Wine_EnsureGwOpen($a_i_Pid) Then Return False
	Scanner_ScanForCharname()
	If $g_h_GWWindow = 0 Or $g_h_GWWindow = "" Then
		$g_h_GWWindow = Wine_FindGwHwnd($a_i_Pid)
		If $g_h_GWWindow = 0 Then $g_h_GWWindow = Scanner_GetHwnd($a_i_Pid)
	EndIf
	Wine_RegisterCorePatterns()
	Wine_ResolveAssertionPatterns()
	Wine_EnsureGwAu3Header()
	Return ($g_h_GWProcess <> 0 And $g_amx2_Patterns[0][0] >= 1)
EndFunc

Func Wine_EnsureGwAu3Header()
	If $g_p_GwAu3Header <> 0 Then Return True
	$g_p_GwAu3Header = Scanner_ScanForGwAu3()
	If $g_p_GwAu3Header <> 0 Then Return True
	Local $avAlloc = DllCall($g_h_Kernel32, "ptr", "VirtualAllocEx", _
			"handle", $g_h_GWProcess, _
			"ptr", 0, _
			"ulong_ptr", $GC_I_GWAU3_HEADER_SIZE, _
			"dword", 0x1000, _
			"dword", 0x40)
	If @error Or Not IsArray($avAlloc) Or $avAlloc[0] = 0 Then
		Out("Wine salvage: VirtualAllocEx for GwAu3 header failed")
		Return False
	EndIf
	$g_p_GwAu3Header = $avAlloc[0]
	Memory_WriteBinary($GC_S_GWAU3_HEADER_BIN, $g_p_GwAu3Header)
	Memory_Write($g_p_GwAu3Header + $GC_I_GWAU3_OFFSET_SCANPTR, 0)
	Memory_Write($g_p_GwAu3Header + $GC_I_GWAU3_OFFSET_CMDPTR, 0)
	Return True
EndFunc

; Mirror Core_Initialize's Scanner_AddPattern list so salvage can skip ScanAllPatterns.
Func Wine_RegisterCorePatterns()
	If IsArray($g_amx2_Patterns) And $g_amx2_Patterns[0][0] >= 50 Then Return True
	Scanner_ClearPatterns()
	Scanner_AddPattern('BasePointer', '506A0F6A00FF35', 0x8, 'Ptr')
	Scanner_AddPattern('Ping', '568B750889165E', -0x3, 'Ptr')
	Scanner_AddPattern('StatusCode', '8945088D45086A04', -0x10, 'Ptr')
	Scanner_AddPattern('Login', '83C420D955ECD955F0', 0x33, 'Ptr')
	Scanner_AddPattern('InGame', '8D7E388907', 0x4D, 'Ptr')
	Scanner_AddPattern('PacketSend', 'C747540000000081E6', -0x4F, 'Func')
	Scanner_AddPattern('PacketLocation', '83C40433C08BE55DC3A1', 0xB, 'Ptr')
	Scanner_AddPattern('Action', '8B7508578BF983FE09750C6877', -0x3, 'Func')
	Scanner_AddPattern('ActionBase', '8D1C87899DF4', -0x3, 'Ptr')
	Scanner_AddPattern('Environment', '6BC67C5E05', 0x6, 'Ptr')
	Scanner_AddPattern('PreGame', "P:\Code\Gw\Ui\UiPregame.cpp", "!s_scene", 'Ptr')
	Scanner_AddPattern('FrameArray', "P:\Code\Engine\Frame\FrMsg.cpp", "frame", 'Ptr')
	Scanner_AddPattern('SceneContext', 'D9E0D95DFC8B01', 0x0, 'Ptr')
	Scanner_AddPattern('SkillBase', '69C6A40000005E', 0x9, 'Ptr')
	Scanner_AddPattern('SkillTimer', 'FFD68B4DF08BD88B4708', -0x3, 'Ptr')
	Scanner_AddPattern('UseSkill', '85F6745B83FE1174', -0x127, 'Func')
	Scanner_AddPattern('UseHeroSkill', 'BA02000000B954080000', -0x59, 'Func')
	Scanner_AddPattern('FriendList', "P:\Code\Gw\Friend\FriendApi.cpp", "friendName && *friendName", 'Ptr')
	Scanner_AddPattern('PlayerStatus', '83FE037740FF24B50000000033C0', -0x25, 'Func')
	Scanner_AddPattern('AddFriend', '8B751083FE037465', -0x47, 'Func')
	Scanner_AddPattern('RemoveFriend', '83F803741D83F8047418', 0x0, 'Func')
	Scanner_AddPattern('AttributeInfo', 'BA3300000089088d4004', -0x3, 'Ptr')
	Scanner_AddPattern('IncreaseAttribute', '8B7D088B702C8B1F3B9E00050000', -0x5A, 'Func')
	Scanner_AddPattern('DecreaseAttribute', '8B8AA800000089480C5DC3CC', 0x19, 'Func')
	Scanner_AddPattern('Transaction', '85FF741D8B4D14EB08', -0x7E, 'Func')
	Scanner_AddPattern('BuyItemBase', 'D9EED9580CC74004', 0xF, 'Ptr')
	Scanner_AddPattern('RequestQuote', '8B752083FE107614', -0x34, 'Func')
	Scanner_AddPattern('Salvage', '33C58945FC8B45088945F08B450C8945F48B45108945F88D45EC506A10C745EC77', -0xA, 'Func')
	Scanner_AddPattern('SalvageGlobal', '8B4A04538945F48B4208', 0x1, 'Ptr')
	Scanner_AddPattern('InvCanIdentifyAll', '558BEC83EC??A1????????33C58945FC8D45??50E8????????8B45??83C40483F8FF????????000057', 0x1, 'Func')
	Scanner_AddPattern('InvIdentifyAll', '558BEC83EC??A1????????33C58945FC8D45??50E8????????8B45??83C40483F8FF????????000053', 0x1, 'Func')
	Scanner_AddPattern('InvCanDepositAllMaterials', '558BEC83EC??5733FF33C0538945FC568D4D??C745??000000005150', 0x1, 'Func')
	Scanner_AddPattern('InvDepositAllMaterials', '558BEC83EC??A1????????33C58945FC53565733FF897D??EB068D9B', 0x1, 'Func')
	Scanner_AddPattern('DropBundle', '8378480675058B4024EB0233C085C07405E8', 0x1, 'Ptr')
	Scanner_AddPattern('QueryPropIntersect', '558BEC83EC??535657E8????????8B40148B587C', 0x1, 'Func')
	Scanner_AddPattern('TradeSessOfferItem', 'C74204030000', -0x17, 'Func')
	Scanner_AddPattern('TradeSessSubmit', 'C74104070000', -0x14, 'Func')
	Scanner_AddPattern('TradeSessConfirm', 'C74604020000005E', -0x1e, 'Func')
	Scanner_AddPattern('TradeSessAbort', 'C7460401000000B8', -0x16, 'Func')
	Scanner_AddPattern('TradeSessRevokeItem', 'C746040500000089', -0x1d, 'Func')
	Scanner_AddPattern('TradeSessRevokeSubmit', 'C74604060000', -0x16, 'Func')
	Scanner_AddPattern('TradeSessRevokeConfirm', 'C7460404000000B8', -0x16, 'Func')
	Scanner_AddPattern('AgentBase', '8B0C9085C97419', -0x3, 'Ptr')
	Scanner_AddPattern('ChangeTarget', '3BDF0F95', -0x89, 'Func')
	Scanner_AddPattern('CurrentTarget', '83C4085F8BE55DC3CCCCCCCCCCCCCCCCCCCCCCCCCCCCCC55', -0xE, 'Ptr')
	Scanner_AddPattern('MyID', '83EC08568BF13B15', -0x3, 'Ptr')
	Scanner_AddPattern('Move', '558BEC83EC208D45F0', 0x1, 'Func')
	Scanner_AddPattern('ClickCoords', '8B451C85C0741CD945F8', 0xD, 'Ptr')
	Scanner_AddPattern('InstanceInfo', '6A2C50E80000000083C408C7', 0xE, 'Ptr')
	Scanner_AddPattern('WorldConst', '8D0476C1E00405', 0x8, 'Ptr')
	Scanner_AddPattern('Region', '6A548D46248908', -0x3, 'Ptr')
	Scanner_AddPattern('AreaInfo', '6BC67C5E05', 0x6, 'Ptr')
	Scanner_AddPattern('TradeCancel', 'C745FC01000000506A04', -0x6, 'Func')
	Scanner_AddPattern('UIMessage', 'B900000000E8000000005DC3894508', -0x14, 'Func')
	Scanner_AddPattern('CompassFlag', '8D451050566A5D57', 0x1, 'Func')
	Scanner_AddPattern('PartySearchButtonCallback', '8B450883EC08568BF18B480483F90E', -0x2, 'Func')
	Scanner_AddPattern('PartyWindowButtonCallback', '837d0800578bf97411', -0x2, 'Func')
	Scanner_AddPattern('EnterMission', '83C902890A5D', 0x24, 'Func')
	Scanner_AddPattern('SetDifficulty', '83C41C682A010010', 0x8C, 'Func')
	Scanner_AddPattern('Dialog', '894B248B4B2883E900', 0x16, 'Func')
	Scanner_AddPattern('Interact', '894B248B4B2883E900', 0x26, 'Func')
	Scanner_AddPattern('AiMode', '683A000010FF36', 0x1, 'Ptr')
	Scanner_AddPattern('HeroCommand', '33D268E001000068????????8D4A08', 0x1, 'Ptr')
	Scanner_AddPattern('HeroSkills', '8B4E04505185FF', 0x1, 'Ptr')
	Scanner_AddPattern('PlayerAdd', "P:\Code\Gw\Ui\Game\Party\PtInvite.cpp", "m_invitePlayerId", 'Ptr')
	Scanner_AddPattern('PlayerKick', "P:\Code\Gw\Ui\Game\Party\PtUtil.cpp", "playerId == MissionCliGetPlayerId()", 'Ptr')
	Scanner_AddPattern('PartyInvitations', '8B7D0C8BF083C4048B4704', 0x1, 'Ptr')
	Scanner_AddPattern('ActiveQuest', '8B45083B46040F842D010000', 0x1, 'Ptr')
	Scanner_AddPattern('Engine', '568B3085F67478EB038D4900D9460C', -0x22, 'Hook')
	Scanner_AddPattern('Render', 'F6C401741C68', -0x68, 'Hook')
	Scanner_AddPattern('LoadFinished', '2BD9C1E303', 0xA0, 'Hook')
	Scanner_AddPattern('Trader', '8D4DFC51576A5650', -0x3C, 'Hook')
	Scanner_AddPattern('TradePartner', '6A008D45F8C745F80100000050686501000089', -0xC, 'Hook')
	Scanner_AddPattern('ValidateAsyncDecodeStr', "P:\Code\Engine\Text\TextApi.cpp", "codedString", 'Func')
	If IsDeclared("g_b_AddPattern") Then Extend_AddPattern()
	Return $g_amx2_Patterns[0][0] >= 1
EndFunc

Func Wine_ResolveAssertionPatterns()
	If Not IsArray($g_amx2_AssertionPatterns) Then Return
	If UBound($g_amx2_AssertionPatterns) < 1 Then Return
	Local $asHex = Scanner_GetMultipleAssertionPatterns($g_amx2_AssertionPatterns)
	If Not IsArray($asHex) Then Return
	Local $iAssert = 0
	Local $i = 1
	For $i = 1 To $g_amx2_Patterns[0][0]
		If Not $g_amx2_Patterns[$i][4] Then ContinueLoop
		If $iAssert < UBound($asHex) Then $g_amx2_Patterns[$i][1] = $asHex[$iAssert]
		$iAssert += 1
	Next
EndFunc

; Scan .text in RPM chunks and bind pointers. Skips the API 20s per-byte scan.
Func Wine_TrySalvageInit($a_b_ChangeTitle = False)
	If Not Wine_EnsureGwOpen($g_i_GWProcessId) Then
		Out("Wine salvage: no process handle")
		Return False
	EndIf
	If Not IsArray($g_amx2_Patterns) Or $g_amx2_Patterns[0][0] < 1 Then
		Wine_RegisterCorePatterns()
		Wine_ResolveAssertionPatterns()
	EndIf
	If Not IsArray($g_amx2_Patterns) Or $g_amx2_Patterns[0][0] < 1 Then
		Out("Wine salvage: no pattern table")
		Return False
	EndIf
	If Not Wine_EnsureGwAu3Header() Then
		Out("Wine salvage: GwAu3 header alloc failed")
		Return False
	EndIf
	Local $aResults = Wine_ScanPatternsChunked()
	If Not IsArray($aResults) Then Return False
	If Not Wine_HasCriticalPatterns($aResults) Then
		Out("Wine salvage: chunked scan missed AgentBase/MyID/Engine/Move/BasePointer")
		Return False
	EndIf
	$g_ap_ScanResults = $aResults
	Out("Wine salvage: AgentBase=" & Hex(Scanner_GetScanResult('AgentBase', $aResults, 'Ptr')) & _
			" MyID=" & Hex(Scanner_GetScanResult('MyID', $aResults, 'Ptr')) & _
			" Engine=" & Hex(Scanner_GetScanResult('Engine', $aResults, 'Hook')) & _
			" Move=" & Hex(Scanner_GetScanResult('Move', $aResults, 'Func')) & _
			" BasePointer=" & Hex(Scanner_GetScanResult('BasePointer', $aResults, 'Ptr')))
	Out("Wine salvage: binding pointers from chunked scan")
	Local $h = Wine_FinishCoreInitialize($a_b_ChangeTitle)
	Return Leveler_AttachLooksLive($h)
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
		Out("Wine salvage missing:" & $sMiss)
		Return False
	EndIf
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
	Local $aBytes[$iCount + 1][256]
	Local $abWild[$iCount + 1][256]
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
		If StringLeft($sPat, 2) = "0x" Or StringLeft($sPat, 2) = "0X" Then $sPat = StringTrimLeft($sPat, 2)
		If $sPat = "" Or StringRegExp($sPat, "[^0-9A-Fa-f]") Then
			$aLen[$i] = 0
			ContinueLoop
		EndIf
		If Mod(StringLen($sPat), 2) = 1 Then $sPat = "0" & $sPat
		Local $iLen = Int(StringLen($sPat) / 2)
		If $iLen > 255 Then $iLen = 255
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

	Out("Wine chunked scan: .text " & $iTextSize & " bytes, " & $iUsable & "/" & $iCount & " hex patterns")
	Local $hScan = TimerInit()
	Local $iChunk = 1048576
	Local $iOverlap = $iMaxPat
	If $iOverlap < 128 Then $iOverlap = 128
	Local $p = $pStart
	Local $iFound = 0
	Local $iFailSame = 0
	While $p < $pEnd And $iFound < $iUsable
		Local $iRead = $iChunk
		If $p + $iRead > $pEnd Then $iRead = $pEnd - $p
		If $iRead <= 0 Then ExitLoop
		Local $dBuf = DllStructCreate("byte[" & $iRead & "]")
		If @error Then
			If $iChunk > 65536 Then
				$iChunk = Int($iChunk / 4)
				Out("Wine chunked scan: buffer alloc failed, chunk=" & $iChunk)
				ContinueLoop
			EndIf
			Out("Wine chunked scan: buffer alloc failed at " & Hex($p))
			ExitLoop
		EndIf
		Local $av = DllCall($g_h_Kernel32, "int", "ReadProcessMemory", _
				"int", $g_h_GWProcess, _
				"int", $p, _
				"ptr", DllStructGetPtr($dBuf), _
				"int", $iRead, _
				"int", "")
		If @error Or Not IsArray($av) Or $av[0] = 0 Then
			If $iChunk > 65536 Then
				$iChunk = Int($iChunk / 4)
				$iFailSame += 1
				Out("Wine chunked scan: ReadProcessMemory failed at " & Hex($p) & ", chunk=" & $iChunk)
				If $iFailSame < 6 Then ContinueLoop
			EndIf
			Out("Wine chunked scan: ReadProcessMemory failed at " & Hex($p))
			ExitLoop
		EndIf
		$iFailSame = 0
		Local $sHay = BinaryToString(DllStructGetData($dBuf, 1), 1)
		For $i = 1 To $iCount
			If $aResults[$i] <> 0 Or $aLen[$i] < 1 Or $aNeedle[$i] = "" Then ContinueLoop
			Local $iHit = Wine_MatchInHay($sHay, $i, $aBytes, $abWild, $aLen[$i], $aNeedle[$i], $aNeedleAt[$i])
			If $iHit >= 0 Then
				; Match ASM GetScannedAddress: (last-byte) - size + offset = P - 1 + offset
				$aResults[$i] = $p + $iHit - 1 + $aOff[$i]
				$iFound += 1
			EndIf
		Next
		If Mod($p - $pStart, 1048576) < $iRead Then
			Out("Wine chunked scan: " & ($p - $pStart + $iRead) & "/" & $iTextSize & " (" & $iFound & " hits)")
		EndIf
		If $p + $iRead >= $pEnd Then ExitLoop
		$p += $iRead - $iOverlap
		If $iOverlap >= $iRead Then ExitLoop
	WEnd
	Out("Wine chunked scan: found " & $iFound & "/" & $iCount & " in " & Round(TimerDiff($hScan)) & " ms")
	Local $sMiss = ""
	For $i = 1 To $iCount
		If $aResults[$i] = 0 And $aLen[$i] > 0 Then $sMiss &= " " & $g_amx2_Patterns[$i][0]
	Next
	If $sMiss <> "" Then Out("Wine chunked scan missed:" & $sMiss)
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
