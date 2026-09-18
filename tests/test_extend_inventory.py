#!/usr/bin/env python3
"""Source-level checks for the Extend Inventory bag stall fix.

These do not talk to Guild Wars. They lock the scan-then-equip-or-buy-one
contract so Kestrel Shade cannot mass-buy Bags into every backpack slot.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
CRAFT = (ROOT / "Leveler_Craft.au3").read_text()
STEPS = (ROOT / "Leveler_Steps.au3").read_text()
CONST = (ROOT / "Leveler_Const.au3").read_text()


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
        for name in (
            "Leveler_ExtendInventory",
            "Leveler_EnsureBagSlot",
            "Leveler_EquipLooseBagIntoSlot",
            "Leveler_EquipBagItem",
            "Leveler_BuyInventoryBag",
            "Leveler_FindLooseBagItem",
        ):
            body = func_body(CRAFT, name)
            self.assertNotIn("Item_FindItemByModelID", body, name)
            self.assertNotIn("$GC_I_HEADER_EQUIP_BAG", body, name)

    def test_scan_backpack_then_equip_or_buy_one(self):
        ensure = func_body(CRAFT, "Leveler_EnsureBagSlot")
        self.assertIn("Leveler_FindLooseBagItem", ensure)
        self.assertIn("Scan start bag", ensure)
        self.assertIn("Buying one", ensure)
        self.assertIn("Leveler_BuyInventoryBag", ensure)
        self.assertIn("Leveler_EquipLooseBagIntoSlot", ensure)
        found_at = ensure.find("Leveler_FindLooseBagItem")
        buy_at = ensure.find("Leveler_BuyInventoryBag")
        equip_at = ensure.find("Leveler_EquipLooseBagIntoSlot")
        self.assertLess(found_at, buy_at)
        self.assertLess(found_at, equip_at)

    def test_bag_click_drag_not_kmoveitem_useitem_or_equipbag(self):
        equip = func_body(CRAFT, "Leveler_EquipLooseBagIntoSlot")
        send = func_body(CRAFT, "Leveler_EquipBagItem")
        dest = func_body(CRAFT, "Leveler_LegalBagDest")
        close = func_body(CRAFT, "Leveler_CloseMerchantWindow")
        self.assertIn("Leveler_CloseMerchantWindow()", equip)
        self.assertIn("Leveler_OpenInventoryForBagEquip", equip)
        self.assertIn("Leveler_EquipBagItem", equip)
        self.assertIn("Leveler_LegalBagDest", equip)
        self.assertIn("Leveler_FocusGwForClick", equip)
        self.assertIn("Leveler_RestoreLevelerGui", equip)
        click = func_body(CRAFT, "Leveler_ClickGwClient")
        drag = func_body(CRAFT, "Leveler_DragGwClient")
        focus = func_body(CRAFT, "Leveler_FocusGwForClick")
        layout = func_body(CRAFT, "Leveler_InventoryLayout")
        self.assertIn("Leveler_ClickGwClient", send)
        self.assertIn("Leveler_DragGwClient", send)
        self.assertIn("Leveler_ClientToScreen", click)
        self.assertIn("Leveler_ClientToScreen", drag)
        self.assertIn('Opt("MouseCoordMode", 1)', click)
        self.assertIn('Opt("MouseCoordMode", 1)', drag)
        self.assertIn("MouseClickDrag", drag)
        self.assertNotIn("ControlClick", click)
        self.assertNotIn("ControlClick", drag)
        self.assertIn("@SW_HIDE", focus)
        self.assertIn("WinActivate", focus)
        self.assertIn("$BAG_INV_COMPASS", layout)
        self.assertIn("top-backpack", func_body(CRAFT, "Leveler_InventoryLayoutName"))
        self.assertIn("paperdoll-backpack", func_body(CRAFT, "Leveler_InventoryLayoutName"))
        self.assertIn("bottom-backpack", func_body(CRAFT, "Leveler_InventoryLayoutName"))
        self.assertIn("Leveler_LegalBagDest", send)
        self.assertNotIn("0x100001AF", send)
        self.assertNotIn("$g_d_MoveMap", send)
        self.assertNotIn("$g_p_MoveMap", send)
        self.assertNotIn("Core_Enqueue", send)
        self.assertNotRegex(send, r"Item_UseItem\(")
        self.assertNotRegex(equip, r"Item_UseItem\(")
        self.assertNotIn("$GC_I_HEADER_ITEM_USE", send)
        self.assertNotIn("$GC_I_HEADER_EQUIP_BAG", send)
        self.assertNotIn("Core_SendPacket", send)
        self.assertNotIn("Ui_EquipItem", equip)
        self.assertNotIn("Ui_EquipItem", send)
        self.assertNotIn("Item_EquipItem", equip)
        self.assertNotIn("Item_EquipItem", send)
        self.assertNotIn("$LEVELER_UIMSG_MOVE_ITEM", CONST)
        self.assertIn("$BAG_INV_COMPASS", CONST)
        self.assertIn("$BAG_INV_PAPER_GRID_Y", CONST)
        self.assertIn("$MODEL_BAG", dest)
        self.assertIn("$GC_I_INVENTORY_BAG1", dest)
        self.assertIn("$GC_I_INVENTORY_BAG2", dest)
        self.assertIn("$GC_I_INVENTORY_BELT_POUCH", dest)
        self.assertIn("Agent_CancelAction", close)
        self.assertLess(
            close.find("Merchant_GetMerchantItemsSize() = 0"),
            close.find("Agent_CancelAction"),
        )
        open_inv = func_body(CRAFT, "Leveler_OpenInventoryForBagEquip")
        self.assertIn("$GC_I_CONTROL_INVENTORY_OPEN_INVENTORY", open_inv)
        self.assertIn("$GC_I_CONTROL_INVENTORY_OPEN_BACKPACK", open_inv)
        self.assertIn("$GC_I_CONTROL_PANEL_CLOSE_ALL_PANELS", open_inv)
        self.assertNotIn("$GC_I_CONTROL_INVENTORY_OPEN_BELT_POUCH", open_inv)
        self.assertNotIn("$GC_I_CONTROL_INVENTORY_OPEN_BAG_1", open_inv)
        self.assertIn("$GC_I_INVENTORY_BACKPACK", send)
        self.assertIn("Inventory double-click", send)

    def test_bags_never_target_belt_pouch(self):
        dest = func_body(CRAFT, "Leveler_LegalBagDest")
        bag_block = dest[dest.find("$a_i_Model = $MODEL_BAG") :]
        self.assertIn("If $a_i_Bag = $GC_I_INVENTORY_BELT_POUCH Then Return 0", bag_block)
        self.assertIn("$GC_I_INVENTORY_BAG1", bag_block)
        self.assertIn("$GC_I_INVENTORY_BAG2", bag_block)
        pouch_block = dest[dest.find("$a_i_Model = $MODEL_BELT_POUCH") : dest.find("$a_i_Model = $MODEL_BAG")]
        self.assertIn("$GC_I_INVENTORY_BELT_POUCH", pouch_block)
        send = func_body(CRAFT, "Leveler_EquipBagItem")
        self.assertIn("Leveler_LegalBagDest", send)
        self.assertNotIn("$GC_I_INVENTORY_BELT_POUCH", send.split("Leveler_LegalBagDest")[0])


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
        self.assertIn("Leveler_HasExtendedBags()", body)
        self.assertIn("Leveler_EquipOwnedInventoryBags()", body)
        step = func_body(STEPS, "Leveler_Step_ExtendInventory")
        self.assertIn("Leveler_EquipOwnedInventoryBags()", step)

    def test_loose_backpack_bags_block_further_buys(self):
        step = func_body(STEPS, "Leveler_Step_ExtendInventory")
        self.assertIn("not buying more", step)
        extend = func_body(CRAFT, "Leveler_ExtendInventory")
        self.assertIn("not buying more", extend)
        extend_owned_at = extend.find("Leveler_EquipOwnedInventoryBags")
        extend_buy_at = extend.find("Leveler_EnsureBagSlot")
        self.assertGreater(extend_owned_at, 0)
        self.assertGreater(extend_buy_at, extend_owned_at)
        buy = func_body(CRAFT, "Leveler_BuyInventoryBag")
        self.assertIn("Already have bag model", buy)
        self.assertIn("Merchant_BuyItem($a_i_Model, 1, False)", buy)

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
        self.assertNotIn("Item_GetItemBySlot", find)
        self.assertNotIn("Item_GetItemBySlot", count)
        self.assertIn("Leveler_BagScanSlotCount", find)
        self.assertIn("Leveler_ItemPtrInBagCell", find)
        self.assertIn("$BAG_BACKPACK_SCAN_SLOTS", scan)
        self.assertIn("Scanning start bag slots", find)
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

    def test_compact_cell20_is_left_of_compass_not_aa114ff_miss(self):
        """stall.webp 1280x800: cell 20 and pouch tab must not sit under the compass."""
        w = 1280
        width = 240
        compass = 176
        top = 8
        grid_x = 12
        grid_y = 58
        cell = 33
        tab_y = 42
        self.assertIn("$BAG_INV_WIDTH = 240", CONST)
        self.assertIn("$BAG_INV_COMPASS = 176", CONST)
        self.assertIn("$BAG_INV_CELL = 33", CONST)
        left = w - compass - width
        col = (20 - 1) % 5
        row = (20 - 1) // 5
        x = left + grid_x + col * cell + cell // 2
        y = top + grid_y + row * cell + cell // 2
        tx = left + grid_x + 1 * cell + cell // 2
        ty = top + tab_y
        self.assertEqual(left, 864)
        self.assertLess(x, w - compass)
        self.assertGreater(x, left)
        self.assertNotEqual((x, y), (1238, 201))
        self.assertNotEqual((x, y), (1058, 201))
        self.assertLess(tx, x)
        self.assertLess(ty, y)
        self.assertEqual((x, y), (1024, 181))
        self.assertEqual((tx, ty), (925, 50))


if __name__ == "__main__":
    unittest.main()
