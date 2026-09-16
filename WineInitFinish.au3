#include-once

; UNSAFE ON WINE. Previously mirrored Core_Initialize bind + Assembler_ModifyMemory
; (VirtualAllocEx, WriteProcessMemory, JMP detours into Gw.exe). That path crashed
; Gw.exe under wine-gw. Wine attach must not call this.
Func Wine_FinishCoreInitialize($a_b_ChangeTitle = False)
	#forceref $a_b_ChangeTitle
	Out("Wine_FinishCoreInitialize is disabled: it writes engine hooks into Gw.exe.")
	Return SetError(1, 0, 0)
EndFunc
