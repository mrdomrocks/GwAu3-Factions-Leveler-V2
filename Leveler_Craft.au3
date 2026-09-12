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

Func Leveler_FindInvItem($a_i_Model)
	Local $l_i_Item = Item_FindItemByModelID($a_i_Model)
	If $l_i_Item = 0 Then $l_i_Item = Item_GetBagsItembyModelID($a_i_Model)
	Return $l_i_Item
EndFunc

Func Leveler_IsModelEquipped($a_i_Model)
	If $a_i_Model = 0 Then Return False
	If Item_GetInventoryInfo("WeaponSet0WeaponModelID") = $a_i_Model Then Return True
	If Item_GetInventoryInfo("WeaponSet1WeaponModelID") = $a_i_Model Then Return True
	Local $l_i_Item = Leveler_FindInvItem($a_i_Model)
	If $l_i_Item = 0 Then Return False
	If Item_GetItemInfoByModelID($a_i_Model, "Equipped") <> 0 Then Return True
	If Item_GetItemInfoByModelID($a_i_Model, "BagEquipped") <> 0 Then Return True
	Return False
EndFunc

; Find the crafted item and put it on. Crafting alone leaves it in the bag.
Func Leveler_EquipModel($a_i_Model)
	If Leveler_IsModelEquipped($a_i_Model) Then Return True
	Local $i
	For $i = 1 To 6
		Local $l_i_Item = Leveler_FindInvItem($a_i_Model)
		If $l_i_Item = 0 Then
			Sleep(350)
			ContinueLoop
		EndIf
		Item_EquipItem($l_i_Item)
		Sleep(250)
		Ui_EquipItem($l_i_Item)
		Sleep(400)
		If Leveler_IsModelEquipped($a_i_Model) Then
			Out("[Craft] Equipped model " & $a_i_Model)
			Return True
		EndIf
	Next
	Out("[Craft] Failed to equip model " & $a_i_Model)
	Return False
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

Func Leveler_GetArmorBuyList(ByRef $a_ai_Models, ByRef $a_ai_Counts)
	Local $l_i_Prof = Leveler_PrimaryProfession()
	Switch $l_i_Prof
		Case $GC_I_PROFESSION_RANGER
			Local $l_ai_M[1] = [$GC_I_MODELID_TANNED_HIDE]
			Local $l_ai_C[1] = [6]
			$a_ai_Models = $l_ai_M
			$a_ai_Counts = $l_ai_C
		Case $GC_I_PROFESSION_MONK, $GC_I_PROFESSION_NECROMANCER, $GC_I_PROFESSION_ELEMENTALIST
			If $l_i_Prof = $GC_I_PROFESSION_NECROMANCER Then
				Local $l_ai_M2[2] = [$GC_I_MODELID_TANNED_HIDE, $GC_I_MODELID_DUST]
				Local $l_ai_C2[2] = [6, 1]
				$a_ai_Models = $l_ai_M2
				$a_ai_Counts = $l_ai_C2
			Else
				Local $l_ai_M3[2] = [$GC_I_MODELID_CLOTHS, $GC_I_MODELID_DUST]
				Local $l_ai_C3[2] = [6, 1]
				$a_ai_Models = $l_ai_M3
				$a_ai_Counts = $l_ai_C3
			EndIf
		Case Else
			Local $l_ai_M4[1] = [$GC_I_MODELID_CLOTHS]
			Local $l_ai_C4[1] = [6]
			$a_ai_Models = $l_ai_M4
			$a_ai_Counts = $l_ai_C4
	EndSwitch
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
		If Not Leveler_BuyMaterialShortfall($l_ai_Models[$i], $l_ai_Counts[$i]) Then Return False
	Next
	Return True
EndFunc

Func Leveler_BuyWeaponMaterials()
	If Not Leveler_BuyMaterialShortfall($GC_I_MODELID_WOOD, 4) Then Return False
	If Not Leveler_BuyMaterialShortfall($GC_I_MODELID_DUST, 1) Then Return False
	Return True
EndFunc

Func Leveler_CraftWeapon()
	If Leveler_FindInvItem($MODEL_CLAIRVOYANT_STAFF) = 0 Then
		Local $l_ai_Mats[2][2]
		$l_ai_Mats[0][0] = $GC_I_MODELID_WOOD
		$l_ai_Mats[0][1] = 4
		$l_ai_Mats[1][0] = $GC_I_MODELID_DUST
		$l_ai_Mats[1][1] = 1
		If Not Merchant_CraftItem($MODEL_CLAIRVOYANT_STAFF, $WEAPON_GOLD_COST, $l_ai_Mats) Then
			Out("[Craft] Failed to craft Clairvoyant Staff")
			Return False
		EndIf
		Sleep(800)
	EndIf
	If Not Leveler_EquipModel($MODEL_CLAIRVOYANT_STAFF) Then Return False
	Out("[Craft] Starter staff equipped")
	Return True
EndFunc

