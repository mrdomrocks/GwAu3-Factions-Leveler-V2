#!/usr/bin/env python3
"""Source-level checks for the Extend Inventory bag stall fix.

These do not talk to Guild Wars. They lock scan-then-buy-one and the Wine
soft-skip so Kestrel Shade cannot mass-buy Bags or retry ruled-out equip APIs.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
CRAFT = (ROOT / "Leveler_Craft.au3").read_text()
STEPS = (ROOT / "Leveler_Steps.au3").read_text()
CONST = (ROOT / "Leveler_Const.au3").read_text()
STATUS = (ROOT / "Leveler_Status.au3").read_text()
MAIN = (ROOT / "Factions_Character_Leveler.au3").read_text()

BAG_FUNCS = (
    "Leveler_ExtendInventory",
    "Leveler_EnsureBagSlot",
    "Leveler_SkipBagEquip",
    "Leveler_SkipBagEquipIfOwned",
    "Leveler_BagsStepComplete",
    "Leveler_BuyInventoryBag",
    "Leveler_FindLooseBagItem",
    "Leveler_HasOwnedSmallBag",
)


def func_body(src: str, name: str) -> str:
    match = re.search(rf"Func {name}\((.*?)EndFunc", src, re.S)
    if not match:
        raise AssertionError(f"missing {name}")
    return match.group(0)


class ExtendInventoryContract(unittest.TestCase):
    def test_craft_weapon_stays_clairvoyant_staff(self):
        body = func_body(CRAFT, "Leveler_CraftWeapon")
        self.assertIn("$MODEL_CLAIRVOYANT_STAFF", body)
        self.assertNotIn("$MODEL_SAI", body)

    def test_extend_inventory_does_not_equip_merchant_listings(self):
        for name in BAG_FUNCS:
            body = func_body(CRAFT, name)
            self.assertNotIn("Item_FindItemByModelID", body, name)
            self.assertNotIn("$GC_I_HEADER_EQUIP_BAG", body, name)

    def test_scan_backpack_then_skip_or_buy_one(self):
        ensure = func_body(CRAFT, "Leveler_EnsureBagSlot")
        self.assertIn("Leveler_FindLooseBagItem", ensure)
        self.assertIn("Scan start bag", ensure)
        self.assertIn("Buying one", ensure)
        self.assertIn("Leveler_BuyInventoryBag", ensure)
        self.assertIn("Leveler_SkipBagEquip", ensure)
        self.assertNotIn("Leveler_EquipLooseBagIntoSlot", ensure)
        found_at = ensure.find("Leveler_FindLooseBagItem")
        buy_at = ensure.find("Leveler_BuyInventoryBag")
        skip_at = ensure.find("Leveler_SkipBagEquip")
        self.assertLess(found_at, buy_at)
        self.assertLess(found_at, skip_at)

    def test_bag_step_never_sends_ruled_out_equip(self):
        """c6a5520 Item_EquipItem was a no-op. Do not ship another equip variant."""
        self.assertNotIn("Func Leveler_EquipBagItem", CRAFT)
        self.assertNotIn("Func Leveler_EquipLooseBagIntoSlot", CRAFT)
        self.assertNotIn("Func Leveler_EquipOwnedInventoryBags", CRAFT)
        self.assertNotIn("Func Leveler_LegalBagDest", CRAFT)
        for name in BAG_FUNCS:
            body = func_body(CRAFT, name)
            self.assertNotRegex(body, r"Item_EquipItem\(", name)
            self.assertNotRegex(body, r"Ui_EquipItem\(", name)
            self.assertNotRegex(body, r"Item_UseItem\(", name)
            self.assertNotIn("$GC_I_HEADER_EQUIP_BAG", body, name)
            self.assertNotIn("$GC_I_HEADER_ITEM_USE", body, name)
            self.assertNotIn("Core_SendPacket", body, name)
            self.assertNotIn("0x100001AF", body, name)
            self.assertNotIn("mouse_event", body, name)
            self.assertNotIn("MouseClickDrag", body, name)
            self.assertNotIn("SetCursorPos", body, name)
        self.assertNotIn("Leveler_OpenInventoryForBagEquip", CRAFT)
        self.assertNotIn("Leveler_SendInputClick", CRAFT)
        self.assertNotIn("Leveler_ClickGwClient", CRAFT)
        self.assertNotIn("Leveler_FocusGwForClick", CRAFT)
        self.assertNotIn("Leveler_RestoreLevelerGui", CRAFT)
        self.assertNotIn("Leveler_BackpackCellXY", CRAFT)
        self.assertNotIn("Leveler_DragGwClient", CRAFT)
        self.assertNotIn("Leveler_BagTabXY", CRAFT)
        self.assertNotIn("$LEVELER_UIMSG_MOVE_ITEM", CONST)
        self.assertNotIn("$BAG_INV_COMPASS", CONST)
        self.assertIn("$LEVELER_SKIP_BAG_EQUIP = True", CONST)
        self.assertIn("$g_b_BagsStepSkipped", CONST)
        skip = func_body(CRAFT, "Leveler_SkipBagEquip")
        self.assertIn("$g_b_BagsStepSkipped = True", skip)
        self.assertIn("Skipping bag-slot install", skip)
        self.assertIn("Return True", skip)
        find = func_body(CRAFT, "Leveler_FindLooseBagItem")
        self.assertIn("Item_GetItemBySlot", find)
        self.assertIn("Leveler_ItemIdFromPtr", find)
        self.assertIn("Belt Pouch item id", find)
        self.assertIn("$GC_I_TYPE_BAG", func_body(CRAFT, "Leveler_ItemIsSmallBag"))

    def test_craft_weapon_still_uses_paperdoll_equip(self):
        body = func_body(CRAFT, "Leveler_EquipModel")
        self.assertIn("Item_EquipItem", body)
        self.assertIn("Ui_EquipItem", body)

    def test_missing_bags_fail_the_step(self):
        body = func_body(CRAFT, "Leveler_ExtendInventory")
        self.assertIn("Inventory bags are still missing after the merchant", body)
        self.assertRegex(body, r"still missing after the merchant[\s\S]*Return False")

    def test_already_extended_or_owned_bags_complete(self):
        body = func_body(CRAFT, "Leveler_ExtendInventory")
        self.assertIn("Leveler_BagsStepComplete()", body)
        self.assertIn("Leveler_SkipBagEquipIfOwned()", body)
        step = func_body(STEPS, "Leveler_Step_ExtendInventory")
        self.assertIn("Leveler_BagsStepComplete()", step)
        self.assertIn("Leveler_SkipBagEquipIfOwned()", step)
        self.assertIn("Return True", step)
        self.assertNotIn("Retrying Item_EquipItem", step)
        status = func_body(STATUS, "Leveler_StatusCheck")
        self.assertIn("Leveler_BagsStepComplete()", status)

    def test_loose_backpack_bags_block_further_buys(self):
        step = func_body(STEPS, "Leveler_Step_ExtendInventory")
        self.assertIn("not buying more", step)
        extend = func_body(CRAFT, "Leveler_ExtendInventory")
        self.assertIn("not buying more", extend)
        extend_owned_at = extend.find("Leveler_SkipBagEquipIfOwned")
        extend_buy_at = extend.find("Leveler_EnsureBagSlot")
        self.assertGreater(extend_owned_at, 0)
        self.assertGreater(extend_buy_at, extend_owned_at)
        buy = func_body(CRAFT, "Leveler_BuyInventoryBag")
        self.assertIn("Already have bag model", buy)
        self.assertIn("Merchant_BuyItem($a_i_Model, 1, False)", buy)
        owned = extend[extend_owned_at:]
        self.assertIn("Return True", owned.split("Leveler_EnsureBagSlot")[0])

    def test_pouch_slot_before_extra_bags(self):
        body = func_body(CRAFT, "Leveler_ExtendInventory")
        pouch_at = body.find("Leveler_EnsureBagSlot($MODEL_BELT_POUCH")
        bag_at = body.find("Leveler_EnsureBagSlot($MODEL_BAG")
        self.assertGreater(pouch_at, 0)
        self.assertGreater(bag_at, pouch_at)

    def test_buy_caps_prevent_mass_fill(self):
        self.assertIn("$BAG_MAX_POUCH_BUYS = 1", CONST)
        self.assertIn("$BAG_MAX_BAG_BUYS = 2", CONST)
        buy = func_body(CRAFT, "Leveler_BuyInventoryBag")
        self.assertIn("Merchant_BuyItem($a_i_Model, 1, False)", buy)

    def test_has_extended_bags_uses_bag_slots_not_worn_items(self):
        body = func_body(CRAFT, "Leveler_HasExtendedBags")
        self.assertNotIn("Leveler_IsModelEquipped", body)
        self.assertIn("BeltPouchPtr", body)
        self.assertIn("Bag1Ptr", body)

    def test_merchant_wait_and_buy_return_are_checked(self):
        buy = func_body(CRAFT, "Leveler_BuyInventoryBag")
        self.assertIn("Leveler_WaitForMerchantOffer", buy)
        self.assertIn("If Not Merchant_BuyItem", buy)
        self.assertIn("$BAG_GOLD_COST", buy)
        self.assertIn("$BAG_GOLD_COST = 100", CONST)

    def test_find_loose_bags_walks_every_backpack_slot(self):
        find = func_body(CRAFT, "Leveler_FindLooseBagItem")
        count = func_body(CRAFT, "Leveler_CountLooseBags")
        scan = func_body(CRAFT, "Leveler_BagScanSlotCount")
        cell = func_body(CRAFT, "Leveler_ItemPtrInBagCell")
        self.assertIn("Item_GetItemBySlot", find)
        self.assertIn("Leveler_ItemIdFromPtr", find)
        self.assertIn("Belt Pouch item id", find)
        self.assertIn('Item_GetItemInfoByPtr($a_p_Item, "ItemID")', func_body(CRAFT, "Leveler_ItemIdFromPtr"))
        self.assertIn("Item_GetItemBySlot", cell)
        self.assertIn("Leveler_BagScanSlotCount", find)
        self.assertIn("Leveler_ItemPtrInBagCell", find)
        self.assertIn("$BAG_BACKPACK_SCAN_SLOTS", scan)
        self.assertIn("Scanning start bag slots", find)
        self.assertIn("$GC_I_TYPE_BAG", find)
        self.assertIn("Leveler_ItemIsSmallBag", find)
        self.assertIn("Leveler_ItemIsSmallBag", count)
        self.assertIn("$GC_I_TYPE_BAG", func_body(CRAFT, "Leveler_ItemIsSmallBag"))
        self.assertIn("not TYPE_BAG", find)
        self.assertIn("$GC_I_INVENTORY_ITEMTYPE", find)
        self.assertIn("$GC_I_INVENTORY_BACKPACK", find)
        self.assertNotIn("$GC_I_INVENTORY_BELT_POUCH", find)
        self.assertNotIn("$GC_I_INVENTORY_BAG1", find)
        self.assertIn("$BAG_BACKPACK_SCAN_SLOTS = 20", CONST)
        self.assertIn("ItemArray", cell)
        self.assertIn("BagPtr", find)

    def test_find_loose_bags_skips_merchant_listings(self):
        body = func_body(CRAFT, "Leveler_FindLooseBagItem")
        self.assertIn("Item_GetInventoryArray", body)
        self.assertIn("$GC_I_INVENTORY_BACKPACK", body)
        self.assertIn("BagPtr", body)

    def test_out_tees_to_leveler_log_files(self):
        out = func_body(MAIN, "Out")
        log = func_body(MAIN, "Leveler_FileLog")
        self.assertIn("Leveler_FileLog", out)
        self.assertIn(r'leveler.log', log)
        self.assertIn(r"Z:\tmp\leveler-kestrel.log", log)
        self.assertIn("FileFlush", log)

    def test_small_bag_requires_type_bag_not_just_model(self):
        helper = func_body(CRAFT, "Leveler_ItemIsSmallBag")
        self.assertIn("$GC_I_TYPE_BAG", helper)
        self.assertIn('Item_GetItemInfoByPtr($a_p_Item, "ItemType")', helper)
        self.assertIn('Item_GetItemInfoByPtr($a_p_Item, "ModelID")', helper)
        find = func_body(CRAFT, "Leveler_FindLooseBagItem")
        self.assertIn("not TYPE_BAG", find)
        self.assertLess(find.find("Leveler_ItemIsSmallBag"), find.find("Return $l_i_Id"))

    def test_owned_bag_skips_install_instead_of_equipitem(self):
        """Kestrel cell 1 id 1640 type=3 model=34. Complete the step; do not Item_EquipItem."""
        skip = func_body(CRAFT, "Leveler_SkipBagEquipIfOwned")
        self.assertIn("Leveler_HasOwnedSmallBag", skip)
        self.assertIn("Leveler_SkipBagEquip", skip)
        complete = func_body(CRAFT, "Leveler_BagsStepComplete")
        self.assertIn("$LEVELER_SKIP_BAG_EQUIP", complete)
        self.assertIn("Leveler_HasOwnedSmallBag", complete)
        self.assertIn("$g_b_BagsStepSkipped", complete)
        step = func_body(STEPS, "Leveler_Step_ExtendInventory")
        self.assertIn("Leveler_SkipBagEquipIfOwned()", step)
        self.assertNotRegex(step, r"Item_EquipItem")
        self.assertNotIn("928,514", CRAFT)
        self.assertNotIn("mouse_event", CRAFT)
        self.assertNotIn("$GC_I_HEADER_EQUIP_BAG", func_body(CRAFT, "Leveler_ExtendInventory"))

    def test_belt_pouch_item_id_uses_gwau3_slot_and_itemid(self):
        """GwAu3: Item_GetItemBySlot then Item_GetItemInfoByPtr(..., 'ItemID') / Item_ItemID."""
        fromptr = func_body(CRAFT, "Leveler_ItemIdFromPtr")
        self.assertIn('Item_GetItemInfoByPtr($a_p_Item, "ItemID")', fromptr)
        self.assertIn("Item_ItemID", fromptr)
        find = func_body(CRAFT, "Leveler_FindLooseBagItem")
        self.assertIn("Item_GetItemBySlot($l_i_Bag, $s)", find)
        self.assertIn("Belt Pouch item id", find)
        log = func_body(CRAFT, "Leveler_LogBagState")
        self.assertIn('Item_GetBagInfo($GC_I_INVENTORY_BELT_POUCH, "ContainerItem")', log)
        self.assertIn("Item_GetItemInfoByPtr", CONST)
        self.assertIn("ContainerItem", CONST)


if __name__ == "__main__":
    unittest.main()
