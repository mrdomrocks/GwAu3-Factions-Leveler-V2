#include-once

Func Leveler_CountModel($a_i_Model, $a_b_IncludeStorage = True)
	Local $l_i_Count = 0
	Local $l_av_Inv = Item_GetInventoryArray()
	If IsArray($l_av_Inv) Then
		For $i = 0 To UBound($l_av_Inv) - 1
			If $l_av_Inv[$i][$GC_I_INVENTORY_MODELID] = $a_i_Model Then
				$l_i_Count += $l_av_Inv[$i][$GC_I_INVENTORY_QUANTITY]
			EndIf
		Next
	EndIf
	If $a_b_IncludeStorage Then
		Local $l_av_Store = Item_GetStorageArray(True)
		If IsArray($l_av_Store) Then
			For $i = 0 To UBound($l_av_Store) - 1
				If $l_av_Store[$i][$GC_I_INVENTORY_MODELID] = $a_i_Model Then
					$l_i_Count += $l_av_Store[$i][$GC_I_INVENTORY_QUANTITY]
				EndIf
			Next
		EndIf
	EndIf
	Return $l_i_Count
EndFunc

Func Leveler_OwnsModel($a_i_Model)
	If $a_i_Model = 0 Then Return False
	If Leveler_IsModelEquipped($a_i_Model) Then Return True
	; Bags only. Item_FindItemByModelID also matches crafter-window listings.
	If Item_GetBagsItembyModelID($a_i_Model) <> 0 Then Return True
	Return False
EndFunc

Func Leveler_ArmorSetOwned($a_ai_Pieces)
	Local $i
	For $i = 0 To UBound($a_ai_Pieces) - 1
		If Not Leveler_OwnsModel($a_ai_Pieces[$i][0]) Then Return False
	Next
	Return True
EndFunc

Func Leveler_WaitForCrafterOffer($a_i_Model, $a_i_Timeout = 8000)
	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < $a_i_Timeout
		If $g_b_LevelerPaused Then Return False
		If Merchant_GetMerchantItemPtr($a_i_Model) <> 0 Then Return True
		Sleep(200)
	WEnd
	Out("[Craft] Crafter is not offering model " & $a_i_Model)
	Return False
EndFunc

Func Leveler_WaitForBagModel($a_i_Model, $a_i_Timeout = 6000)
	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < $a_i_Timeout
		If Item_GetBagsItembyModelID($a_i_Model) <> 0 Then Return True
		If Leveler_IsModelEquipped($a_i_Model) Then Return True
		Sleep(200)
	WEnd
	Return False
EndFunc

Func Leveler_WeaponSetHasModel($a_i_Model)
	If $a_i_Model = 0 Then Return False
	Local $l_as_Ptrs[8] = [ _
			"WeaponSet0WeaponPtr", "WeaponSet0OffhandPtr", _
			"WeaponSet1WeaponPtr", "WeaponSet1OffhandPtr", _
			"WeaponSet2WeaponPtr", "WeaponSet2OffhandPtr", _
			"WeaponSet3WeaponPtr", "WeaponSet3OffhandPtr" _
			]
	Local $i
	For $i = 0 To UBound($l_as_Ptrs) - 1
		If Item_GetInventoryInfo($l_as_Ptrs[$i]) = 0 Then ContinueLoop
		Local $l_s_ModelKey = StringReplace($l_as_Ptrs[$i], "Ptr", "ModelID")
		If Item_GetInventoryInfo($l_s_ModelKey) = $a_i_Model Then Return True
	Next
	Return False
EndFunc

; Worn items live in the EquippedItems bag, not in backpack flags.
Func Leveler_EquippedBagHasModel($a_i_Model)
	If $a_i_Model = 0 Then Return False
	Local $l_p_EqBag = Item_GetBagPtr($GC_I_INVENTORY_EQUIPPED_ITEMS)
	If $l_p_EqBag = 0 Then $l_p_EqBag = Item_GetInventoryInfo("EquippedItemsPtr")
	If $l_p_EqBag = 0 Then Return False

	Local $l_ap_Items = Item_GetBagItemArray($GC_I_INVENTORY_EQUIPPED_ITEMS)
	If IsArray($l_ap_Items) Then
		Local $i
		For $i = 1 To $l_ap_Items[0]
			If $l_ap_Items[$i] = 0 Then ContinueLoop
			If Memory_Read($l_ap_Items[$i] + 0x2C, "dword") = $a_i_Model Then Return True
		Next
	EndIf

	Local $l_i_Slot
	For $l_i_Slot = $GC_I_EQUIPMENT_SLOT_RIGHT_HAND To $GC_I_EQUIPMENT_SLOT_HANDS
		Local $l_p_Item = Item_GetItemBySlot($GC_I_INVENTORY_EQUIPPED_ITEMS, $l_i_Slot + 1)
		If $l_p_Item = 0 Then ContinueLoop
		If Memory_Read($l_p_Item + 0x2C, "dword") = $a_i_Model Then Return True
	Next

	Local $l_i_Item = Item_FindItemByModelID($a_i_Model)
	If $l_i_Item <> 0 Then
		Local $l_p_Item2 = Item_GetItemPtr($l_i_Item)
		If $l_p_Item2 <> 0 Then
			If Memory_Read($l_p_Item2 + 0x8, "ptr") = $l_p_EqBag Then Return True
			If Memory_Read($l_p_Item2 + 0xC, "ptr") = $l_p_EqBag Then Return True
		EndIf
	EndIf
	Return False
EndFunc

Func Leveler_IsModelEquipped($a_i_Model)
	If $a_i_Model = 0 Then Return False
	If Leveler_WeaponSetHasModel($a_i_Model) Then Return True
	If Leveler_EquippedBagHasModel($a_i_Model) Then Return True
	Return False
EndFunc

; Find the crafted item in bags and put it on. Do not equip crafter-window listings.
Func Leveler_EquipModel($a_i_Model)
	If Leveler_IsModelEquipped($a_i_Model) Then
		Out("[Craft] Model " & $a_i_Model & " is already equipped")
		Return True
	EndIf
	Local $l_i_Agent = Agent_ConvertID(-2)
	Local $i
	For $i = 1 To 8
		Local $l_i_Item = Item_GetBagsItembyModelID($a_i_Model)
		If $l_i_Item = 0 Then
			Sleep(400)
			ContinueLoop
		EndIf
		Out("[Craft] Equipping item " & $l_i_Item & " (model " & $a_i_Model & ")")
		Item_EquipItem($l_i_Item)
		Sleep(200)
		Ui_EquipItem($l_i_Item, $l_i_Agent)
		Sleep(800)
		If Leveler_IsModelEquipped($a_i_Model) Then
			Out("[Craft] Equipped model " & $a_i_Model)
			Return True
		EndIf
		If Item_GetBagsItembyModelID($a_i_Model) = 0 Then
			Out("[Craft] Model " & $a_i_Model & " left inventory bags after equip")
			Return True
		EndIf
	Next
	Out("[Craft] Failed to equip model " & $a_i_Model)
	Return False
EndFunc

Func Leveler_CraftAndEquipPiece($a_i_ItemID, $a_i_Gold, $a_ai_Mats)
	If Leveler_OwnsModel($a_i_ItemID) Then
		Out("[Craft] Already own piece " & $a_i_ItemID)
		Return Leveler_EquipModel($a_i_ItemID)
	EndIf
	Local $l_i_Gold = Item_GetInventoryInfo("GoldCharacter")
	If $l_i_Gold < $a_i_Gold Then
		Out("[Craft] Need " & $a_i_Gold & " gold, have " & $l_i_Gold & ". Withdrawing.")
		Item_WithdrawGold($a_i_Gold)
		Sleep(400)
		$l_i_Gold = Item_GetInventoryInfo("GoldCharacter")
		If $l_i_Gold < $a_i_Gold Then
			Out("[Craft] Still short of gold for piece " & $a_i_ItemID)
			Return False
		EndIf
	EndIf
	Out("[Craft] Crafting piece " & $a_i_ItemID & " for " & $a_i_Gold & " gold")
	If Not Merchant_CraftItem($a_i_ItemID, $a_i_Gold, $a_ai_Mats) Then
		Out("[Craft] Merchant_CraftItem failed for " & $a_i_ItemID)
		Return False
	EndIf
	If Not Leveler_WaitForBagModel($a_i_ItemID) Then
		Out("[Craft] Piece " & $a_i_ItemID & " did not appear in bags after craft")
		Return False
	EndIf
	Return Leveler_EquipModel($a_i_ItemID)