Func Leveler_CraftMonasteryArmor()
	Local $l_ai_Pieces = Leveler_GetMonasteryPieces()
	For $i = 0 To UBound($l_ai_Pieces) - 1
		Local $l_i_ItemID = $l_ai_Pieces[$i][0]
		If Leveler_FindInvItem($l_i_ItemID) = 0 Then
			Local $l_ai_Mats[1][2]
			$l_ai_Mats[0][0] = $l_ai_Pieces[$i][1]
			$l_ai_Mats[0][1] = $l_ai_Pieces[$i][2]
			If Not Merchant_CraftItem($l_i_ItemID, $MONASTERY_ARMOR_GOLD, $l_ai_Mats) Then
				Out("[Craft] Failed to craft armor piece " & $l_i_ItemID)
				Return False
			EndIf
			Sleep(800)
		EndIf
		If Not Leveler_EquipModel($l_i_ItemID) Then Return False
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
		If Item_FindItemByModelID($l_ai_Pieces[$i][0]) <> 0 Then Return True
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

Func Leveler_BuyMaterialShortfallInv($a_i_Model, $a_i_Need)
	Local $l_i_Have = Leveler_CountModel($a_i_Model, False)
	Local $l_i_Short = $a_i_Need - $l_i_Have
	If $l_i_Short <= 0 Then
		Out("[Craft] Inventory already has " & $l_i_Have & "x model " & $a_i_Model)
		Return True
	EndIf
	Out("[Craft] Buying " & $l_i_Short & "x model " & $a_i_Model & " for inventory")
	If Not Merchant_BuyItem($a_i_Model, $l_i_Short, True) Then
		If Not Merchant_BuyItem($a_i_Model, $l_i_Short, False) Then
			Out("[Craft] Failed to buy material " & $a_i_Model)
			Return False
		EndIf
	EndIf
	Sleep(500)
	Return True
EndFunc

Func Leveler_CraftSeitungArmor()
	Local $l_ai_Pieces = Leveler_GetSeitungPieces()
	For $i = 0 To UBound($l_ai_Pieces) - 1
		Local $l_i_ItemID = $l_ai_Pieces[$i][0]
		If Leveler_FindInvItem($l_i_ItemID) = 0 Then
			Local $l_ai_Mats[1][2]
			$l_ai_Mats[0][0] = $l_ai_Pieces[$i][1]
			$l_ai_Mats[0][1] = $l_ai_Pieces[$i][2]
			If Not Merchant_CraftItem($l_i_ItemID, $SEITUNG_ARMOR_GOLD, $l_ai_Mats) Then
				Out("[Craft] Failed to craft Seitung armor piece " & $l_i_ItemID)
				Return False
			EndIf
			Sleep(800)
		EndIf
		If Not Leveler_EquipModel($l_i_ItemID) Then Return False
	Next
	Out("[Craft] Seitung armor set crafted and equipped")
	Return True
EndFunc

Func Leveler_HasSeitungArmor()
	Local $l_ai_Pieces = Leveler_GetSeitungPieces()
	For $i = 0 To UBound($l_ai_Pieces) - 1
		If Item_FindItemByModelID($l_ai_Pieces[$i][0]) <> 0 Then Return True
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
	Local $l_ai_Pieces = Leveler_GetSeitungPieces()
	For $i = 0 To UBound($l_ai_Pieces) - 1
		Leveler_DestroyModel($l_ai_Pieces[$i][0])
	Next
	Out("[Craft] Destroyed Seitung armor")
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
	For $i = 0 To UBound($l_ai_Pieces) - 1
		If Leveler_FindInvItem($l_ai_Pieces[$i][0]) = 0 Then
			Local $l_ai_Mats[2][2]
			$l_ai_Mats[0][0] = $l_ai_Pieces[$i][1]
			$l_ai_Mats[0][1] = $l_ai_Pieces[$i][2]
			$l_ai_Mats[1][0] = $l_ai_Pieces[$i][3]
			$l_ai_Mats[1][1] = $l_ai_Pieces[$i][4]
			If Not Merchant_CraftItem($l_ai_Pieces[$i][0], $MAX_ARMOR_GOLD, $l_ai_Mats) Then
				Out("[Craft] Failed to craft max armor piece " & $l_ai_Pieces[$i][0])
				Return False
			EndIf
			Sleep(800)
		EndIf
		If Not Leveler_EquipModel($l_ai_Pieces[$i][0]) Then Return False
	Next
	Out("[Craft] Max armor set crafted and equipped")
	Return True
EndFunc

Func Leveler_HasMaxArmor()
	Local $l_ai_Pieces = Leveler_GetMaxArmorPieces()
	For $i = 0 To UBound($l_ai_Pieces) - 1
		If Item_FindItemByModelID($l_ai_Pieces[$i][0]) <> 0 Then Return True
	Next
	Return False
EndFunc

Func Leveler_HasCraftedWeapon()
	If Item_FindItemByModelID($MODEL_CLAIRVOYANT_STAFF) <> 0 Then Return True
	If Item_GetInventoryInfo("WeaponSet0WeaponModelID") = $MODEL_CLAIRVOYANT_STAFF Then Return True
	Return False
EndFunc

Func Leveler_HasExtendedBags()
	If Item_GetBagPtr($GC_I_INVENTORY_BAG1) = 0 Then Return False
	If Item_GetBagPtr($GC_I_INVENTORY_BAG2) = 0 Then Return False
	Return True
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
