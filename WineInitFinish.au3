#include-once

; UNSAFE ON WINE. Previously mirrored Core_Initialize bind + Assembler_ModifyMemory
; (VirtualAllocEx, WriteProcessMemory, five JMP detours into Gw.exe). That path
; crashed Gw.exe under wine-gw. Wine attach uses Wine_TryMinimalEngineHook instead
; (one RWX page, one Engine JMP). Do not call this.
Func Wine_FinishCoreInitialize($a_b_ChangeTitle = False)
	#forceref $a_b_ChangeTitle
	Out("Wine_FinishCoreInitialize is disabled: it plants five engine hooks into Gw.exe.")
	Return SetError(1, 0, 0)
EndFunc
