#!/usr/bin/env python3
"""Source-level checks for the Extend Inventory bag stall fix.

These do not talk to Guild Wars. They lock the buy/equip contract so the
Kestrel Shade loop cannot come back from Item_FindItemByModelID + EquipItem
or from mass-buying Bags into every backpack slot.
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
            "Leveler_UseLooseBagIntoSlot",
            "Leveler_BuyInventoryBag",
            "Leveler_FindLooseBagItem",
        ):
            body = func_body(CRAFT, name)
            self.assertNotIn("Item_FindItemByModelID", body, name)

    def test_useitem_after_closing_merchant(self):
        use = func_body(CRAFT, "Leveler_UseLooseBagIntoSlot")
        self.assertIn("Leveler_CloseMerchantWindow()", use)
        self.assertIn("Item_UseItem", use)
        self.assertNotIn("Item_EquipItem", use)
        close = func_body(CRAFT, "Leveler_CloseMerchantWindow")
        self.assertIn("Agent_CancelAction", close)

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
        buy = func_body(CRAFT, "Leveler_BuyInventoryBag")
        self.assertIn("Already have bag model", buy)
        self.assertIn("Leveler_FindLooseBagItem", buy)
        self.assertIn("Merchant_BuyItem($a_i_Model, 1, False)", buy)

    def test_pouch_is_bought_before_extra_bags(self):
        body = func_body(CRAFT, "Leveler_ExtendInventory")
        pouch_at = body.find("Leveler_BuyInventoryBag($MODEL_BELT_POUCH)")
        bag_at = body.find("Leveler_BuyInventoryBag($MODEL_BAG)")
        self.assertGreater(pouch_at, 0)
        self.assertGreater(bag_at, pouch_at)

    def test_buy_caps_prevent_mass_fill(self):
        self.assertIn("$BAG_MAX_POUCH_BUYS = 1", CONST)
        self.assertIn("$BAG_MAX_BAG_BUYS = 2", CONST)
        body = func_body(CRAFT, "Leveler_ExtendInventory")
        self.assertIn("$BAG_MAX_POUCH_BUYS", body)
        self.assertIn("$BAG_MAX_BAG_BUYS", body)

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

    def test_find_loose_bags_skips_merchant_listings(self):
        body = func_body(CRAFT, "Leveler_FindLooseBagItem")
        self.assertIn("Item_GetItemBySlot", body)
        self.assertIn("Item_GetInventoryArray", body)
        self.assertIn("BagPtr", body)  # comment + 0xC bag ptr filter


if __name__ == "__main__":
    unittest.main()