EndFunc

Func Leveler_EquipArmorPieces($a_ai_Pieces)
	Local $i
	For $i = 0 To UBound($a_ai_Pieces) - 1
		If Not Leveler_EquipModel($a_ai_Pieces[$i][0]) Then Return False
	Next
	Return True
EndFunc

Func Leveler_ArmorSetEquipped($a_ai_Pieces)
	Local $i
	For $i = 0 To UBound($a_ai_Pieces) - 1
		If Not Leveler_IsModelEquipped($a_ai_Pieces[$i][0]) Then Return False
	Next
	Return True
EndFunc

Func Leveler_BuyMaterialShortfall($a_i_Model, $a_i_Need)
	Local $l_i_Have = Leveler_CountModel($a_i_Model, True)
	Local $l_i_Short = $a_i_Need - $l_i_Have
	If $l_i_Short <= 0 Then
		Out("[Craft] Already have " & $l_i_Have & "x model " & $a_i_Model)
		Return True
	EndIf
	Out("[Craft] Buying " & $l_i_Short & "x model " & $a_i_Model)
	If Not Merchant_BuyItem($a_i_Model, $l_i_Short, True) Then
		If Not Merchant_BuyItem($a_i_Model, $l_i_Short, False) Then
			Out("[Craft] Failed to buy material " & $a_i_Model)
			Return False
		EndIf
	EndIf
	Sleep(500)
	Return True
EndFunc

; Python _EARLY_ARMOR_DATA["buy"] is 6 cloth/hide, but monastery pieces cost 8
; (Ritualist boots cost 3 cloth, so 10). Sum the piece list so craft cannot run short.
Func Leveler_GetArmorBuyList(ByRef $a_ai_Models, ByRef $a_ai_Counts)
	Local $l_ai_M[4]
	Local $l_ai_C[4]
	Local $l_i_Count = 0
	Local $l_ai_Pieces = Leveler_GetMonasteryPieces()
	For $i = 0 To UBound($l_ai_Pieces) - 1
		Leveler_AddMatNeed($l_ai_M, $l_ai_C, $l_i_Count, $l_ai_Pieces[$i][1], $l_ai_Pieces[$i][2])
	Next
	If $l_i_Count = 0 Then
		Local $l_ai_Empty[0]
		$a_ai_Models = $l_ai_Empty
		$a_ai_Counts = $l_ai_Empty
		Return
	EndIf
	ReDim $l_ai_M[$l_i_Count]
	ReDim $l_ai_C[$l_i_Count]
	$a_ai_Models = $l_ai_M
	$a_ai_Counts = $l_ai_C
EndFunc

