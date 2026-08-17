#!/usr/bin/env python3
"""Locate synchronized shop assets in both runtimes and reject pixel offsets."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageChops, ImageStat


REFERENCE_SIZE = (1920, 1080)
ACCEPTANCE_OPERATION_NAMES = {
    "01_shop_entry",
    "02_offer_hover",
    "02a_entry_first_offer_pressed",
    "03_refresh_curtain",
    "04_refresh_complete",
    "05_purchase_complete",
    "09_second_purchase",
    "10_party_full_purchase",
    "12_paid_refresh_complete",
    "13_bag_pet_purchase",
    "14_bag_with_pet_open",
    "17b_exit_pressed",
    "18_exit_to_route",
    "19_reenter_shop_after_exit",
}
ASSETS = (
    ("shop_facade", "01_shop_entry", "shop_facade.png", (31, 86), 4, None),
    (
        "merchant",
        "01_shop_entry",
        "../../route/shop/characters/generated/shop_character_001.png",
        (813, 593),
        6,
        (177, 177),
    ),
    ("refresh_bell", "01_shop_entry", "refresh_bell_normal.png", (945, 712), 6, None),
    ("refresh_bell_hover", "02b_refresh_hover", "refresh_bell_hover.png", (945, 712), 6, None),
    ("shared_bag", "01_shop_entry", "shared_bag_closed.png", (313, 776), 6, None),
    ("shared_bag_open", "07_bag_open", "shared_bag_open.png", (313, 776), 6, None),
    ("shared_bag_inventory", "07_bag_open", "shared_bag_inventory.png", (502, 379), 6, None),
    ("shared_party_shelf", "01_shop_entry", "shared_party_shelf.png", (519, 587), 6, None),
    ("shared_coin_panel", "01_shop_entry", "shared_coin_panel.png", (1303, 885), 6, None),
    ("shared_exit", "01_shop_entry", "shared_exit_normal.png", (1410, 490), 6, None),
    ("shared_exit_hover", "17_exit_hover", "shared_exit_hover.png", (1410, 490), 6, None),
    ("refresh_curtain", "03_refresh_curtain", "refresh_curtain.png", (492, 313), 8, None),
    (
        "entry_offer_1",
        "01_shop_entry",
        "../../shared/pets/generated/pal_016.png",
        (502, 364),
        6,
        (152, 152),
    ),
    (
        "entry_offer_2",
        "01_shop_entry",
        "../../shared/pets/generated/pal_053.png",
        (827, 364),
        6,
        (152, 152),
    ),
    (
        "entry_offer_3",
        "01_shop_entry",
        "../../shared/pets/generated/pal_138.png",
        (1152, 394),
        6,
        (152, 152),
    ),
    (
        "entry_offer_2_hover",
        "02_entry_second_offer_hover",
        "../../shared/pets/generated/pal_053.png",
        (827, 364),
        6,
        (152, 152),
    ),
    (
        "entry_offer_3_hover",
        "02_entry_third_offer_hover",
        "../../shared/pets/generated/pal_138.png",
        (1152, 394),
        6,
        (152, 152),
    ),
    (
        "refresh_offer_1",
        "04_refresh_complete",
        "../../shared/pets/generated/pal_009.png",
        (502, 364),
        6,
        (152, 152),
    ),
    (
        "refresh_offer_2",
        "04_refresh_complete",
        "../../shared/pets/generated/pal_110.png",
        (827, 364),
        6,
        (152, 152),
    ),
    (
        "refresh_offer_3",
        "04_refresh_complete",
        "../../shared/pets/generated/pal_111.png",
        (1152, 394),
        6,
        (152, 152),
    ),
    (
        "refresh_offer_1_hover",
        "04a_refresh_first_offer_hover",
        "../../shared/pets/generated/pal_009.png",
        (502, 364),
        6,
        (152, 152),
    ),
    (
        "refresh_offer_2_hover",
        "04b_refresh_second_offer_hover",
        "../../shared/pets/generated/pal_110.png",
        (827, 364),
        6,
        (152, 152),
    ),
    (
        "refresh_offer_3_hover",
        "04c_refresh_third_offer_hover",
        "../../shared/pets/generated/pal_111.png",
        (1152, 394),
        6,
        (152, 152),
    ),
    (
        "party_pet_wide",
        "05_purchase_complete",
        "../../shared/pets/generated/pal_002.png",
        (565, 805),
        6,
        (154, 124),
    ),
    (
        "party_pet_square",
        "05_purchase_complete",
        "../../shared/pets/generated/pal_009.png",
        (757, 804),
        6,
        (126, 126),
    ),
    (
        "party_pet_slot_3",
        "10_party_full_purchase",
        "../../shared/pets/generated/pal_110.png",
        (933, 804),
        6,
        (126, 126),
    ),
    (
        "party_pet_slot_4",
        "10_party_full_purchase",
        "../../shared/pets/generated/pal_111.png",
        (1113, 804),
        6,
        (126, 126),
    ),
    (
        "paid_refresh_offer_1",
        "12_paid_refresh_complete",
        "../../shared/pets/generated/pal_017.png",
        (502, 364),
        6,
        (152, 152),
    ),
    (
        "paid_refresh_offer_2",
        "12_paid_refresh_complete",
        "../../shared/pets/generated/pal_027.png",
        (827, 364),
        6,
        (152, 152),
    ),
    (
        "paid_refresh_offer_3",
        "12_paid_refresh_complete",
        "../../shared/pets/generated/pal_105.png",
        (1152, 413),
        6,
        (152, 114),
    ),
    (
        "paid_refresh_offer_1_hover",
        "12a_paid_refresh_first_offer_hover",
        "../../shared/pets/generated/pal_017.png",
        (502, 364),
        6,
        (152, 152),
    ),
    (
        "paid_refresh_offer_2_hover",
        "12b_paid_refresh_second_offer_hover",
        "../../shared/pets/generated/pal_027.png",
        (827, 364),
        6,
        (152, 152),
    ),
    (
        "paid_refresh_offer_3_hover",
        "12c_paid_refresh_third_offer_hover",
        "../../shared/pets/generated/pal_105.png",
        (1152, 413),
        6,
        (152, 114),
    ),
)
ASSET_MAX_MEAN_OPAQUE_RGB_ERROR = {
    "party_pet_wide": 0.01,
    "party_pet_square": 0.01,
    "party_pet_slot_3": 0.01,
    "party_pet_slot_4": 0.01,
}
OVERLAPS = (
    (
        "party_shelf_above_bag",
        "shared_party_shelf.png",
        (519, 587),
        "shared_bag_closed.png",
        (313, 776),
        0.95,
    ),
    (
        "coin_panel_above_exit",
        "shared_coin_panel.png",
        (1303, 885),
        "shared_exit_normal.png",
        (1410, 490),
        0.95,
    ),
)
PIXEL_MATCH_CROPS = (
    ("coin_value_entry", "01_shop_entry", (1373, 917, 1436, 945)),
    ("coin_panel_safe_hover", "01e_entry_coin_panel_hover", (1303, 885, 1468, 1009)),
    ("coin_panel_safe_click", "01e2_entry_coin_panel_click", (1303, 885, 1468, 1009)),
    ("coin_panel_safe_click_exit", "01e2_entry_coin_panel_click", (1410, 490, 1679, 962)),
    ("coin_exit_overlap_hover_panel", "01f_entry_coin_exit_overlap_hover", (1303, 885, 1510, 1009)),
    ("coin_exit_overlap_hover_exit", "01f_entry_coin_exit_overlap_hover", (1410, 490, 1679, 962)),
    ("coin_exit_overlap_click_panel", "01f2_entry_coin_exit_overlap_click", (1303, 885, 1510, 1009)),
    ("coin_exit_overlap_click_exit", "01f2_entry_coin_exit_overlap_click", (1410, 490, 1679, 962)),
    ("exit_transparent_gap_hover", "01g_entry_exit_transparent_gap_hover", (1410, 490, 1679, 962)),
    ("exit_transparent_gap_click", "01g2_entry_exit_transparent_gap_click", (1410, 490, 1679, 962)),
    ("coin_value_purchase", "05_purchase_complete", (1373, 917, 1436, 945)),
    ("price_entry_1", "01_shop_entry", (570, 532, 595, 553)),
    ("price_entry_2", "01_shop_entry", (895, 532, 920, 553)),
    ("price_entry_3", "01_shop_entry", (1218, 532, 1243, 553)),
    ("entry_empty_slot_4", "02c_entry_fourth_empty_slot_hover", (498, 610, 658, 800)),
    ("entry_empty_slot_4_click", "02c2_entry_fourth_empty_slot_click", (498, 610, 658, 800)),
    ("entry_empty_slot_5", "02d_entry_fifth_empty_slot_hover", (1148, 610, 1308, 800)),
    ("entry_empty_slot_5_click", "02d2_entry_fifth_empty_slot_click", (1148, 610, 1308, 800)),
    ("price_refresh_2", "04_refresh_complete", (895, 532, 920, 553)),
    ("price_refresh_3", "04_refresh_complete", (1218, 532, 1243, 553)),
    ("refresh_offer_1_hover_art_upper", "04a_refresh_first_offer_hover", (502, 364, 624, 394)),
    ("refresh_offer_1_hover_art_lower", "04a_refresh_first_offer_hover", (502, 394, 654, 516)),
    ("refresh_offer_1_hover_top", "04a_refresh_first_offer_hover", (498, 360, 658, 364)),
    ("refresh_offer_1_hover_left", "04a_refresh_first_offer_hover", (498, 360, 502, 550)),
    ("refresh_offer_1_hover_right", "04a_refresh_first_offer_hover", (654, 360, 658, 550)),
    ("refresh_offer_1_hover_bottom", "04a_refresh_first_offer_hover", (498, 546, 658, 550)),
    ("refresh_offer_2_hover_art_upper", "04b_refresh_second_offer_hover", (827, 364, 949, 394)),
    ("refresh_offer_2_hover_art_lower", "04b_refresh_second_offer_hover", (827, 394, 979, 516)),
    ("refresh_offer_2_hover_top", "04b_refresh_second_offer_hover", (823, 360, 983, 364)),
    ("refresh_offer_2_hover_left", "04b_refresh_second_offer_hover", (823, 360, 827, 550)),
    ("refresh_offer_2_hover_right", "04b_refresh_second_offer_hover", (979, 360, 983, 550)),
    ("refresh_offer_2_hover_bottom", "04b_refresh_second_offer_hover", (823, 546, 983, 550)),
    ("refresh_offer_3_hover_art_upper", "04c_refresh_third_offer_hover", (1152, 394, 1274, 409)),
    ("refresh_offer_3_hover_art_lower", "04c_refresh_third_offer_hover", (1152, 409, 1304, 546)),
    ("refresh_offer_3_hover_top", "04c_refresh_third_offer_hover", (1148, 375, 1308, 379)),
    ("refresh_offer_3_hover_left", "04c_refresh_third_offer_hover", (1148, 375, 1152, 565)),
    ("refresh_offer_3_hover_right", "04c_refresh_third_offer_hover", (1304, 375, 1308, 565)),
    ("refresh_offer_3_hover_bottom", "04c_refresh_third_offer_hover", (1148, 561, 1308, 565)),
    ("coin_value_paid_refresh", "12_paid_refresh_complete", (1373, 917, 1436, 945)),
    ("price_paid_refresh_1", "12_paid_refresh_complete", (570, 532, 595, 553)),
    ("price_paid_refresh_2", "12_paid_refresh_complete", (895, 532, 920, 553)),
    ("price_paid_refresh_3", "12_paid_refresh_complete", (1218, 532, 1243, 553)),
    (
        "paid_refresh_offer_3_hover_art",
        "12c_paid_refresh_third_offer_hover",
        (1152, 413, 1304, 527),
    ),
    ("paid_refresh_offer_1_hover_art_upper", "12a_paid_refresh_first_offer_hover", (502, 364, 624, 394)),
    ("paid_refresh_offer_1_hover_art_lower", "12a_paid_refresh_first_offer_hover", (502, 394, 654, 516)),
    ("paid_refresh_offer_1_hover_top", "12a_paid_refresh_first_offer_hover", (498, 360, 658, 364)),
    ("paid_refresh_offer_1_hover_left", "12a_paid_refresh_first_offer_hover", (498, 360, 502, 550)),
    ("paid_refresh_offer_1_hover_right", "12a_paid_refresh_first_offer_hover", (654, 360, 658, 550)),
    ("paid_refresh_offer_1_hover_bottom", "12a_paid_refresh_first_offer_hover", (498, 546, 658, 550)),
    ("paid_refresh_offer_2_hover_art_upper", "12b_paid_refresh_second_offer_hover", (827, 364, 949, 394)),
    ("paid_refresh_offer_2_hover_art_lower", "12b_paid_refresh_second_offer_hover", (827, 394, 979, 516)),
    ("paid_refresh_offer_2_hover_top", "12b_paid_refresh_second_offer_hover", (823, 360, 983, 364)),
    ("paid_refresh_offer_2_hover_left", "12b_paid_refresh_second_offer_hover", (823, 360, 827, 550)),
    ("paid_refresh_offer_2_hover_right", "12b_paid_refresh_second_offer_hover", (979, 360, 983, 550)),
    ("paid_refresh_offer_2_hover_bottom", "12b_paid_refresh_second_offer_hover", (823, 546, 983, 550)),
    ("sold_offer_1_empty", "05_purchase_complete", (498, 360, 658, 550)),
    ("sold_offer_2_empty", "09_second_purchase", (823, 360, 983, 550)),
    ("sold_offer_3_empty", "10_party_full_purchase", (1148, 375, 1308, 565)),
    ("sold_paid_offer_1_empty", "13_bag_pet_purchase", (498, 360, 658, 550)),
    ("hover_frame_top", "02_offer_hover", (498, 360, 658, 364)),
    ("hover_frame_left", "02_offer_hover", (498, 360, 502, 550)),
    ("hover_frame_right", "02_offer_hover", (654, 360, 658, 463)),
    ("hover_frame_bottom", "02_offer_hover", (498, 546, 658, 550)),
    ("pressed_offer_1_top", "02a_entry_first_offer_pressed", (498, 360, 658, 364)),
    ("pressed_offer_1_left", "02a_entry_first_offer_pressed", (498, 360, 502, 550)),
    ("pressed_offer_1_right", "02a_entry_first_offer_pressed", (654, 360, 658, 550)),
    ("pressed_offer_1_bottom", "02a_entry_first_offer_pressed", (498, 546, 658, 550)),
    ("pressed_offer_1_art_upper", "02a_entry_first_offer_pressed", (502, 364, 624, 394)),
    ("pressed_offer_1_art_lower", "02a_entry_first_offer_pressed", (502, 394, 654, 516)),
    ("entry_offer_2_hover_art_upper", "02_entry_second_offer_hover", (827, 364, 949, 394)),
    ("entry_offer_2_hover_art_lower", "02_entry_second_offer_hover", (827, 394, 979, 516)),
    ("entry_offer_2_hover_top", "02_entry_second_offer_hover", (823, 360, 983, 364)),
    ("entry_offer_2_hover_left", "02_entry_second_offer_hover", (823, 360, 827, 550)),
    ("entry_offer_2_hover_right", "02_entry_second_offer_hover", (979, 360, 983, 550)),
    ("entry_offer_2_hover_bottom", "02_entry_second_offer_hover", (823, 546, 983, 550)),
    ("pressed_offer_2_top", "02a2_entry_second_offer_pressed", (823, 360, 983, 364)),
    ("pressed_offer_2_left", "02a2_entry_second_offer_pressed", (823, 360, 827, 550)),
    ("pressed_offer_2_right", "02a2_entry_second_offer_pressed", (979, 360, 983, 550)),
    ("pressed_offer_2_bottom", "02a2_entry_second_offer_pressed", (823, 546, 983, 550)),
    ("pressed_offer_2_art_upper", "02a2_entry_second_offer_pressed", (827, 364, 949, 394)),
    ("pressed_offer_2_art_lower", "02a2_entry_second_offer_pressed", (827, 394, 979, 516)),
    ("entry_offer_3_hover_art_upper", "02_entry_third_offer_hover", (1152, 394, 1274, 409)),
    ("entry_offer_3_hover_art_lower", "02_entry_third_offer_hover", (1152, 409, 1304, 546)),
    ("entry_offer_3_hover_top", "02_entry_third_offer_hover", (1148, 375, 1308, 379)),
    ("entry_offer_3_hover_left", "02_entry_third_offer_hover", (1148, 375, 1152, 565)),
    ("entry_offer_3_hover_right", "02_entry_third_offer_hover", (1304, 375, 1308, 565)),
    ("entry_offer_3_hover_bottom", "02_entry_third_offer_hover", (1148, 561, 1308, 565)),
    ("pressed_offer_3_top", "02a3_entry_third_offer_pressed", (1148, 375, 1308, 379)),
    ("pressed_offer_3_left", "02a3_entry_third_offer_pressed", (1148, 375, 1152, 565)),
    ("pressed_offer_3_right", "02a3_entry_third_offer_pressed", (1304, 375, 1308, 565)),
    ("pressed_offer_3_bottom", "02a3_entry_third_offer_pressed", (1148, 561, 1308, 565)),
    ("pressed_offer_3_art_upper", "02a3_entry_third_offer_pressed", (1152, 394, 1274, 409)),
    ("pressed_offer_3_art_lower", "02a3_entry_third_offer_pressed", (1152, 409, 1304, 546)),
    ("refresh_bell_hover_right", "02b_refresh_hover", (1019, 712, 1034, 798)),
    ("refresh_bell_hover_bottom", "02b_refresh_hover", (945, 783, 1034, 798)),
    ("refresh_bell_pressed_upper", "02b2_refresh_pressed", (954, 712, 1034, 765)),
    ("paid_refresh_bell_hover_upper", "10d_paid_refresh_hover", (954, 712, 1034, 765)),
    ("paid_refresh_bell_pressed_upper", "10d2_paid_refresh_pressed", (954, 712, 1034, 765)),
    ("refresh_bell_process_right", "03_refresh_curtain", (1019, 712, 1034, 798)),
    ("refresh_bell_process_bottom", "03_refresh_curtain", (945, 783, 1034, 798)),
    ("exit_hover_full", "17_exit_hover", (1410, 490, 1679, 962)),
    ("exit_pressed_full", "17b_exit_pressed", (1410, 490, 1679, 962)),
    ("exit_pressed_pointer_outside_full", "17b2_exit_pressed_pointer_outside", (1410, 490, 1679, 962)),
    ("exit_pressed_pointer_reentered_full", "17b3_exit_pressed_pointer_reentered", (1410, 490, 1679, 962)),
    ("exit_pressed_pointer_outside_again_full", "17b4_exit_pressed_pointer_outside_again", (1410, 490, 1679, 962)),
    ("exit_press_cancelled_full", "17c_exit_press_cancelled", (1410, 490, 1679, 962)),
    ("exit_repressed_after_cancel_full", "17d_exit_repressed_after_cancel", (1410, 490, 1679, 962)),
    ("exit_repressed_pointer_outside_full", "17e_exit_repressed_pointer_outside", (1410, 490, 1679, 962)),
    ("exit_repressed_pointer_reentered_full", "17f_exit_repressed_pointer_reentered", (1410, 490, 1679, 962)),
    ("reentered_shop_offer_1_full", "19_reenter_shop_after_exit", (498, 360, 658, 550)),
    ("reentered_shop_offer_2_full", "19_reenter_shop_after_exit", (823, 360, 983, 550)),
    ("reentered_shop_offer_3_full", "19_reenter_shop_after_exit", (1148, 375, 1308, 565)),
    ("reentered_shop_bag_closed_full", "19_reenter_shop_after_exit", (313, 776, 549, 1009)),
    ("reentered_shop_coin_panel_full", "19_reenter_shop_after_exit", (1303, 885, 1468, 1009)),
    ("reentered_shop_exit_full", "19_reenter_shop_after_exit", (1410, 490, 1679, 962)),
    ("reentered_shop_offer_2_hover_art_upper", "19a_reentered_second_offer_hover", (827, 364, 949, 394)),
    ("reentered_shop_offer_2_hover_art_body", "19a_reentered_second_offer_hover", (827, 394, 979, 463)),
    ("reentered_shop_offer_2_hover_top", "19a_reentered_second_offer_hover", (823, 360, 983, 364)),
    ("reentered_shop_offer_2_hover_left", "19a_reentered_second_offer_hover", (823, 360, 827, 550)),
    ("reentered_shop_offer_2_hover_right_upper", "19a_reentered_second_offer_hover", (979, 360, 983, 463)),
    ("reentered_shop_offer_2_hover_bottom", "19a_reentered_second_offer_hover", (823, 546, 983, 550)),
    ("reentered_shop_offer_2_pressed_top", "19b_reentered_second_offer_pressed", (823, 360, 983, 364)),
    ("reentered_shop_offer_2_pressed_left", "19b_reentered_second_offer_pressed", (823, 360, 827, 550)),
    ("reentered_shop_offer_2_pressed_right", "19b_reentered_second_offer_pressed", (979, 360, 983, 550)),
    ("reentered_shop_offer_2_pressed_bottom", "19b_reentered_second_offer_pressed", (823, 546, 983, 550)),
    ("reentered_shop_offer_2_pressed_art_upper", "19b_reentered_second_offer_pressed", (827, 364, 949, 394)),
    ("reentered_shop_offer_2_pressed_art_lower", "19b_reentered_second_offer_pressed", (827, 394, 979, 516)),
    ("reentered_shop_offer_2_cancelled_full", "19c_reentered_second_offer_press_cancelled", (823, 360, 983, 550)),
    ("reentered_shop_offer_2_rehover_art_upper", "19d_reentered_second_offer_rehover_after_cancel", (827, 364, 949, 394)),
    ("reentered_shop_offer_2_rehover_art_body", "19d_reentered_second_offer_rehover_after_cancel", (827, 394, 979, 463)),
    ("reentered_shop_offer_2_rehover_top", "19d_reentered_second_offer_rehover_after_cancel", (823, 360, 983, 364)),
    ("reentered_shop_offer_2_rehover_left", "19d_reentered_second_offer_rehover_after_cancel", (823, 360, 827, 550)),
    ("reentered_shop_offer_2_rehover_right_upper", "19d_reentered_second_offer_rehover_after_cancel", (979, 360, 983, 463)),
    ("reentered_shop_offer_2_rehover_bottom_left", "19d_reentered_second_offer_rehover_after_cancel", (823, 546, 970, 550)),
    ("reentered_shop_offer_2_repressed_top", "19e_reentered_second_offer_repressed_after_cancel", (823, 360, 983, 364)),
    ("reentered_shop_offer_2_repressed_left", "19e_reentered_second_offer_repressed_after_cancel", (823, 360, 827, 550)),
    ("reentered_shop_offer_2_repressed_right", "19e_reentered_second_offer_repressed_after_cancel", (979, 360, 983, 550)),
    ("reentered_shop_offer_2_repressed_bottom", "19e_reentered_second_offer_repressed_after_cancel", (823, 546, 983, 550)),
    ("reentered_shop_offer_2_repressed_art_upper", "19e_reentered_second_offer_repressed_after_cancel", (827, 364, 949, 394)),
    ("reentered_shop_offer_2_repressed_art_lower", "19e_reentered_second_offer_repressed_after_cancel", (827, 394, 979, 516)),
    ("reentered_shop_offer_2_repressed_full", "19e_reentered_second_offer_repressed_after_cancel", (823, 360, 983, 550)),
    ("reentered_shop_offer_2_repressed_outside_full", "19f_reentered_second_offer_repressed_pointer_outside", (823, 360, 983, 550)),
    ("reentered_shop_offer_2_repressed_reentered_full", "19g_reentered_second_offer_repressed_pointer_reentered", (823, 360, 983, 550)),
    ("reentered_shop_offer_2_repressed_outside_again_full", "19h_reentered_second_offer_repressed_pointer_outside_again", (823, 360, 983, 550)),
    ("reentered_shop_offer_2_repress_cancelled_after_reentry_cycle_full", "19i_reentered_second_offer_repress_cancelled_after_reentry_cycle", (823, 360, 983, 550)),
    ("reentered_shop_offer_2_rehover_after_repress_cycle_art_upper", "19j_reentered_second_offer_rehover_after_repress_cycle_cancel", (827, 364, 949, 394)),
    ("reentered_shop_offer_2_rehover_after_repress_cycle_art_body", "19j_reentered_second_offer_rehover_after_repress_cycle_cancel", (827, 394, 979, 463)),
    ("reentered_shop_offer_2_rehover_after_repress_cycle_top", "19j_reentered_second_offer_rehover_after_repress_cycle_cancel", (823, 360, 983, 364)),
    ("reentered_shop_offer_2_rehover_after_repress_cycle_left", "19j_reentered_second_offer_rehover_after_repress_cycle_cancel", (823, 360, 827, 550)),
    ("reentered_shop_offer_2_rehover_after_repress_cycle_right_upper", "19j_reentered_second_offer_rehover_after_repress_cycle_cancel", (979, 360, 983, 463)),
    ("reentered_shop_offer_2_rehover_after_repress_cycle_bottom_left", "19j_reentered_second_offer_rehover_after_repress_cycle_cancel", (823, 546, 970, 550)),
    ("bag_open_full", "07_bag_open", (313, 776, 549, 1009)),
    ("bag_inventory_inner", "07_bag_open", (510, 387, 1312, 810)),
    ("bag_open_hover_cleared_full", "07a_bag_open_hover_cleared", (313, 776, 549, 1009)),
    ("bag_open_hover_cleared_inventory", "07a_bag_open_hover_cleared", (502, 379, 1320, 818)),
    ("bag_open_rehover_full", "07a2_bag_open_hover", (313, 776, 549, 1009)),
    ("bag_open_rehover_inventory", "07a2_bag_open_hover", (502, 379, 1320, 818)),
    ("bag_open_pressed_full", "07a3_bag_open_pressed", (313, 776, 549, 1009)),
    ("bag_open_pressed_inventory", "07a3_bag_open_pressed", (502, 379, 1320, 818)),
    ("empty_bag_slot_hover", "07b_empty_bag_slot_hover", (541, 409, 724, 586)),
    ("empty_bag_slot_click_full_bag", "07c_empty_bag_slot_click", (502, 379, 1320, 818)),
    ("empty_bag_eighth_slot_hover", "07d_empty_bag_eighth_slot_hover", (1096, 587, 1279, 764)),
    ("bag_closed_after_toggle", "08_bag_closed", (313, 776, 549, 1009)),
    ("bag_pet_first_slot", "14_bag_with_pet_open", (541, 409, 724, 586)),
    ("bag_pet_hover_highlight", "15_bag_pet_hover", (541, 409, 724, 586)),
    ("mixed_bag_eighth_slot_hover", "15b_bag_pet_eighth_empty_slot_hover", (502, 379, 1320, 818)),
    ("mixed_bag_hover_cleared", "15c_bag_hover_cleared", (502, 379, 1320, 818)),
    ("occupied_bag_slot_click_full_bag", "15d_bag_pet_click", (502, 379, 1320, 818)),
    ("party_first_click_pet_and_slot", "06a_party_first_click", (552, 790, 730, 903)),
    ("party_second_click_pet_and_slot", "06c_party_second_click", (738, 790, 901, 903)),
    ("bag_closed_hover_full", "06d_bag_closed_hover", (313, 776, 549, 1009)),
    ("bag_closed_pressed_full", "06d2_bag_closed_pressed", (313, 776, 549, 1009)),
    ("party_third_click_pet_and_slot", "10b2_party_third_click", (914, 790, 1077, 903)),
    ("party_fourth_click_pet_slot_and_right_edge", "10c2_party_fourth_click", (1094, 790, 1280, 903)),
    ("entry_second_empty_party_slot", "01b_entry_second_empty_party_slot_hover", (738, 790, 901, 903)),
    ("entry_second_empty_party_slot_click", "01b2_entry_second_empty_party_slot_click", (738, 790, 901, 922)),
    ("entry_fourth_empty_party_slot_and_right_edge", "01c_entry_fourth_empty_party_slot_hover", (1094, 790, 1280, 922)),
    ("entry_fourth_empty_party_slot_click_and_right_edge", "01c2_entry_fourth_empty_party_slot_click", (1094, 790, 1280, 922)),
    ("entry_third_empty_party_slot", "01d_entry_third_empty_party_slot_hover", (914, 790, 1077, 922)),
    ("entry_third_empty_party_slot_click", "01d2_entry_third_empty_party_slot_click", (914, 790, 1077, 922)),
    ("bag_overlay_bottom_empty", "07_bag_open", (0, 1060, 1920, 1080)),
    ("bag_overlay_bottom_pet", "14_bag_with_pet_open", (0, 1060, 1920, 1080)),
    ("bag_overlay_bottom_pet_hover", "15_bag_pet_hover", (0, 1060, 1920, 1080)),
)
TOLERANCE_MATCH_CROPS = (
    (
        "merchant_alpha_composite",
        "01_shop_entry",
        (813, 580, 990, 782),
        6000,
        0.55,
    ),
)
EFFECT_MATCH_CROPS = (
    (
        "party_shadow_treatment",
        "01_shop_entry",
        "05_purchase_complete",
        (781, 903, 860, 922),
        30,
        900,
        0.25,
        "darken",
    ),
    (
        "party_shadow_hover",
        "05_purchase_complete",
        "06_party_hover",
        (603, 903, 682, 922),
        100,
        1300,
        1.1,
        "brighten",
    ),
    (
        "party_shadow_first_click",
        "05_purchase_complete",
        "06a_party_first_click",
        (603, 903, 682, 922),
        100,
        1400,
        1.1,
        "brighten",
    ),
    (
        "party_shadow_second_hover",
        "05_purchase_complete",
        "06b_party_second_hover",
        (781, 903, 860, 922),
        100,
        1300,
        1.1,
        "brighten",
    ),
    (
        "party_shadow_second_click",
        "05_purchase_complete",
        "06c_party_second_click",
        (781, 903, 860, 922),
        100,
        1400,
        1.1,
        "brighten",
    ),
    (
        "party_shadow_third_hover",
        "10_party_full_purchase",
        "10b_party_third_hover",
        (957, 903, 1036, 922),
        100,
        1300,
        1.1,
        "brighten",
    ),
    (
        "party_shadow_third_click",
        "10_party_full_purchase",
        "10b2_party_third_click",
        (957, 903, 1036, 922),
        100,
        1400,
        1.1,
        "brighten",
    ),
    (
        "party_shadow_fourth_hover",
        "10_party_full_purchase",
        "10c_party_fourth_hover",
        (1137, 903, 1216, 922),
        100,
        1300,
        1.1,
        "brighten",
    ),
    (
        "party_shadow_fourth_click",
        "10_party_full_purchase",
        "10c2_party_fourth_click",
        (1137, 903, 1216, 922),
        100,
        1400,
        1.1,
        "brighten",
    ),
)


def _opaque_mask(template: Image.Image, alpha_threshold: int = 250) -> Image.Image:
    alpha = template.convert("RGBA").getchannel("A")
    maximum_alpha = alpha.getextrema()[1]
    effective_threshold = (
        alpha_threshold
        if maximum_alpha >= alpha_threshold
        else max(1, round(maximum_alpha * 0.75))
    )
    mask = alpha.point(lambda value: 255 if value >= effective_threshold else 0)
    if mask.getbbox() is None:
        raise ValueError("template has no sufficiently opaque pixels")
    return mask


def _positions(expected: tuple[int, int], radius: int) -> Iterable[tuple[int, int]]:
    expected_x, expected_y = expected
    for y in range(expected_y - radius, expected_y + radius + 1):
        for x in range(expected_x - radius, expected_x + radius + 1):
            yield x, y


def locate_template(
    screenshot: Image.Image,
    template: Image.Image,
    expected: tuple[int, int],
    radius: int,
) -> dict:
    screen = screenshot.convert("RGB")
    source = template.convert("RGBA")
    source_rgb = source.convert("RGB")
    mask = _opaque_mask(source)
    width, height = source.size
    candidates = []
    for x, y in _positions(expected, radius):
        if x < 0 or y < 0 or x + width > screen.width or y + height > screen.height:
            continue
        crop = screen.crop((x, y, x + width, y + height))
        difference = ImageChops.difference(crop, source_rgb)
        mean = ImageStat.Stat(difference, mask).mean
        score = sum(mean) / len(mean)
        distance = abs(x - expected[0]) + abs(y - expected[1])
        candidates.append((score, distance, x, y))
    if not candidates:
        raise ValueError("template search area is outside the screenshot")
    candidates.sort()
    score, _distance, x, y = candidates[0]
    second_score = candidates[1][0] if len(candidates) > 1 else score
    return {
        "position": [x, y],
        "expected": list(expected),
        "offset": [x - expected[0], y - expected[1]],
        "mean_opaque_rgb_error": round(score, 6),
        "next_candidate_margin": round(second_score - score, 6),
        "search_radius": radius,
    }


def overlap_layer_stats(
    screenshot: Image.Image,
    top_template: Image.Image,
    top_position: tuple[int, int],
    bottom_template: Image.Image,
    bottom_position: tuple[int, int],
    alpha_threshold: int = 250,
) -> dict:
    screen = screenshot.convert("RGB")
    top = top_template.convert("RGBA")
    bottom = bottom_template.convert("RGBA")
    left = max(top_position[0], bottom_position[0])
    top_y = max(top_position[1], bottom_position[1])
    right = min(top_position[0] + top.width, bottom_position[0] + bottom.width)
    bottom_y = min(top_position[1] + top.height, bottom_position[1] + bottom.height)
    both_opaque = 0
    top_closer = 0
    bottom_closer = 0
    ties = 0
    for y in range(top_y, bottom_y):
        for x in range(left, right):
            top_pixel = top.getpixel((x - top_position[0], y - top_position[1]))
            bottom_pixel = bottom.getpixel((x - bottom_position[0], y - bottom_position[1]))
            if top_pixel[3] < alpha_threshold or bottom_pixel[3] < alpha_threshold:
                continue
            both_opaque += 1
            screen_pixel = screen.getpixel((x, y))
            top_distance = sum(abs(screen_pixel[index] - top_pixel[index]) for index in range(3))
            bottom_distance = sum(abs(screen_pixel[index] - bottom_pixel[index]) for index in range(3))
            if top_distance < bottom_distance:
                top_closer += 1
            elif bottom_distance < top_distance:
                bottom_closer += 1
            else:
                ties += 1
    if both_opaque == 0:
        raise ValueError("overlap check has no jointly opaque pixels")
    return {
        "jointly_opaque_pixels": both_opaque,
        "top_closer_pixels": top_closer,
        "bottom_closer_pixels": bottom_closer,
        "tie_pixels": ties,
        "top_closer_ratio": round(top_closer / both_opaque, 6),
    }


def pixel_crop_stats(left: Image.Image, right: Image.Image, box: tuple[int, int, int, int]) -> dict:
    left_crop = left.convert("RGB").crop(box)
    right_crop = right.convert("RGB").crop(box)
    difference = ImageChops.difference(left_crop, right_crop)
    differing_pixels = sum(pixel != (0, 0, 0) for pixel in difference.getdata())
    bbox = difference.getbbox()
    return {
        "box": list(box),
        "differing_pixels": differing_pixels,
        "difference_bbox": list(bbox) if bbox is not None else None,
        "passed": differing_pixels == 0,
    }


def tolerance_crop_stats(
    left: Image.Image,
    right: Image.Image,
    box: tuple[int, int, int, int],
    maximum_differing_pixels: int,
    maximum_mean_absolute_rgb_error: float,
) -> dict:
    left_crop = left.convert("RGB").crop(box)
    right_crop = right.convert("RGB").crop(box)
    difference = ImageChops.difference(left_crop, right_crop)
    differing_pixels = sum(pixel != (0, 0, 0) for pixel in difference.getdata())
    mean_absolute_rgb_error = sum(ImageStat.Stat(difference).mean) / 3.0
    bbox = difference.getbbox()
    return {
        "box": list(box),
        "differing_pixels": differing_pixels,
        "difference_bbox": list(bbox) if bbox is not None else None,
        "mean_absolute_rgb_error": round(mean_absolute_rgb_error, 6),
        "maximum_differing_pixels": maximum_differing_pixels,
        "maximum_mean_absolute_rgb_error": maximum_mean_absolute_rgb_error,
        "passed": (
            differing_pixels <= maximum_differing_pixels
            and mean_absolute_rgb_error <= maximum_mean_absolute_rgb_error
        ),
    }


def effect_crop_stats(
    left_baseline: Image.Image,
    left_effect: Image.Image,
    right_baseline: Image.Image,
    right_effect: Image.Image,
    box: tuple[int, int, int, int],
    maximum_channel_change: int,
    direction: str = "darken",
) -> dict:
    images = [
        image.convert("RGB").crop(box)
        for image in (left_baseline, left_effect, right_baseline, right_effect)
    ]
    eligible_pixels = 0
    differing_channels = 0
    absolute_error = 0
    for left_base, left_result, right_base, right_result in zip(
        *(image.getdata() for image in images)
    ):
        left_delta = tuple(left_result[index] - left_base[index] for index in range(3))
        right_delta = tuple(right_result[index] - right_base[index] for index in range(3))
        outside_change_limit = (
            max(abs(value) for value in left_delta) > maximum_channel_change
            or max(abs(value) for value in right_delta) > maximum_channel_change
        )
        wrong_direction = (
            (direction == "darken" and (max(left_delta) > 0 or max(right_delta) > 0))
            or (direction == "brighten" and (min(left_delta) < 0 or min(right_delta) < 0))
        )
        if outside_change_limit or wrong_direction:
            continue
        eligible_pixels += 1
        for index in range(3):
            channel_error = abs(left_delta[index] - right_delta[index])
            absolute_error += channel_error
            if channel_error != 0:
                differing_channels += 1
    mean_absolute_effect_error = (
        absolute_error / (eligible_pixels * 3)
        if eligible_pixels > 0
        else float("inf")
    )
    return {
        "box": list(box),
        "maximum_channel_change": maximum_channel_change,
        "direction": direction,
        "eligible_pixels": eligible_pixels,
        "differing_channels": differing_channels,
        "mean_absolute_effect_error": round(mean_absolute_effect_error, 6),
    }


def audit_geometry(
    art_dir: Path,
    formal_dir: Path,
    asset_root: Path,
    diagnostic_full: bool = False,
) -> dict:
    selected_names = None if diagnostic_full else ACCEPTANCE_OPERATION_NAMES
    acceptance_assets = tuple(
        item for item in ASSETS if selected_names is None or item[1] in selected_names
    )
    acceptance_pixel_crops = tuple(
        item for item in PIXEL_MATCH_CROPS if selected_names is None or item[1] in selected_names
    )
    acceptance_tolerance_crops = tuple(
        item for item in TOLERANCE_MATCH_CROPS if selected_names is None or item[1] in selected_names
    )
    acceptance_effect_crops = tuple(
        item
        for item in EFFECT_MATCH_CROPS
        if selected_names is None or (item[1] in selected_names and item[2] in selected_names)
    )
    records = []
    overlap_checks = []
    pixel_checks = []
    tolerance_checks = []
    effect_checks = []
    errors = []
    image_cache: dict[Path, Image.Image] = {}

    def load(path: Path) -> Image.Image:
        if path not in image_cache:
            image_cache[path] = Image.open(path).convert("RGBA")
        return image_cache[path]

    try:
        for name, capture, filename, expected, radius, target_size in acceptance_assets:
            template_path = (asset_root / filename).resolve()
            art_path = art_dir / f"{capture}.png"
            formal_path = formal_dir / f"{capture}.png"
            missing = [str(path) for path in (template_path, art_path, formal_path) if not path.is_file()]
            if missing:
                errors.append(f"{name}: missing file(s): {', '.join(missing)}")
                continue
            art_image = load(art_path)
            formal_image = load(formal_path)
            if art_image.size != REFERENCE_SIZE or formal_image.size != REFERENCE_SIZE:
                errors.append(
                    f"{name}: screenshots must be {REFERENCE_SIZE}, got {art_image.size}/{formal_image.size}"
                )
                continue
            template = load(template_path)
            if target_size is not None:
                template = template.resize(target_size, Image.Resampling.NEAREST)
            art_result = locate_template(art_image, template, expected, radius)
            formal_result = locate_template(formal_image, template, expected, radius)
            art_position = art_result["position"]
            formal_position = formal_result["position"]
            delta = [formal_position[0] - art_position[0], formal_position[1] - art_position[1]]
            maximum_mean_error = ASSET_MAX_MEAN_OPAQUE_RGB_ERROR.get(name)
            pixel_fidelity_passed = (
                maximum_mean_error is None
                or (
                    art_result["mean_opaque_rgb_error"] <= maximum_mean_error
                    and formal_result["mean_opaque_rgb_error"] <= maximum_mean_error
                )
            )
            passed = (
                art_result["offset"] == [0, 0]
                and formal_result["offset"] == [0, 0]
                and pixel_fidelity_passed
            )
            if not passed:
                errors.append(
                    f"{name}: art/formal positions {art_position}/{formal_position}, "
                    f"mean errors {art_result['mean_opaque_rgb_error']}/"
                    f"{formal_result['mean_opaque_rgb_error']}, expected {list(expected)}"
                )
            records.append(
                {
                    "name": name,
                    "capture": capture,
                    "template": str(template_path.resolve()),
                    "art": art_result,
                    "formal": formal_result,
                    "formal_minus_art": delta,
                    "maximum_mean_opaque_rgb_error": maximum_mean_error,
                    "passed": passed,
                }
            )
        art_entry_path = art_dir / "01_shop_entry.png"
        formal_entry_path = formal_dir / "01_shop_entry.png"
        for name, top_file, top_position, bottom_file, bottom_position, minimum in OVERLAPS:
            top_path = (asset_root / top_file).resolve()
            bottom_path = (asset_root / bottom_file).resolve()
            overlap_paths = (top_path, bottom_path, art_entry_path, formal_entry_path)
            overlap_missing = [str(path) for path in overlap_paths if not path.is_file()]
            if overlap_missing:
                errors.append(f"{name}: missing file(s): " + ", ".join(overlap_missing))
                continue
            top_template = load(top_path)
            bottom_template = load(bottom_path)
            art_overlap = overlap_layer_stats(
                load(art_entry_path),
                top_template,
                top_position,
                bottom_template,
                bottom_position,
            )
            formal_overlap = overlap_layer_stats(
                load(formal_entry_path),
                top_template,
                top_position,
                bottom_template,
                bottom_position,
            )
            overlap_passed = (
                art_overlap["top_closer_ratio"] >= minimum
                and formal_overlap["top_closer_ratio"] >= minimum
            )
            if not overlap_passed:
                errors.append(
                    f"{name}: top ratios art/formal "
                    f"{art_overlap['top_closer_ratio']}/{formal_overlap['top_closer_ratio']}"
                )
            overlap_checks.append(
                {
                    "name": name,
                    "top": top_file,
                    "bottom": bottom_file,
                    "minimum_top_closer_ratio": minimum,
                    "art": art_overlap,
                    "formal": formal_overlap,
                    "passed": overlap_passed,
                }
            )
        for name, capture, box in acceptance_pixel_crops:
            art_path = art_dir / f"{capture}.png"
            formal_path = formal_dir / f"{capture}.png"
            missing = [str(path) for path in (art_path, formal_path) if not path.is_file()]
            if missing:
                errors.append(f"{name}: missing file(s): " + ", ".join(missing))
                continue
            result = pixel_crop_stats(load(art_path), load(formal_path), box)
            if not result["passed"]:
                errors.append(f"{name}: differing pixels {result['differing_pixels']}")
            pixel_checks.append({"name": name, "capture": capture, **result})
        for (
            name,
            capture,
            box,
            maximum_differing_pixels,
            maximum_mean_absolute_rgb_error,
        ) in acceptance_tolerance_crops:
            art_path = art_dir / f"{capture}.png"
            formal_path = formal_dir / f"{capture}.png"
            missing = [str(path) for path in (art_path, formal_path) if not path.is_file()]
            if missing:
                errors.append(f"{name}: missing file(s): " + ", ".join(missing))
                continue
            result = tolerance_crop_stats(
                load(art_path),
                load(formal_path),
                box,
                maximum_differing_pixels,
                maximum_mean_absolute_rgb_error,
            )
            if not result["passed"]:
                errors.append(
                    f"{name}: differing pixels {result['differing_pixels']}, "
                    f"mean RGB error {result['mean_absolute_rgb_error']}"
                )
            tolerance_checks.append({"name": name, "capture": capture, **result})
        for (
            name,
            baseline_capture,
            effect_capture,
            box,
            maximum_channel_change,
            minimum_eligible_pixels,
            maximum_mean_error,
            direction,
        ) in acceptance_effect_crops:
            paths = (
                art_dir / f"{baseline_capture}.png",
                art_dir / f"{effect_capture}.png",
                formal_dir / f"{baseline_capture}.png",
                formal_dir / f"{effect_capture}.png",
            )
            missing = [str(path) for path in paths if not path.is_file()]
            if missing:
                errors.append(f"{name}: missing file(s): " + ", ".join(missing))
                continue
            result = effect_crop_stats(
                *(load(path) for path in paths),
                box,
                maximum_channel_change,
                direction,
            )
            effect_passed = (
                result["eligible_pixels"] >= minimum_eligible_pixels
                and result["mean_absolute_effect_error"] <= maximum_mean_error
            )
            if not effect_passed:
                errors.append(
                    f"{name}: eligible pixels {result['eligible_pixels']}, "
                    f"mean effect error {result['mean_absolute_effect_error']}"
                )
            effect_checks.append({
                "name": name,
                "baseline_capture": baseline_capture,
                "effect_capture": effect_capture,
                "minimum_eligible_pixels": minimum_eligible_pixels,
                "maximum_mean_absolute_effect_error": maximum_mean_error,
                **result,
                "passed": effect_passed,
            })
    finally:
        for image in image_cache.values():
            image.close()
    passed = (
        not errors
        and len(records) == len(acceptance_assets)
        and all(record["passed"] for record in records)
        and len(overlap_checks) == len(OVERLAPS)
        and all(check["passed"] for check in overlap_checks)
        and len(pixel_checks) == len(acceptance_pixel_crops)
        and all(check["passed"] for check in pixel_checks)
        and len(tolerance_checks) == len(acceptance_tolerance_crops)
        and all(check["passed"] for check in tolerance_checks)
        and len(effect_checks) == len(acceptance_effect_crops)
        and all(check["passed"] for check in effect_checks)
    )
    return {
        "schema": "ysbzs.shop-art-geometry-audit.v1",
        "profile": "diagnostic_full" if diagnostic_full else "fixed_seed_acceptance_14",
        "passed": passed,
        "reference_size": list(REFERENCE_SIZE),
        "asset_count": len(records),
        "overlap_check_count": len(overlap_checks),
        "pixel_check_count": len(pixel_checks),
        "tolerance_check_count": len(tolerance_checks),
        "effect_check_count": len(effect_checks),
        "errors": errors,
        "assets": records,
        "overlap_checks": overlap_checks,
        "pixel_checks": pixel_checks,
        "tolerance_checks": tolerance_checks,
        "effect_checks": effect_checks,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--art-dir", type=Path, required=True)
    parser.add_argument("--formal-dir", type=Path, required=True)
    parser.add_argument(
        "--asset-root",
        type=Path,
        default=Path(__file__).resolve().parents[2] / "art/images/shop/screen_shop_godot_v1",
    )
    parser.add_argument("--report", type=Path)
    parser.add_argument(
        "--diagnostic-full",
        action="store_true",
        help="audit the historical exhaustive micro-interaction matrix instead of the 14-image acceptance set",
    )
    args = parser.parse_args()
    result = audit_geometry(
        args.art_dir,
        args.formal_dir,
        args.asset_root,
        diagnostic_full=args.diagnostic_full,
    )
    output = json.dumps(result, ensure_ascii=False, indent=2)
    print(output)
    if args.report is not None:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(output + "\n", encoding="utf-8")
    if result["passed"]:
        print(f"SHOP_ART_GEOMETRY_OK assets={result['asset_count']}")
        return 0
    print(f"SHOP_ART_GEOMETRY_FAIL errors={len(result['errors'])}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