; Returns 2D array [n][3] = itemID, matModel, qty
Func Leveler_GetMonasteryPieces()
	Local $l_i_Prof = Leveler_PrimaryProfession()
	Local $l_ai_Pieces[5][3]
	Switch $l_i_Prof
		Case $GC_I_PROFESSION_WARRIOR
			$l_ai_Pieces[0][0] = 10156
			$l_ai_Pieces[0][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[0][2] = 3
			$l_ai_Pieces[1][0] = 10158
			$l_ai_Pieces[1][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[1][2] = 2
			$l_ai_Pieces[2][0] = 10155
			$l_ai_Pieces[2][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[2][2] = 1
			$l_ai_Pieces[3][0] = 10030
			$l_ai_Pieces[3][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[3][2] = 1
			$l_ai_Pieces[4][0] = 10157
			$l_ai_Pieces[4][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[4][2] = 1
		Case $GC_I_PROFESSION_RANGER
			$l_ai_Pieces[0][0] = 10605
			$l_ai_Pieces[0][1] = $GC_I_MODELID_TANNED_HIDE
			$l_ai_Pieces[0][2] = 3
			$l_ai_Pieces[1][0] = 10607
			$l_ai_Pieces[1][1] = $GC_I_MODELID_TANNED_HIDE
			$l_ai_Pieces[1][2] = 2
			$l_ai_Pieces[2][0] = 10604
			$l_ai_Pieces[2][1] = $GC_I_MODELID_TANNED_HIDE
			$l_ai_Pieces[2][2] = 1
			$l_ai_Pieces[3][0] = 14655
			$l_ai_Pieces[3][1] = $GC_I_MODELID_TANNED_HIDE
			$l_ai_Pieces[3][2] = 1
			$l_ai_Pieces[4][0] = 10606
			$l_ai_Pieces[4][1] = $GC_I_MODELID_TANNED_HIDE
			$l_ai_Pieces[4][2] = 1
		Case $GC_I_PROFESSION_MONK
			$l_ai_Pieces[0][0] = 9611
			$l_ai_Pieces[0][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[0][2] = 3
			$l_ai_Pieces[1][0] = 9613
			$l_ai_Pieces[1][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[1][2] = 2
			$l_ai_Pieces[2][0] = 9610
			$l_ai_Pieces[2][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[2][2] = 1
			$l_ai_Pieces[3][0] = 9590
			$l_ai_Pieces[3][1] = $GC_I_MODELID_DUST
			$l_ai_Pieces[3][2] = 1
			$l_ai_Pieces[4][0] = 9612
			$l_ai_Pieces[4][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[4][2] = 1
		Case $GC_I_PROFESSION_ASSASSIN
			$l_ai_Pieces[0][0] = 7185
			$l_ai_Pieces[0][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[0][2] = 3
			$l_ai_Pieces[1][0] = 7187
			$l_ai_Pieces[1][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[1][2] = 2
			$l_ai_Pieces[2][0] = 7184
			$l_ai_Pieces[2][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[2][2] = 1
			$l_ai_Pieces[3][0] = 7116
			$l_ai_Pieces[3][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[3][2] = 1
			$l_ai_Pieces[4][0] = 7186
			$l_ai_Pieces[4][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[4][2] = 1
		Case $GC_I_PROFESSION_MESMER
			$l_ai_Pieces[0][0] = 7538
			$l_ai_Pieces[0][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[0][2] = 3
			$l_ai_Pieces[1][0] = 7540
			$l_ai_Pieces[1][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[1][2] = 2
			$l_ai_Pieces[2][0] = 7537
			$l_ai_Pieces[2][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[2][2] = 1
			$l_ai_Pieces[3][0] = 7517
			$l_ai_Pieces[3][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[3][2] = 1
			$l_ai_Pieces[4][0] = 7539
			$l_ai_Pieces[4][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[4][2] = 1
		Case $GC_I_PROFESSION_NECROMANCER
			$l_ai_Pieces[0][0] = 8749
			$l_ai_Pieces[0][1] = $GC_I_MODELID_TANNED_HIDE
			$l_ai_Pieces[0][2] = 3
			$l_ai_Pieces[1][0] = 8751
			$l_ai_Pieces[1][1] = $GC_I_MODELID_TANNED_HIDE
			$l_ai_Pieces[1][2] = 2
			$l_ai_Pieces[2][0] = 8748
			$l_ai_Pieces[2][1] = $GC_I_MODELID_TANNED_HIDE
			$l_ai_Pieces[2][2] = 1
			$l_ai_Pieces[3][0] = 8731
			$l_ai_Pieces[3][1] = $GC_I_MODELID_DUST
			$l_ai_Pieces[3][2] = 1
			$l_ai_Pieces[4][0] = 8750
			$l_ai_Pieces[4][1] = $GC_I_MODELID_TANNED_HIDE
			$l_ai_Pieces[4][2] = 1
		Case $GC_I_PROFESSION_RITUALIST
			$l_ai_Pieces[0][0] = 11310
			$l_ai_Pieces[0][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[0][2] = 3
			$l_ai_Pieces[1][0] = 11313
			$l_ai_Pieces[1][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[1][2] = 2
			$l_ai_Pieces[2][0] = 11309
			$l_ai_Pieces[2][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[2][2] = 3
			$l_ai_Pieces[3][0] = 11194
			$l_ai_Pieces[3][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[3][2] = 1
			$l_ai_Pieces[4][0] = 11311
			$l_ai_Pieces[4][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[4][2] = 1
		Case $GC_I_PROFESSION_ELEMENTALIST
			$l_ai_Pieces[0][0] = 9194
			$l_ai_Pieces[0][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[0][2] = 3
			$l_ai_Pieces[1][0] = 9196
			$l_ai_Pieces[1][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[1][2] = 2
			$l_ai_Pieces[2][0] = 9193
			$l_ai_Pieces[2][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[2][2] = 1
			$l_ai_Pieces[3][0] = 9171
			$l_ai_Pieces[3][1] = $GC_I_MODELID_DUST
			$l_ai_Pieces[3][2] = 1
			$l_ai_Pieces[4][0] = 9195
			$l_ai_Pieces[4][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[4][2] = 1
		Case Else
			$l_ai_Pieces[0][0] = 10156
			$l_ai_Pieces[0][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[0][2] = 3
			$l_ai_Pieces[1][0] = 10158
			$l_ai_Pieces[1][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[1][2] = 2
			$l_ai_Pieces[2][0] = 10155
			$l_ai_Pieces[2][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[2][2] = 1
			$l_ai_Pieces[3][0] = 10030
			$l_ai_Pieces[3][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[3][2] = 1
			$l_ai_Pieces[4][0] = 10157
			$l_ai_Pieces[4][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[4][2] = 1
	EndSwitch
	Return $l_ai_Pieces
EndFunc

Func Leveler_BuyEarlyArmorMaterials()
	Local $l_ai_Models, $l_ai_Counts
	Leveler_GetArmorBuyList($l_ai_Models, $l_ai_Counts)
	For $i = 0 To UBound($l_ai_Models) - 1
		; Inventory only — Merchant_CraftItem needs the mats in bags, not storage.
		If Not Leveler_BuyMaterialShortfallInv($l_ai_Models[$i], $l_ai_Counts[$i]) Then Return False
	Next
	Return True
EndFunc

; Hiroyuki lists a Domination staff for every profession. Assassin / Warrior / Ranger
; should craft Sai / Cleaver / Longbow; Merchant_CraftItem of 11647 fails in a loop.
Func Leveler_WeaponUsesStaff()
	Switch Leveler_PrimaryProfession()
		Case $GC_I_PROFESSION_WARRIOR, $GC_I_PROFESSION_RANGER, $GC_I_PROFESSION_ASSASSIN
			Return False
	EndSwitch
	Return True
EndFunc

; Name, merchant item type, preferred model (0 = first matching type), mats [n][2].
; Hiroyuki recipes: Sai 5 iron; Cleaver 4 iron + 1 wood; Longbow 5 wood;
; Clairvoyant Staff 4 wood + 1 dust. All 100 gold.
Func Leveler_GetWeaponPlan(ByRef $a_s_Name, ByRef $a_i_Type, ByRef $a_i_PreferredModel, ByRef $a_ai_Mats)
	Local $l_i_Prof = Leveler_PrimaryProfession()
	Local $l_ai_Mats[1][2]
	$a_i_PreferredModel = 0
	Switch $l_i_Prof
		Case $GC_I_PROFESSION_ASSASSIN
			$a_s_Name = "Sai"
			$a_i_Type = $GC_I_TYPE_DAGGERS
			$l_ai_Mats[0][0] = $GC_I_MODELID_IRON
			$l_ai_Mats[0][1] = 5
		Case $GC_I_PROFESSION_WARRIOR
			$a_s_Name = "Cleaver"
			$a_i_Type = $GC_I_TYPE_AXE
			ReDim $l_ai_Mats[2][2]
			$l_ai_Mats[0][0] = $GC_I_MODELID_IRON
			$l_ai_Mats[0][1] = 4
			$l_ai_Mats[1][0] = $GC_I_MODELID_WOOD
			$l_ai_Mats[1][1] = 1
		Case $GC_I_PROFESSION_RANGER
			$a_s_Name = "Longbow"
			$a_i_Type = $GC_I_TYPE_BOW
			$l_ai_Mats[0][0] = $GC_I_MODELID_WOOD
			$l_ai_Mats[0][1] = 5
		Case Else
			$a_s_Name = "Clairvoyant Staff"
			$a_i_Type = $GC_I_TYPE_STAFF
			$a_i_PreferredModel = $MODEL_CLAIRVOYANT_STAFF
			ReDim $l_ai_Mats[2][2]
			$l_ai_Mats[0][0] = $GC_I_MODELID_WOOD
			$l_ai_Mats[0][1] = 4
			$l_ai_Mats[1][0] = $GC_I_MODELID_DUST
			$l_ai_Mats[1][1] = 1
	EndSwitch
	$a_ai_Mats = $l_ai_Mats
EndFunc

Func Leveler_RememberWeaponModel($a_i_Model)
	If $a_i_Model = 0 Then Return
	$g_i_CraftedWeaponModel = $a_i_Model
EndFunc

; First Hiroyuki listing of this item type. Prefers $a_i_PreferredModel when offered.
Func Leveler_FindMerchantWeaponModel($a_i_Type, $a_i_PreferredModel = 0)
	If $a_i_PreferredModel <> 0 And Merchant_GetMerchantItemPtr($a_i_PreferredModel) <> 0 Then Return $a_i_PreferredModel
	Local $l_i_Size = Merchant_GetMerchantItemsSize()
	Local $i
	For $i = 1 To $l_i_Size
		Local $l_p_Item = Merchant_GetMerchantItemPtr($i, 1)
		If $l_p_Item = 0 Then ContinueLoop
		If Item_GetItemInfoByPtr($l_p_Item, "ItemType") <> $a_i_Type Then ContinueLoop
		Local $l_i_Model = Memory_Read($l_p_Item + 0x2C, "dword")
		If $l_i_Model <> 0 Then Return $l_i_Model
	Next
	Return 0
EndFunc

Func Leveler_WaitForWeaponOffer($a_i_Type, $a_i_PreferredModel = 0, $a_i_Timeout = 8000)
	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < $a_i_Timeout
		If $g_b_LevelerPaused Then Return 0
		Local $l_i_Model = Leveler_FindMerchantWeaponModel($a_i_Type, $a_i_PreferredModel)
		If $l_i_Model <> 0 Then Return $l_i_Model
		Sleep(200)
	WEnd
	Out("[Craft] Crafter is not offering a profession weapon (type " & $a_i_Type & ", preferred " & $a_i_PreferredModel & ")")
	Leveler_LogMerchantWeapons()
	Return 0
EndFunc

Func Leveler_LogMerchantWeapons()
	Local $l_i_Size = Number(Merchant_GetMerchantItemsSize())
	Out("[Craft] Merchant listings: " & $l_i_Size)
	If $l_i_Size <= 0 Then Return
	Local $i
	Local $l_i_Max = $l_i_Size
	If $l_i_Max > 12 Then $l_i_Max = 12
	For $i = 1 To $l_i_Max
		Local $l_p_Item = Merchant_GetMerchantItemPtr($i, 1)
		If $l_p_Item = 0 Then ContinueLoop
		Out("[Craft]  slot " & $i & " type " & Item_GetItemInfoByPtr($l_p_Item, "ItemType") & " model " & Memory_Read($l_p_Item + 0x2C, "dword") & " prof " & Item_GetItemInfoByPtr($l_p_Item, "Profession"))
	Next
EndFunc

Func Leveler_GetCraftedWeaponModel()
	If $g_i_CraftedWeaponModel <> 0 Then Return $g_i_CraftedWeaponModel
	If Leveler_WeaponUsesStaff() Then Return $MODEL_CLAIRVOYANT_STAFF
	Local $l_s_Name, $l_i_Type, $l_i_Preferred
	Local $l_ai_Mats
	Leveler_GetWeaponPlan($l_s_Name, $l_i_Type, $l_i_Preferred, $l_ai_Mats)
	Return Leveler_FindMerchantWeaponModel($l_i_Type, $l_i_Preferred)
EndFunc

Func Leveler_EquipCraftedWeapon()
	If $g_b_WeaponCraftSkipped Then Return True
	Local $l_i_Model = Leveler_GetCraftedWeaponModel()
	If $l_i_Model = 0 Then Return True
	Return Leveler_EquipModel($l_i_Model)
EndFunc

Func Leveler_WeaponStepEquipped()
	If $g_b_WeaponCraftSkipped Then Return True
	Local $l_i_Model = Leveler_GetCraftedWeaponModel()
	If $l_i_Model = 0 Then Return False
	Return Leveler_IsModelEquipped($l_i_Model)
EndFunc

; Inventory only — Merchant_CraftItem needs the mats in bags, not storage.
Func Leveler_BuyWeaponMaterials()
	Local $l_s_Name, $l_i_Type, $l_i_Preferred
	Local $l_ai_Mats
	Leveler_GetWeaponPlan($l_s_Name, $l_i_Type, $l_i_Preferred, $l_ai_Mats)
	Out("[Craft] Buying materials for " & $l_s_Name & " (profession " & Leveler_PrimaryProfession() & ")")
	Local $i
	For $i = 0 To UBound($l_ai_Mats) - 1
		If $l_ai_Mats[$i][0] = 0 Or $l_ai_Mats[$i][1] <= 0 Then ContinueLoop
		If Not Leveler_BuyMaterialShortfallInv($l_ai_Mats[$i][0], $l_ai_Mats[$i][1]) Then Return False
	Next
	Return True
EndFunc

Func Leveler_SkipWeaponCraft($a_s_Reason)
	Out("[Craft] " & $a_s_Reason & ". Skipping Craft Weapon so monastery armor can continue.")
	$g_b_WeaponCraftSkipped = True
	Return True
EndFunc

Func Leveler_CraftWeapon()
	Local $l_s_Name, $l_i_Type, $l_i_Preferred
	Local $l_ai_Mats
	Leveler_GetWeaponPlan($l_s_Name, $l_i_Type, $l_i_Preferred, $l_ai_Mats)
	If Not Leveler_WeaponUsesStaff() Then
		Out("[Craft] Primary " & Leveler_PrimaryProfession() & " is melee/physical. Crafting " & $l_s_Name & " instead of Clairvoyant Staff.")
	EndIf

	Local $l_i_Model = Leveler_GetCraftedWeaponModel()
	If $l_i_Model <> 0 And Leveler_OwnsModel($l_i_Model) Then
		Leveler_RememberWeaponModel($l_i_Model)
		If Not Leveler_EquipModel($l_i_Model) Then Return False
		Out("[Craft] Starter weapon equipped (model " & $l_i_Model & ")")
		Return True
	EndIf

	$l_i_Model = Leveler_WaitForWeaponOffer($l_i_Type, $l_i_Preferred)
	If $l_i_Model = 0 Then
		If Leveler_WeaponUsesStaff() Then Return False
		Return Leveler_SkipWeaponCraft("Hiroyuki is not offering " & $l_s_Name)
	EndIf
	Leveler_RememberWeaponModel($l_i_Model)

	If Leveler_OwnsModel($l_i_Model) Then
		If Not Leveler_EquipModel($l_i_Model) Then Return False
		Out("[Craft] Starter weapon equipped (model " & $l_i_Model & ")")
		Return True
	EndIf

	Out("[Craft] Crafting " & $l_s_Name & " model " & $l_i_Model)
	If Not Leveler_CraftAndEquipPiece($l_i_Model, $WEAPON_GOLD_COST, $l_ai_Mats) Then
		Out("[Craft] Failed to craft " & $l_s_Name & " (model " & $l_i_Model & ")")
		Return False
	EndIf
	Out("[Craft] Starter weapon equipped")
	Return True
EndFunc

Func Leveler_CraftMonasteryArmor()
	Local $l_ai_Pieces = Leveler_GetMonasteryPieces()
	If Not Leveler_WaitForCrafterOffer($l_ai_Pieces[0][0]) Then Return False
	For $i = 0 To UBound($l_ai_Pieces) - 1
		Local $l_ai_Mats[1][2]
		$l_ai_Mats[0][0] = $l_ai_Pieces[$i][1]
		$l_ai_Mats[0][1] = $l_ai_Pieces[$i][2]
		If Not Leveler_CraftAndEquipPiece($l_ai_Pieces[$i][0], $MONASTERY_ARMOR_GOLD, $l_ai_Mats) Then
			Out("[Craft] Failed to craft armor piece " & $l_ai_Pieces[$i][0])
			Return False
		EndIf
	Next
	Out("[Craft] Monastery armor set crafted and equipped")
	Return True
EndFunc

Func Leveler_DestroyModel($a_i_Model)
	Local $l_i_Item = Item_FindItemByModelID($a_i_Model)
	If $l_i_Item = 0 Then $l_i_Item = Item_GetBagsItembyModelID($a_i_Model)
	If $l_i_Item = 0 Then Return True
	Item_DestroyItem($l_i_Item)
	Sleep(200)
	Return True
EndFunc

; Bags only. Do not destroy equipped armor or crafter-window listings.
Func Leveler_DestroyBagModel($a_i_Model)
	If $a_i_Model = 0 Then Return True
	If Leveler_IsModelEquipped($a_i_Model) Then
		Out("[Craft] Not destroying equipped model " & $a_i_Model)
		Return True
	EndIf
	Local $l_i_Item = Item_GetBagsItembyModelID($a_i_Model)
	If $l_i_Item = 0 Then Return True
	Item_DestroyItem($l_i_Item)
	Sleep(200)
	Return True
EndFunc

Func Leveler_GetStarterArmorModels()
	Local $l_i_Prof = Leveler_PrimaryProfession()
	Local $l_ai_Armor[5]
	Switch $l_i_Prof
		Case $GC_I_PROFESSION_ASSASSIN
			$l_ai_Armor[0] = 7251
			$l_ai_Armor[1] = 7249
			$l_ai_Armor[2] = 7250
			$l_ai_Armor[3] = 7252
			$l_ai_Armor[4] = 7248
		Case $GC_I_PROFESSION_RITUALIST
			$l_ai_Armor[0] = 11332
			$l_ai_Armor[1] = 11330
			$l_ai_Armor[2] = 11331
			$l_ai_Armor[3] = 11333
			$l_ai_Armor[4] = 11329
		Case $GC_I_PROFESSION_WARRIOR
			$l_ai_Armor[0] = 10174
			$l_ai_Armor[1] = 10172
			$l_ai_Armor[2] = 10173
			$l_ai_Armor[3] = 10175
			$l_ai_Armor[4] = 10171
		Case $GC_I_PROFESSION_RANGER
			$l_ai_Armor[0] = 10623
			$l_ai_Armor[1] = 10621
			$l_ai_Armor[2] = 10622
			$l_ai_Armor[3] = 10624
			$l_ai_Armor[4] = 10620
		Case $GC_I_PROFESSION_MONK
			$l_ai_Armor[0] = 9725
			$l_ai_Armor[1] = 9723
			$l_ai_Armor[2] = 9724
			$l_ai_Armor[3] = 9726
			$l_ai_Armor[4] = 9722
		Case $GC_I_PROFESSION_ELEMENTALIST
			$l_ai_Armor[0] = 9324
			$l_ai_Armor[1] = 9322
			$l_ai_Armor[2] = 9323
			$l_ai_Armor[3] = 9325
			$l_ai_Armor[4] = 9321
		Case $GC_I_PROFESSION_MESMER
			$l_ai_Armor[0] = 8026
			$l_ai_Armor[1] = 8024
			$l_ai_Armor[2] = 8025
			$l_ai_Armor[3] = 8054
			$l_ai_Armor[4] = 8023
		Case $GC_I_PROFESSION_NECROMANCER
			$l_ai_Armor[0] = 8863
			$l_ai_Armor[1] = 8861
			$l_ai_Armor[2] = 8862
			$l_ai_Armor[3] = 8864
			$l_ai_Armor[4] = 8860
		Case Else
			Local $l_ai_Empty[0]
			$l_ai_Armor = $l_ai_Empty
	EndSwitch
	Return $l_ai_Armor
EndFunc

Func Leveler_HasStarterArmor()
	Local $l_ai_Armor = Leveler_GetStarterArmorModels()
	For $i = 0 To UBound($l_ai_Armor) - 1
		If Item_FindItemByModelID($l_ai_Armor[$i]) <> 0 Then Return True
		If Item_GetBagsItembyModelID($l_ai_Armor[$i]) <> 0 Then Return True
	Next
	Return False
EndFunc

Func Leveler_HasMonasteryArmor()
	Local $l_ai_Pieces = Leveler_GetMonasteryPieces()
	For $i = 0 To UBound($l_ai_Pieces) - 1
		If Leveler_OwnsModel($l_ai_Pieces[$i][0]) Then Return True
	Next
	Return False
EndFunc

; Returns 2D array [n][3] = itemID, matModel, qty
Func Leveler_GetSeitungPieces()
	Local $l_i_Prof = Leveler_PrimaryProfession()
	Local $l_ai_Pieces[5][3]
	Switch $l_i_Prof
		Case $GC_I_PROFESSION_WARRIOR
			$l_ai_Pieces[0][0] = 10164
			$l_ai_Pieces[0][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[0][2] = 18
			$l_ai_Pieces[1][0] = 10166
			$l_ai_Pieces[1][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[1][2] = 12
			$l_ai_Pieces[2][0] = 10163
			$l_ai_Pieces[2][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[2][2] = 6
			$l_ai_Pieces[3][0] = 10046
			$l_ai_Pieces[3][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[3][2] = 6
			$l_ai_Pieces[4][0] = 10165
			$l_ai_Pieces[4][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[4][2] = 6
		Case $GC_I_PROFESSION_RANGER
			$l_ai_Pieces[0][0] = 10613
			$l_ai_Pieces[0][1] = $GC_I_MODELID_TANNED_HIDE
			$l_ai_Pieces[0][2] = 18
			$l_ai_Pieces[1][0] = 10615
			$l_ai_Pieces[1][1] = $GC_I_MODELID_TANNED_HIDE
			$l_ai_Pieces[1][2] = 12
			$l_ai_Pieces[2][0] = 10612
			$l_ai_Pieces[2][1] = $GC_I_MODELID_TANNED_HIDE
			$l_ai_Pieces[2][2] = 6
			$l_ai_Pieces[3][0] = 10483
			$l_ai_Pieces[3][1] = $GC_I_MODELID_TANNED_HIDE
			$l_ai_Pieces[3][2] = 6
			$l_ai_Pieces[4][0] = 10614
			$l_ai_Pieces[4][1] = $GC_I_MODELID_TANNED_HIDE
			$l_ai_Pieces[4][2] = 6
		Case $GC_I_PROFESSION_MONK
			$l_ai_Pieces[0][0] = 9619
			$l_ai_Pieces[0][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[0][2] = 18
			$l_ai_Pieces[1][0] = 9621
			$l_ai_Pieces[1][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[1][2] = 12
			$l_ai_Pieces[2][0] = 9618
			$l_ai_Pieces[2][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[2][2] = 6
			$l_ai_Pieces[3][0] = 9600
			$l_ai_Pieces[3][1] = $GC_I_MODELID_DUST
			$l_ai_Pieces[3][2] = 6
			$l_ai_Pieces[4][0] = 9620
			$l_ai_Pieces[4][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[4][2] = 6
		Case $GC_I_PROFESSION_ASSASSIN
			$l_ai_Pieces[0][0] = 7193
			$l_ai_Pieces[0][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[0][2] = 18
			$l_ai_Pieces[1][0] = 7195
			$l_ai_Pieces[1][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[1][2] = 12
			$l_ai_Pieces[2][0] = 7192
			$l_ai_Pieces[2][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[2][2] = 6
			$l_ai_Pieces[3][0] = 7126
			$l_ai_Pieces[3][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[3][2] = 6
			$l_ai_Pieces[4][0] = 7194
			$l_ai_Pieces[4][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[4][2] = 6
		Case $GC_I_PROFESSION_MESMER
			$l_ai_Pieces[0][0] = 7546
			$l_ai_Pieces[0][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[0][2] = 18
			$l_ai_Pieces[1][0] = 7548
			$l_ai_Pieces[1][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[1][2] = 12
			$l_ai_Pieces[2][0] = 7545
			$l_ai_Pieces[2][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[2][2] = 6
			$l_ai_Pieces[3][0] = 7528
			$l_ai_Pieces[3][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[3][2] = 6
			$l_ai_Pieces[4][0] = 7547
			$l_ai_Pieces[4][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[4][2] = 6
		Case $GC_I_PROFESSION_NECROMANCER
			$l_ai_Pieces[0][0] = 8757
			$l_ai_Pieces[0][1] = $GC_I_MODELID_TANNED_HIDE
			$l_ai_Pieces[0][2] = 18
			$l_ai_Pieces[1][0] = 8759
			$l_ai_Pieces[1][1] = $GC_I_MODELID_TANNED_HIDE
			$l_ai_Pieces[1][2] = 12
			$l_ai_Pieces[2][0] = 8756
			$l_ai_Pieces[2][1] = $GC_I_MODELID_TANNED_HIDE
			$l_ai_Pieces[2][2] = 6
			$l_ai_Pieces[3][0] = 8741
			$l_ai_Pieces[3][1] = $GC_I_MODELID_DUST
			$l_ai_Pieces[3][2] = 6
			$l_ai_Pieces[4][0] = 8758
			$l_ai_Pieces[4][1] = $GC_I_MODELID_TANNED_HIDE
			$l_ai_Pieces[4][2] = 6
		Case $GC_I_PROFESSION_RITUALIST
			$l_ai_Pieces[0][0] = 11320
			$l_ai_Pieces[0][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[0][2] = 18
			$l_ai_Pieces[1][0] = 11323
			$l_ai_Pieces[1][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[1][2] = 12
			$l_ai_Pieces[2][0] = 11319
			$l_ai_Pieces[2][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[2][2] = 6
			$l_ai_Pieces[3][0] = 11203
			$l_ai_Pieces[3][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[3][2] = 6
			$l_ai_Pieces[4][0] = 11321
			$l_ai_Pieces[4][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[4][2] = 6
		Case $GC_I_PROFESSION_ELEMENTALIST
			$l_ai_Pieces[0][0] = 9202
			$l_ai_Pieces[0][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[0][2] = 18
			$l_ai_Pieces[1][0] = 9204
			$l_ai_Pieces[1][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[1][2] = 12
			$l_ai_Pieces[2][0] = 9201
			$l_ai_Pieces[2][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[2][2] = 6
			$l_ai_Pieces[3][0] = 9183
			$l_ai_Pieces[3][1] = $GC_I_MODELID_DUST
			$l_ai_Pieces[3][2] = 6
			$l_ai_Pieces[4][0] = 9203
			$l_ai_Pieces[4][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[4][2] = 6
		Case Else
			$l_ai_Pieces[0][0] = 10164
			$l_ai_Pieces[0][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[0][2] = 18
			$l_ai_Pieces[1][0] = 10166
			$l_ai_Pieces[1][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[1][2] = 12
			$l_ai_Pieces[2][0] = 10163
			$l_ai_Pieces[2][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[2][2] = 6
			$l_ai_Pieces[3][0] = 10046
			$l_ai_Pieces[3][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[3][2] = 6
			$l_ai_Pieces[4][0] = 10165
			$l_ai_Pieces[4][1] = $GC_I_MODELID_CLOTHS
			$l_ai_Pieces[4][2] = 6
	EndSwitch
	Return $l_ai_Pieces
EndFunc

Func Leveler_BuySeitungMaterials()
	Local $l_ai_Pieces = Leveler_GetSeitungPieces()
	Local $l_i_Cloth = 0
	Local $l_i_Hide = 0
	Local $l_i_Dust = 0
	For $i = 0 To UBound($l_ai_Pieces) - 1
		Switch $l_ai_Pieces[$i][1]
			Case $GC_I_MODELID_CLOTHS
				$l_i_Cloth += $l_ai_Pieces[$i][2]
			Case $GC_I_MODELID_TANNED_HIDE
				$l_i_Hide += $l_ai_Pieces[$i][2]
			Case $GC_I_MODELID_DUST
				$l_i_Dust += $l_ai_Pieces[$i][2]
		EndSwitch
	Next
	; Inventory only — Merchant_CraftItem needs the mats in bags, not storage.
	If $l_i_Cloth > 0 Then
		If Not Leveler_BuyMaterialShortfallInv($GC_I_MODELID_CLOTHS, $l_i_Cloth) Then Return False
	EndIf
	If $l_i_Hide > 0 Then
		If Not Leveler_BuyMaterialShortfallInv($GC_I_MODELID_TANNED_HIDE, $l_i_Hide) Then Return False
	EndIf
	If $l_i_Dust > 0 Then
		If Not Leveler_BuyMaterialShortfallInv($GC_I_MODELID_DUST, $l_i_Dust) Then Return False
	EndIf
	Return True
EndFunc

Func Leveler_SeitungMaterialsReady()
	Local $l_ai_Pieces = Leveler_GetSeitungPieces()
	Local $l_i_Cloth = 0
	Local $l_i_Hide = 0
	Local $l_i_Dust = 0
	For $i = 0 To UBound($l_ai_Pieces) - 1
		Switch $l_ai_Pieces[$i][1]
			Case $GC_I_MODELID_CLOTHS
				$l_i_Cloth += $l_ai_Pieces[$i][2]
			Case $GC_I_MODELID_TANNED_HIDE
				$l_i_Hide += $l_ai_Pieces[$i][2]
			Case $GC_I_MODELID_DUST
				$l_i_Dust += $l_ai_Pieces[$i][2]
		EndSwitch
	Next
	If $l_i_Cloth > 0 And Leveler_CountModel($GC_I_MODELID_CLOTHS, False) < $l_i_Cloth Then Return False
	If $l_i_Hide > 0 And Leveler_CountModel($GC_I_MODELID_TANNED_HIDE, False) < $l_i_Hide Then Return False
	If $l_i_Dust > 0 And Leveler_CountModel($GC_I_MODELID_DUST, False) < $l_i_Dust Then Return False
	Return True
EndFunc

Func Leveler_TraderOffersModel($a_i_Model)
	If Merchant_GetMerchantItemPtr($a_i_Model) <> 0 Then Return True
	Local $l_ap_Items = Item_GetItemArray()
	If Not IsArray($l_ap_Items) Then Return False
	Local $i
	For $i = 1 To $l_ap_Items[0]
		If $l_ap_Items[$i] = 0 Then ContinueLoop
		If Memory_Read($l_ap_Items[$i] + 0x2C, "dword") <> $a_i_Model Then ContinueLoop
		If Memory_Read($l_ap_Items[$i] + 0xC, "ptr") <> 0 Then ContinueLoop
		If Memory_Read($l_ap_Items[$i] + 0x4, "dword") <> 0 Then ContinueLoop
		Return True
	Next
	Return False
EndFunc

Func Leveler_WaitForMaterialOffer($a_i_Model, $a_i_Timeout = 8000)
	Local $l_h_Timer = TimerInit()
	While TimerDiff($l_h_Timer) < $a_i_Timeout
		If $g_b_LevelerPaused Then Return False
		If Leveler_TraderOffersModel($a_i_Model) Then Return True
		Sleep(200)
	WEnd
	Out("[Craft] Trader is not offering model " & $a_i_Model & " (merchant size " & Merchant_GetMerchantItemsSize() & ")")
	Return False
EndFunc

Func Leveler_BuyMaterialShortfallInv($a_i_Model, $a_i_Need)
	Local $l_i_Have = Leveler_CountModel($a_i_Model, False)
	If $l_i_Have >= $a_i_Need Then
		Out("[Craft] Inventory already has " & $l_i_Have & "x model " & $a_i_Model)
		Return True
	EndIf
	Out("[Craft] Need " & $a_i_Need & "x model " & $a_i_Model & " (have " & $l_i_Have & ", gold " & Item_GetInventoryInfo("GoldCharacter") & ")")
	If Not Leveler_WaitForMaterialOffer($a_i_Model) Then Return False
	While $l_i_Have < $a_i_Need
		If $g_b_LevelerPaused Then Return False
		Local $l_i_Before = $l_i_Have
		; Common-material traders sell in quoted lots. A normal Merchant_BuyItem packet does not buy them.
		If Not Merchant_BuyItem($a_i_Model, 1, True) Then
			Out("[Craft] Trader quote/buy failed for model " & $a_i_Model)
			Return False
		EndIf
		Local $l_h_Timer = TimerInit()
		While TimerDiff($l_h_Timer) < 4000
			Sleep(250)
			$l_i_Have = Leveler_CountModel($a_i_Model, False)
			If $l_i_Have > $l_i_Before Then ExitLoop
		WEnd
		If $l_i_Have <= $l_i_Before Then
			Out("[Craft] Material count did not increase for model " & $a_i_Model)
			Return False
		EndIf
		Out("[Craft] Now have " & $l_i_Have & "/" & $a_i_Need & " of model " & $a_i_Model)
	WEnd
	Return True
EndFunc

Func Leveler_CraftSeitungArmor()
	Local $l_ai_Pieces = Leveler_GetSeitungPieces()
	If Not Leveler_WaitForCrafterOffer($l_ai_Pieces[0][0]) Then Return False
	For $i = 0 To UBound($l_ai_Pieces) - 1
		Local $l_ai_Mats[1][2]
		$l_ai_Mats[0][0] = $l_ai_Pieces[$i][1]
		$l_ai_Mats[0][1] = $l_ai_Pieces[$i][2]
		If Not Leveler_CraftAndEquipPiece($l_ai_Pieces[$i][0], $SEITUNG_ARMOR_GOLD, $l_ai_Mats) Then
			Out("[Craft] Failed to craft Seitung armor piece " & $l_ai_Pieces[$i][0])
			Return False
		EndIf
	Next
	Out("[Craft] Seitung armor set crafted and equipped")
	Return True
EndFunc

Func Leveler_HasSeitungArmor()
	Local $l_ai_Pieces = Leveler_GetSeitungPieces()
	For $i = 0 To UBound($l_ai_Pieces) - 1
		If Leveler_OwnsModel($l_ai_Pieces[$i][0]) Then Return True
	Next
	Return False
EndFunc

Func Leveler_DestroyMonasteryArmor()
	Local $l_ai_Pieces = Leveler_GetMonasteryPieces()
	For $i = 0 To UBound($l_ai_Pieces) - 1
		Leveler_DestroyModel($l_ai_Pieces[$i][0])
	Next
	Out("[Craft] Destroyed monastery armor")
	Return True
EndFunc

Func Leveler_DestroySeitungArmor()
	If Not Leveler_ArmorSetEquipped(Leveler_GetMaxArmorPieces()) Then
		Out("[Craft] Max armor is not equipped. Not destroying Seitung pieces.")
		Return False
	EndIf
	Local $l_ai_Mon = Leveler_GetMonasteryPieces()
	Local $i
	For $i = 0 To UBound($l_ai_Mon) - 1
		Leveler_DestroyBagModel($l_ai_Mon[$i][0])
	Next
	Local $l_ai_Pieces = Leveler_GetSeitungPieces()
	For $i = 0 To UBound($l_ai_Pieces) - 1
		If Leveler_IsModelEquipped($l_ai_Pieces[$i][0]) Then
			Out("[Craft] Seitung model " & $l_ai_Pieces[$i][0] & " is still equipped. Not destroying it.")
			Return False
		EndIf
		Leveler_DestroyBagModel($l_ai_Pieces[$i][0])
	Next
	If Not Leveler_ArmorSetEquipped(Leveler_GetMaxArmorPieces()) Then
		Out("[Craft] Max armor is no longer equipped after destroying Seitung")
		Return False
	EndIf
	Out("[Craft] Destroyed leftover monastery and Seitung armor from bags")
	Return True
EndFunc

; Returns [5][5] = itemID, mat1, qty1, mat2, qty2
Func Leveler_GetMaxArmorPieces()
	Local $l_i_Prof = Leveler_PrimaryProfession()
	Local $l_ai_Pieces[5][5]
	Switch $l_i_Prof
		Case $GC_I_PROFESSION_WARRIOR
			Leveler_FillMaxPiece($l_ai_Pieces, 0, 23395, $GC_I_MODELID_TANNED_HIDE, 25, $GC_I_MODELID_STEEL_INGOT, 4)
			Leveler_FillMaxPiece($l_ai_Pieces, 1, 23393, $GC_I_MODELID_TANNED_HIDE, 25, $GC_I_MODELID_STEEL_INGOT, 4)
			Leveler_FillMaxPiece($l_ai_Pieces, 2, 23396, $GC_I_MODELID_TANNED_HIDE, 50, $GC_I_MODELID_STEEL_INGOT, 8)
			Leveler_FillMaxPiece($l_ai_Pieces, 3, 23394, $GC_I_MODELID_TANNED_HIDE, 75, $GC_I_MODELID_STEEL_INGOT, 12)
			Leveler_FillMaxPiece($l_ai_Pieces, 4, 23391, $GC_I_MODELID_TANNED_HIDE, 25, $GC_I_MODELID_STEEL_INGOT, 4)
		Case $GC_I_PROFESSION_RANGER
			Leveler_FillMaxPiece($l_ai_Pieces, 0, 23798, $GC_I_MODELID_CLOTHS, 25, $GC_I_MODELID_FUR_SQUARE, 4)
			Leveler_FillMaxPiece($l_ai_Pieces, 1, 23796, $GC_I_MODELID_CLOTHS, 25, $GC_I_MODELID_FUR_SQUARE, 4)
			Leveler_FillMaxPiece($l_ai_Pieces, 2, 23799, $GC_I_MODELID_CLOTHS, 50, $GC_I_MODELID_FUR_SQUARE, 8)
			Leveler_FillMaxPiece($l_ai_Pieces, 3, 23797, $GC_I_MODELID_CLOTHS, 75, $GC_I_MODELID_FUR_SQUARE, 12)
			Leveler_FillMaxPiece($l_ai_Pieces, 4, 23794, $GC_I_MODELID_CLOTHS, 25, $GC_I_MODELID_FUR_SQUARE, 4)
		Case $GC_I_PROFESSION_MONK
			Leveler_FillMaxPiece($l_ai_Pieces, 0, 23727, $GC_I_MODELID_CLOTHS, 25, $GC_I_MODELID_LINEN, 4)
			Leveler_FillMaxPiece($l_ai_Pieces, 1, 23725, $GC_I_MODELID_CLOTHS, 25, $GC_I_MODELID_LINEN, 4)
			Leveler_FillMaxPiece($l_ai_Pieces, 2, 23728, $GC_I_MODELID_CLOTHS, 50, $GC_I_MODELID_LINEN, 8)
			Leveler_FillMaxPiece($l_ai_Pieces, 3, 23726, $GC_I_MODELID_CLOTHS, 75, $GC_I_MODELID_LINEN, 12)
			Leveler_FillMaxPiece($l_ai_Pieces, 4, 23721, $GC_I_MODELID_ROLL_OF_PARCHMENT, 5, $GC_I_MODELID_VIAL_OF_INK, 4)
		Case $GC_I_PROFESSION_ASSASSIN
			Leveler_FillMaxPiece($l_ai_Pieces, 0, 23442, $GC_I_MODELID_CLOTHS, 25, $GC_I_MODELID_LEATHER_SQUARE, 4)
			Leveler_FillMaxPiece($l_ai_Pieces, 1, 23440, $GC_I_MODELID_CLOTHS, 25, $GC_I_MODELID_LEATHER_SQUARE, 4)
			Leveler_FillMaxPiece($l_ai_Pieces, 2, 23443, $GC_I_MODELID_CLOTHS, 50, $GC_I_MODELID_LEATHER_SQUARE, 8)
			Leveler_FillMaxPiece($l_ai_Pieces, 3, 23441, $GC_I_MODELID_CLOTHS, 75, $GC_I_MODELID_LEATHER_SQUARE, 12)
			Leveler_FillMaxPiece($l_ai_Pieces, 4, 23435, $GC_I_MODELID_CLOTHS, 25, $GC_I_MODELID_LEATHER_SQUARE, 4)
		Case $GC_I_PROFESSION_MESMER
			Leveler_FillMaxPiece($l_ai_Pieces, 0, 23582, $GC_I_MODELID_CLOTHS, 25, $GC_I_MODELID_SILK, 4)
			Leveler_FillMaxPiece($l_ai_Pieces, 1, 23580, $GC_I_MODELID_CLOTHS, 25, $GC_I_MODELID_SILK, 4)
			Leveler_FillMaxPiece($l_ai_Pieces, 2, 23583, $GC_I_MODELID_CLOTHS, 50, $GC_I_MODELID_SILK, 8)
			Leveler_FillMaxPiece($l_ai_Pieces, 3, 23581, $GC_I_MODELID_CLOTHS, 75, $GC_I_MODELID_SILK, 12)
			Leveler_FillMaxPiece($l_ai_Pieces, 4, 23576, $GC_I_MODELID_CLOTHS, 25, $GC_I_MODELID_SILK, 4)
		Case $GC_I_PROFESSION_NECROMANCER
			Leveler_FillMaxPiece($l_ai_Pieces, 0, 23638, $GC_I_MODELID_TANNED_HIDE, 25, $GC_I_MODELID_BONES, 25)
			Leveler_FillMaxPiece($l_ai_Pieces, 1, 23636, $GC_I_MODELID_TANNED_HIDE, 25, $GC_I_MODELID_BONES, 25)
			Leveler_FillMaxPiece($l_ai_Pieces, 2, 23639, $GC_I_MODELID_TANNED_HIDE, 50, $GC_I_MODELID_BONES, 50)
			Leveler_FillMaxPiece($l_ai_Pieces, 3, 23637, $GC_I_MODELID_TANNED_HIDE, 75, $GC_I_MODELID_BONES, 75)
			Leveler_FillMaxPiece($l_ai_Pieces, 4, 23632, $GC_I_MODELID_ROLL_OF_PARCHMENT, 5, $GC_I_MODELID_VIAL_OF_INK, 4)
		Case $GC_I_PROFESSION_RITUALIST
			Leveler_FillMaxPiece($l_ai_Pieces, 0, 23942, $GC_I_MODELID_CLOTHS, 25, $GC_I_MODELID_LEATHER_SQUARE, 4)
			Leveler_FillMaxPiece($l_ai_Pieces, 1, 23940, $GC_I_MODELID_CLOTHS, 25, $GC_I_MODELID_LEATHER_SQUARE, 4)
			Leveler_FillMaxPiece($l_ai_Pieces, 2, 23943, $GC_I_MODELID_CLOTHS, 50, $GC_I_MODELID_LEATHER_SQUARE, 8)
			Leveler_FillMaxPiece($l_ai_Pieces, 3, 23941, $GC_I_MODELID_CLOTHS, 75, $GC_I_MODELID_LEATHER_SQUARE, 12)
			Leveler_FillMaxPiece($l_ai_Pieces, 4, 23939, $GC_I_MODELID_CLOTHS, 25, $GC_I_MODELID_LEATHER_SQUARE, 4)
		Case $GC_I_PROFESSION_ELEMENTALIST
			Leveler_FillMaxPiece($l_ai_Pieces, 0, 23671, $GC_I_MODELID_CLOTHS, 25, $GC_I_MODELID_SILK, 4)
			Leveler_FillMaxPiece($l_ai_Pieces, 1, 23669, $GC_I_MODELID_CLOTHS, 25, $GC_I_MODELID_SILK, 4)
			Leveler_FillMaxPiece($l_ai_Pieces, 2, 23672, $GC_I_MODELID_CLOTHS, 50, $GC_I_MODELID_SILK, 8)
			Leveler_FillMaxPiece($l_ai_Pieces, 3, 23670, $GC_I_MODELID_CLOTHS, 75, $GC_I_MODELID_SILK, 12)
			Leveler_FillMaxPiece($l_ai_Pieces, 4, 23643, $GC_I_MODELID_DUST, 25, $GC_I_MODELID_GLASS_VIAL, 4)
		Case Else
			Leveler_FillMaxPiece($l_ai_Pieces, 0, 23395, $GC_I_MODELID_TANNED_HIDE, 25, $GC_I_MODELID_STEEL_INGOT, 4)
			Leveler_FillMaxPiece($l_ai_Pieces, 1, 23393, $GC_I_MODELID_TANNED_HIDE, 25, $GC_I_MODELID_STEEL_INGOT, 4)
			Leveler_FillMaxPiece($l_ai_Pieces, 2, 23396, $GC_I_MODELID_TANNED_HIDE, 50, $GC_I_MODELID_STEEL_INGOT, 8)
			Leveler_FillMaxPiece($l_ai_Pieces, 3, 23394, $GC_I_MODELID_TANNED_HIDE, 75, $GC_I_MODELID_STEEL_INGOT, 12)
			Leveler_FillMaxPiece($l_ai_Pieces, 4, 23391, $GC_I_MODELID_TANNED_HIDE, 25, $GC_I_MODELID_STEEL_INGOT, 4)
	EndSwitch
	Return $l_ai_Pieces
EndFunc

Func Leveler_FillMaxPiece(ByRef $a_ai_Pieces, $a_i_Row, $a_i_Item, $a_i_Mat1, $a_i_Qty1, $a_i_Mat2, $a_i_Qty2)
	$a_ai_Pieces[$a_i_Row][0] = $a_i_Item
	$a_ai_Pieces[$a_i_Row][1] = $a_i_Mat1
	$a_ai_Pieces[$a_i_Row][2] = $a_i_Qty1
	$a_ai_Pieces[$a_i_Row][3] = $a_i_Mat2
	$a_ai_Pieces[$a_i_Row][4] = $a_i_Qty2
EndFunc

Func Leveler_GetMaxArmorCrafter(ByRef $a_f_X, ByRef $a_f_Y)
	Switch Leveler_PrimaryProfession()
		Case $GC_I_PROFESSION_WARRIOR
			$a_f_X = -891.00
			$a_f_Y = -5382.00
		Case $GC_I_PROFESSION_RANGER, $GC_I_PROFESSION_ASSASSIN
			$a_f_X = -700.00
			$a_f_Y = -5156.00
		Case Else
			$a_f_X = -1682.00
			$a_f_Y = -3970.00
	EndSwitch
EndFunc

Func Leveler_IsCommonMaterial($a_i_Model)
	Switch $a_i_Model
		Case $GC_I_MODELID_CLOTHS, $GC_I_MODELID_TANNED_HIDE, $GC_I_MODELID_DUST, $GC_I_MODELID_BONES
			Return True
	EndSwitch
	Return False
EndFunc

Func Leveler_AddMatNeed(ByRef $a_ai_Models, ByRef $a_ai_Counts, ByRef $a_i_Count, $a_i_Model, $a_i_Qty)
	For $i = 0 To $a_i_Count - 1
		If $a_ai_Models[$i] = $a_i_Model Then
			$a_ai_Counts[$i] += $a_i_Qty
			Return
		EndIf
	Next
	If $a_i_Count >= UBound($a_ai_Models) Then
		ReDim $a_ai_Models[$a_i_Count + 1]
		ReDim $a_ai_Counts[$a_i_Count + 1]
	EndIf
	$a_ai_Models[$a_i_Count] = $a_i_Model
	$a_ai_Counts[$a_i_Count] = $a_i_Qty
	$a_i_Count += 1
EndFunc

Func Leveler_GetMaxArmorMatNeeds($a_b_Common, ByRef $a_ai_Models, ByRef $a_ai_Counts)
	Local $l_ai_M[8]
	Local $l_ai_C[8]
	Local $l_i_Count = 0
	Local $l_ai_Pieces = Leveler_GetMaxArmorPieces()
	For $i = 0 To UBound($l_ai_Pieces) - 1
		If Leveler_IsCommonMaterial($l_ai_Pieces[$i][1]) = $a_b_Common Then
			Leveler_AddMatNeed($l_ai_M, $l_ai_C, $l_i_Count, $l_ai_Pieces[$i][1], $l_ai_Pieces[$i][2])
		EndIf
		If Leveler_IsCommonMaterial($l_ai_Pieces[$i][3]) = $a_b_Common Then
			Leveler_AddMatNeed($l_ai_M, $l_ai_C, $l_i_Count, $l_ai_Pieces[$i][3], $l_ai_Pieces[$i][4])
		EndIf
	Next
	If $l_i_Count = 0 Then
		Local $l_ai_Empty[0]
		$a_ai_Models = $l_ai_Empty
		$a_ai_Counts = $l_ai_Empty
		Return
	EndIf
	ReDim $l_ai_M[$l_i_Count]
	ReDim $l_ai_C[$l_i_Count]
	$a_ai_Models = $l_ai_M
	$a_ai_Counts = $l_ai_C
EndFunc

Func Leveler_BuyMaxArmorMaterials($a_b_Common)
	Local $l_ai_Models, $l_ai_Counts
	Leveler_GetMaxArmorMatNeeds($a_b_Common, $l_ai_Models, $l_ai_Counts)
	For $i = 0 To UBound($l_ai_Models) - 1
		Local $l_i_Need = $l_ai_Counts[$i]
		Local $l_i_Have = Leveler_CountModel($l_ai_Models[$i], False)
		Local $l_i_Short = $l_i_Need - $l_i_Have
		If $l_i_Short <= 0 Then
			Out("[Craft] Inventory already has " & $l_i_Have & "x model " & $l_ai_Models[$i])
			ContinueLoop
		EndIf
		Local $l_i_Buy = $l_i_Short
		If $a_b_Common Then $l_i_Buy = Int(($l_i_Short + 9) / 10)
		Out("[Craft] Buying " & $l_i_Buy & " trader lot(s) of model " & $l_ai_Models[$i] & " (need " & $l_i_Need & ")")
		If Not Merchant_BuyItem($l_ai_Models[$i], $l_i_Buy, True) Then
			If Not Merchant_BuyItem($l_ai_Models[$i], $l_i_Short, False) Then
				Out("[Craft] Failed to buy material " & $l_ai_Models[$i])
				Return False
			EndIf
		EndIf
		Sleep(600)
	Next
	Return True
EndFunc

Func Leveler_CraftMaxArmor()
	Local $l_ai_Pieces = Leveler_GetMaxArmorPieces()
	If Not Leveler_WaitForCrafterOffer($l_ai_Pieces[0][0]) Then Return False
	For $i = 0 To UBound($l_ai_Pieces) - 1
		Local $l_ai_Mats[2][2]
		$l_ai_Mats[0][0] = $l_ai_Pieces[$i][1]
		$l_ai_Mats[0][1] = $l_ai_Pieces[$i][2]
		$l_ai_Mats[1][0] = $l_ai_Pieces[$i][3]
		$l_ai_Mats[1][1] = $l_ai_Pieces[$i][4]
		If Not Leveler_CraftAndEquipPiece($l_ai_Pieces[$i][0], $MAX_ARMOR_GOLD, $l_ai_Mats) Then
			Out("[Craft] Failed to craft max armor piece " & $l_ai_Pieces[$i][0])
			Return False
		EndIf
	Next
	Out("[Craft] Max armor set crafted and equipped")
	Return True
EndFunc

Func Leveler_HasMaxArmor()
	Local $l_ai_Pieces = Leveler_GetMaxArmorPieces()
	For $i = 0 To UBound($l_ai_Pieces) - 1
		If Leveler_OwnsModel($l_ai_Pieces[$i][0]) Then Return True
	Next
	Return False
EndFunc

Func Leveler_HasCraftedWeapon()
	If $g_b_WeaponCraftSkipped Then Return True
	Local $l_i_Model = Leveler_GetCraftedWeaponModel()
	If $l_i_Model = 0 Then Return False
	Return Leveler_OwnsModel($l_i_Model)
EndFunc

Func Leveler_HasExtendedBags()
	If Item_GetBagPtr($GC_I_INVENTORY_BELT_POUCH) <> 0 Then Return True
	If Leveler_IsModelEquipped($MODEL_BELT_POUCH) Then Return True
	If Item_GetBagPtr($GC_I_INVENTORY_BAG1) <> 0 And Item_GetBagPtr($GC_I_INVENTORY_BAG2) <> 0 Then Return True
	Return False
EndFunc

Func Leveler_DestroyStarterArmorAndJunk()
	Local $l_ai_Armor = Leveler_GetStarterArmorModels()
	For $i = 0 To UBound($l_ai_Armor) - 1
		Leveler_DestroyModel($l_ai_Armor[$i])
	Next

	Local $l_ai_Junk[11] = [5819, 6387, 2724, 2652, 2787, 2694, 477, 6498, 2982, 30853, 24897]
	For $i = 0 To UBound($l_ai_Junk) - 1
		Leveler_DestroyModel($l_ai_Junk[$i])
	Next
	Out("[Craft] Destroyed starter armor and junk")
	Return True
EndFunc

Func Leveler_ExtendInventory()
	If Leveler_HasExtendedBags() Then
		Out("[Craft] Belt Pouch already equipped")
		Return True
	EndIf
	If Not Leveler_InteractNpcAt(-11866, 11444, False) Then Return False
	Sleep(400)
	If Item_GetBagPtr($GC_I_INVENTORY_BAG1) = 0 Then
		Merchant_BuyItem($MODEL_BAG, 1, False)
		Sleep(300)
		Local $l_i_Bag = Item_FindItemByModelID($MODEL_BAG)
		If $l_i_Bag <> 0 Then Item_EquipItem($l_i_Bag)
		Sleep(250)
	EndIf
	If Item_GetBagPtr($GC_I_INVENTORY_BAG2) = 0 Then
		Merchant_BuyItem($MODEL_BAG, 1, False)
		Sleep(300)
		Local $l_i_Bag2 = Item_FindItemByModelID($MODEL_BAG)
		If $l_i_Bag2 <> 0 Then Item_EquipItem($l_i_Bag2)
		Sleep(250)
	EndIf
	If Item_GetBagPtr($GC_I_INVENTORY_BELT_POUCH) = 0 Then
		Merchant_BuyItem($MODEL_BELT_POUCH, 1, False)
		Sleep(300)
		Local $l_i_Pouch = Item_FindItemByModelID($MODEL_BELT_POUCH)
		If $l_i_Pouch <> 0 Then Item_EquipItem($l_i_Pouch)
		Sleep(250)
	EndIf
	Out("[Craft] Inventory bags equipped")
	Return True
EndFunc
