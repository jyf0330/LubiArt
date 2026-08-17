#!/usr/bin/env python3
"""Regression tests for synchronized shop asset location checks."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest

from PIL import Image, ImageDraw


MODULE_PATH = Path(__file__).with_name("check_shop_art_geometry.py")
SPEC = importlib.util.spec_from_file_location("check_shop_art_geometry", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class ShopArtGeometryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.template = Image.new("RGBA", (12, 10), (0, 0, 0, 0))
        draw = ImageDraw.Draw(self.template)
        draw.rectangle((2, 1, 9, 8), fill=(44, 178, 213, 255))
        draw.rectangle((4, 3, 7, 6), fill=(241, 191, 52, 255))
        self.expected = (20, 15)

    def _screen(self, position: tuple[int, int]) -> Image.Image:
        screen = Image.new("RGBA", (64, 48), (13, 18, 22, 255))
        screen.alpha_composite(self.template, position)
        return screen

    def test_locates_asset_at_expected_position(self) -> None:
        result = MODULE.locate_template(self._screen(self.expected), self.template, self.expected, 4)
        self.assertEqual(result["position"], list(self.expected))
        self.assertEqual(result["offset"], [0, 0])
        self.assertEqual(result["mean_opaque_rgb_error"], 0.0)

    def test_reports_displaced_asset(self) -> None:
        displaced = (23, 13)
        result = MODULE.locate_template(self._screen(displaced), self.template, self.expected, 4)
        self.assertEqual(result["position"], list(displaced))
        self.assertEqual(result["offset"], [3, -2])

    def test_ignores_overdraw_on_transparent_border(self) -> None:
        screen = self._screen(self.expected)
        ImageDraw.Draw(screen).rectangle((20, 15, 21, 16), fill=(255, 0, 255, 255))
        result = MODULE.locate_template(screen, self.template, self.expected, 4)
        self.assertEqual(result["position"], list(self.expected))

    def test_overlap_layer_stats_identifies_top_asset(self) -> None:
        screen = Image.new("RGBA", (24, 20), (11, 12, 13, 255))
        bottom = Image.new("RGBA", (12, 12), (180, 40, 30, 255))
        top = Image.new("RGBA", (12, 12), (30, 160, 210, 255))
        screen.alpha_composite(bottom, (8, 4))
        screen.alpha_composite(top, (4, 6))
        result = MODULE.overlap_layer_stats(screen, top, (4, 6), bottom, (8, 4))
        self.assertEqual(result["top_closer_ratio"], 1.0)
        self.assertGreater(result["jointly_opaque_pixels"], 0)

    def test_pixel_crop_stats_requires_exact_match(self) -> None:
        left = Image.new("RGB", (12, 12), (20, 30, 40))
        right = left.copy()
        self.assertTrue(MODULE.pixel_crop_stats(left, right, (2, 2, 10, 10))["passed"])
        right.putpixel((5, 6), (21, 30, 40))
        mismatch = MODULE.pixel_crop_stats(left, right, (2, 2, 10, 10))
        self.assertFalse(mismatch["passed"])
        self.assertEqual(mismatch["differing_pixels"], 1)

    def test_tolerance_crop_stats_bounds_composite_noise(self) -> None:
        left = Image.new("RGB", (4, 4), (20, 30, 40))
        right = left.copy()
        right.putpixel((1, 2), (22, 31, 40))
        accepted = MODULE.tolerance_crop_stats(left, right, (0, 0, 4, 4), 1, 0.07)
        self.assertTrue(accepted["passed"])
        self.assertEqual(accepted["differing_pixels"], 1)

        rejected = MODULE.tolerance_crop_stats(left, right, (0, 0, 4, 4), 0, 0.01)
        self.assertFalse(rejected["passed"])
        self.assertGreater(rejected["mean_absolute_rgb_error"], 0.01)

    def test_effect_crop_stats_compares_each_side_against_its_baseline(self) -> None:
        left_baseline = Image.new("RGB", (4, 4), (80, 90, 100))
        right_baseline = Image.new("RGB", (4, 4), (82, 91, 103))
        left_effect = Image.new("RGB", (4, 4), (73, 78, 89))
        right_effect = Image.new("RGB", (4, 4), (75, 79, 92))
        result = MODULE.effect_crop_stats(
            left_baseline,
            left_effect,
            right_baseline,
            right_effect,
            (0, 0, 4, 4),
            30,
        )
        self.assertEqual(result["eligible_pixels"], 16)
        self.assertEqual(result["differing_channels"], 0)
        self.assertEqual(result["mean_absolute_effect_error"], 0.0)

        right_effect.putpixel((2, 1), (76, 79, 92))
        mismatch = MODULE.effect_crop_stats(
            left_baseline,
            left_effect,
            right_baseline,
            right_effect,
            (0, 0, 4, 4),
            30,
        )
        self.assertEqual(mismatch["differing_channels"], 1)
        self.assertGreater(mismatch["mean_absolute_effect_error"], 0.0)

    def test_effect_crop_stats_accepts_matching_brightening(self) -> None:
        left_baseline = Image.new("RGB", (4, 4), (30, 40, 50))
        right_baseline = Image.new("RGB", (4, 4), (32, 43, 54))
        left_effect = Image.new("RGB", (4, 4), (60, 75, 90))
        right_effect = Image.new("RGB", (4, 4), (62, 78, 94))
        result = MODULE.effect_crop_stats(
            left_baseline,
            left_effect,
            right_baseline,
            right_effect,
            (0, 0, 4, 4),
            50,
            "brighten",
        )
        self.assertEqual(result["direction"], "brighten")
        self.assertEqual(result["eligible_pixels"], 16)
        self.assertEqual(result["mean_absolute_effect_error"], 0.0)

    def test_party_hover_effects_allow_antialiased_edge_sampling(self) -> None:
        thresholds = {
            name: minimum_eligible_pixels
            for (
                name,
                _baseline_capture,
                _effect_capture,
                _box,
                _maximum_channel_change,
                minimum_eligible_pixels,
                _maximum_mean_absolute_effect_error,
                _direction,
            ) in MODULE.EFFECT_MATCH_CROPS
        }
        self.assertEqual(thresholds["party_shadow_hover"], 1300)
        self.assertEqual(thresholds["party_shadow_second_hover"], 1300)
        self.assertEqual(thresholds["party_shadow_third_hover"], 1300)
        self.assertEqual(thresholds["party_shadow_fourth_hover"], 1300)
        self.assertEqual(thresholds["party_shadow_first_click"], 1400)
        self.assertEqual(thresholds["party_shadow_second_click"], 1400)
        self.assertEqual(thresholds["party_shadow_third_click"], 1400)
        self.assertEqual(thresholds["party_shadow_fourth_click"], 1400)

    def test_offer_hover_art_crops_exclude_formal_freeze_button(self) -> None:
        crops = {name: box for name, _capture, box in MODULE.PIXEL_MATCH_CROPS}
        self.assertEqual(crops["entry_offer_2_hover_art_upper"], (827, 364, 949, 394))
        self.assertEqual(crops["entry_offer_2_hover_art_lower"], (827, 394, 979, 516))
        self.assertEqual(crops["entry_offer_3_hover_art_upper"], (1152, 394, 1274, 409))
        self.assertEqual(crops["entry_offer_3_hover_art_lower"], (1152, 409, 1304, 546))
        self.assertEqual(crops["paid_refresh_offer_1_hover_art_upper"], (502, 364, 624, 394))
        self.assertEqual(crops["paid_refresh_offer_1_hover_art_lower"], (502, 394, 654, 516))
        self.assertEqual(crops["paid_refresh_offer_2_hover_art_upper"], (827, 364, 949, 394))
        self.assertEqual(crops["paid_refresh_offer_2_hover_art_lower"], (827, 394, 979, 516))
        self.assertEqual(crops["refresh_offer_1_hover_art_upper"], (502, 364, 624, 394))
        self.assertEqual(crops["refresh_offer_1_hover_art_lower"], (502, 394, 654, 516))
        self.assertEqual(crops["refresh_offer_2_hover_art_upper"], (827, 364, 949, 394))
        self.assertEqual(crops["refresh_offer_2_hover_art_lower"], (827, 394, 979, 516))
        self.assertEqual(crops["refresh_offer_3_hover_art_upper"], (1152, 394, 1274, 409))
        self.assertEqual(crops["refresh_offer_3_hover_art_lower"], (1152, 409, 1304, 546))

    def test_entry_first_offer_pressed_checks_complete_frame(self) -> None:
        crops = {
            name: (capture, box)
            for name, capture, box in MODULE.PIXEL_MATCH_CROPS
        }
        self.assertEqual(crops["pressed_offer_1_top"], ("02a_entry_first_offer_pressed", (498, 360, 658, 364)))
        self.assertEqual(crops["pressed_offer_1_left"], ("02a_entry_first_offer_pressed", (498, 360, 502, 550)))
        self.assertEqual(crops["pressed_offer_1_right"], ("02a_entry_first_offer_pressed", (654, 360, 658, 550)))
        self.assertEqual(crops["pressed_offer_1_bottom"], ("02a_entry_first_offer_pressed", (498, 546, 658, 550)))
        self.assertEqual(crops["pressed_offer_1_art_upper"], ("02a_entry_first_offer_pressed", (502, 364, 624, 394)))
        self.assertEqual(crops["pressed_offer_1_art_lower"], ("02a_entry_first_offer_pressed", (502, 394, 654, 516)))

    def test_entry_second_offer_pressed_checks_complete_frame(self) -> None:
        crops = {
            name: (capture, box)
            for name, capture, box in MODULE.PIXEL_MATCH_CROPS
        }
        self.assertEqual(crops["pressed_offer_2_top"], ("02a2_entry_second_offer_pressed", (823, 360, 983, 364)))
        self.assertEqual(crops["pressed_offer_2_left"], ("02a2_entry_second_offer_pressed", (823, 360, 827, 550)))
        self.assertEqual(crops["pressed_offer_2_right"], ("02a2_entry_second_offer_pressed", (979, 360, 983, 550)))
        self.assertEqual(crops["pressed_offer_2_bottom"], ("02a2_entry_second_offer_pressed", (823, 546, 983, 550)))
        self.assertEqual(crops["pressed_offer_2_art_upper"], ("02a2_entry_second_offer_pressed", (827, 364, 949, 394)))
        self.assertEqual(crops["pressed_offer_2_art_lower"], ("02a2_entry_second_offer_pressed", (827, 394, 979, 516)))

    def test_entry_third_offer_pressed_checks_sloped_frame_and_art(self) -> None:
        crops = {
            name: (capture, box)
            for name, capture, box in MODULE.PIXEL_MATCH_CROPS
        }
        self.assertEqual(crops["pressed_offer_3_top"], ("02a3_entry_third_offer_pressed", (1148, 375, 1308, 379)))
        self.assertEqual(crops["pressed_offer_3_left"], ("02a3_entry_third_offer_pressed", (1148, 375, 1152, 565)))
        self.assertEqual(crops["pressed_offer_3_right"], ("02a3_entry_third_offer_pressed", (1304, 375, 1308, 565)))
        self.assertEqual(crops["pressed_offer_3_bottom"], ("02a3_entry_third_offer_pressed", (1148, 561, 1308, 565)))
        self.assertEqual(crops["pressed_offer_3_art_upper"], ("02a3_entry_third_offer_pressed", (1152, 394, 1274, 409)))
        self.assertEqual(crops["pressed_offer_3_art_lower"], ("02a3_entry_third_offer_pressed", (1152, 409, 1304, 546)))

    def test_empty_shelf_apertures_are_checked_as_complete_authored_regions(self) -> None:
        crops = {
            name: (capture, box)
            for name, capture, box in MODULE.PIXEL_MATCH_CROPS
        }
        self.assertEqual(
            crops["entry_empty_slot_4"],
            ("02c_entry_fourth_empty_slot_hover", (498, 610, 658, 800)),
        )
        self.assertEqual(
            crops["entry_empty_slot_4_click"],
            ("02c2_entry_fourth_empty_slot_click", (498, 610, 658, 800)),
        )
        self.assertEqual(
            crops["entry_empty_slot_5"],
            ("02d_entry_fifth_empty_slot_hover", (1148, 610, 1308, 800)),
        )
        self.assertEqual(
            crops["entry_empty_slot_5_click"],
            ("02d2_entry_fifth_empty_slot_click", (1148, 610, 1308, 800)),
        )

    def test_empty_bag_slot_hover_checks_the_full_authored_highlight(self) -> None:
        crops = {
            name: (capture, box)
            for name, capture, box in MODULE.PIXEL_MATCH_CROPS
        }
        self.assertEqual(
            crops["empty_bag_slot_hover"],
            ("07b_empty_bag_slot_hover", (541, 409, 724, 586)),
        )
        self.assertEqual(
            crops["empty_bag_slot_click_full_bag"],
            ("07c_empty_bag_slot_click", (502, 379, 1320, 818)),
        )
        self.assertEqual(
            crops["empty_bag_eighth_slot_hover"],
            ("07d_empty_bag_eighth_slot_hover", (1096, 587, 1279, 764)),
        )
        self.assertEqual(
            crops["mixed_bag_eighth_slot_hover"],
            ("15b_bag_pet_eighth_empty_slot_hover", (502, 379, 1320, 818)),
        )
        self.assertEqual(
            crops["mixed_bag_hover_cleared"],
            ("15c_bag_hover_cleared", (502, 379, 1320, 818)),
        )
        self.assertEqual(
            crops["occupied_bag_slot_click_full_bag"],
            ("15d_bag_pet_click", (502, 379, 1320, 818)),
        )
        self.assertEqual(
            crops["party_first_click_pet_and_slot"],
            ("06a_party_first_click", (552, 790, 730, 903)),
        )
        self.assertEqual(
            crops["party_second_click_pet_and_slot"],
            ("06c_party_second_click", (738, 790, 901, 903)),
        )
        self.assertEqual(
            crops["party_third_click_pet_and_slot"],
            ("10b2_party_third_click", (914, 790, 1077, 903)),
        )
        self.assertEqual(
            crops["party_fourth_click_pet_slot_and_right_edge"],
            ("10c2_party_fourth_click", (1094, 790, 1280, 903)),
        )
        self.assertEqual(
            crops["entry_second_empty_party_slot"],
            ("01b_entry_second_empty_party_slot_hover", (738, 790, 901, 903)),
        )
        self.assertEqual(
            crops["entry_second_empty_party_slot_click"],
            ("01b2_entry_second_empty_party_slot_click", (738, 790, 901, 922)),
        )
        self.assertEqual(
            crops["entry_fourth_empty_party_slot_and_right_edge"],
            ("01c_entry_fourth_empty_party_slot_hover", (1094, 790, 1280, 922)),
        )
        self.assertEqual(
            crops["entry_fourth_empty_party_slot_click_and_right_edge"],
            ("01c2_entry_fourth_empty_party_slot_click", (1094, 790, 1280, 922)),
        )
        self.assertEqual(
            crops["entry_third_empty_party_slot"],
            ("01d_entry_third_empty_party_slot_hover", (914, 790, 1077, 922)),
        )
        self.assertEqual(
            crops["entry_third_empty_party_slot_click"],
            ("01d2_entry_third_empty_party_slot_click", (914, 790, 1077, 922)),
        )

    def test_closed_bag_hover_covers_the_full_authored_chest(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        self.assertEqual(
            crops["bag_closed_hover_full"],
            ("06d_bag_closed_hover", (313, 776, 549, 1009)),
        )

    def test_closed_bag_pressed_covers_the_full_authored_chest(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        self.assertEqual(
            crops["bag_closed_pressed_full"],
            ("06d2_bag_closed_pressed", (313, 776, 549, 1009)),
        )

    def test_refresh_pressed_covers_the_authored_bell_upper_core(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        self.assertEqual(
            crops["refresh_bell_pressed_upper"],
            ("02b2_refresh_pressed", (954, 712, 1034, 765)),
        )

    def test_paid_refresh_hover_covers_the_authored_bell_upper_core(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        self.assertEqual(
            crops["paid_refresh_bell_hover_upper"],
            ("10d_paid_refresh_hover", (954, 712, 1034, 765)),
        )

    def test_paid_refresh_pressed_covers_the_authored_bell_upper_core(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        self.assertEqual(
            crops["paid_refresh_bell_pressed_upper"],
            ("10d2_paid_refresh_pressed", (954, 712, 1034, 765)),
        )

    def test_exit_pressed_covers_the_full_authored_exit_sign(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        self.assertEqual(
            crops["exit_pressed_full"],
            ("17b_exit_pressed", (1410, 490, 1679, 962)),
        )

    def test_exit_pressed_pointer_outside_covers_the_full_authored_exit_sign(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        self.assertEqual(
            crops["exit_pressed_pointer_outside_full"],
            ("17b2_exit_pressed_pointer_outside", (1410, 490, 1679, 962)),
        )

    def test_exit_pressed_pointer_reentered_covers_the_full_authored_exit_sign(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        self.assertEqual(
            crops["exit_pressed_pointer_reentered_full"],
            ("17b3_exit_pressed_pointer_reentered", (1410, 490, 1679, 962)),
        )

    def test_exit_pressed_pointer_outside_again_covers_the_full_authored_exit_sign(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        self.assertEqual(
            crops["exit_pressed_pointer_outside_again_full"],
            ("17b4_exit_pressed_pointer_outside_again", (1410, 490, 1679, 962)),
        )

    def test_exit_press_cancelled_covers_the_full_authored_exit_sign(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        self.assertEqual(
            crops["exit_press_cancelled_full"],
            ("17c_exit_press_cancelled", (1410, 490, 1679, 962)),
        )

    def test_exit_repressed_after_cancel_covers_the_full_authored_exit_sign(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        self.assertEqual(
            crops["exit_repressed_after_cancel_full"],
            ("17d_exit_repressed_after_cancel", (1410, 490, 1679, 962)),
        )

    def test_exit_repressed_pointer_outside_covers_the_full_authored_exit_sign(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        self.assertEqual(
            crops["exit_repressed_pointer_outside_full"],
            ("17e_exit_repressed_pointer_outside", (1410, 490, 1679, 962)),
        )

    def test_exit_repressed_pointer_reentered_covers_the_full_authored_exit_sign(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        self.assertEqual(
            crops["exit_repressed_pointer_reentered_full"],
            ("17f_exit_repressed_pointer_reentered", (1410, 490, 1679, 962)),
        )

    def test_reentered_shop_rechecks_three_offers_and_shared_rail(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        self.assertEqual(
            crops["reentered_shop_offer_1_full"],
            ("19_reenter_shop_after_exit", (498, 360, 658, 550)),
        )
        self.assertEqual(
            crops["reentered_shop_offer_2_full"],
            ("19_reenter_shop_after_exit", (823, 360, 983, 550)),
        )
        self.assertEqual(
            crops["reentered_shop_offer_3_full"],
            ("19_reenter_shop_after_exit", (1148, 375, 1308, 565)),
        )
        self.assertEqual(
            crops["reentered_shop_bag_closed_full"],
            ("19_reenter_shop_after_exit", (313, 776, 549, 1009)),
        )
        self.assertEqual(
            crops["reentered_shop_coin_panel_full"],
            ("19_reenter_shop_after_exit", (1303, 885, 1468, 1009)),
        )
        self.assertEqual(
            crops["reentered_shop_exit_full"],
            ("19_reenter_shop_after_exit", (1410, 490, 1679, 962)),
        )

    def test_reentered_second_offer_hover_covers_shared_art_outside_formal_tooltip(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        expected = {
            "reentered_shop_offer_2_hover_art_upper": (827, 364, 949, 394),
            "reentered_shop_offer_2_hover_art_body": (827, 394, 979, 463),
            "reentered_shop_offer_2_hover_top": (823, 360, 983, 364),
            "reentered_shop_offer_2_hover_left": (823, 360, 827, 550),
            "reentered_shop_offer_2_hover_right_upper": (979, 360, 983, 463),
            "reentered_shop_offer_2_hover_bottom": (823, 546, 983, 550),
        }
        for name, box in expected.items():
            self.assertEqual(crops[name], ("19a_reentered_second_offer_hover", box))

    def test_reentered_second_offer_pressed_and_cancelled_cover_hold_feedback(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        pressed = {
            "reentered_shop_offer_2_pressed_top": (823, 360, 983, 364),
            "reentered_shop_offer_2_pressed_left": (823, 360, 827, 550),
            "reentered_shop_offer_2_pressed_right": (979, 360, 983, 550),
            "reentered_shop_offer_2_pressed_bottom": (823, 546, 983, 550),
            "reentered_shop_offer_2_pressed_art_upper": (827, 364, 949, 394),
            "reentered_shop_offer_2_pressed_art_lower": (827, 394, 979, 516),
        }
        for name, box in pressed.items():
            self.assertEqual(crops[name], ("19b_reentered_second_offer_pressed", box))
        self.assertEqual(
            crops["reentered_shop_offer_2_cancelled_full"],
            ("19c_reentered_second_offer_press_cancelled", (823, 360, 983, 550)),
        )

    def test_reentered_second_offer_rehover_covers_shared_art_outside_formal_tooltip(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        expected = {
            "reentered_shop_offer_2_rehover_art_upper": (827, 364, 949, 394),
            "reentered_shop_offer_2_rehover_art_body": (827, 394, 979, 463),
            "reentered_shop_offer_2_rehover_top": (823, 360, 983, 364),
            "reentered_shop_offer_2_rehover_left": (823, 360, 827, 550),
            "reentered_shop_offer_2_rehover_right_upper": (979, 360, 983, 463),
            "reentered_shop_offer_2_rehover_bottom_left": (823, 546, 970, 550),
        }
        for name, box in expected.items():
            self.assertEqual(
                crops[name],
                ("19d_reentered_second_offer_rehover_after_cancel", box),
            )

    def test_reentered_second_offer_repress_covers_hold_feedback_after_tooltip_restore(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        expected = {
            "reentered_shop_offer_2_repressed_top": (823, 360, 983, 364),
            "reentered_shop_offer_2_repressed_left": (823, 360, 827, 550),
            "reentered_shop_offer_2_repressed_right": (979, 360, 983, 550),
            "reentered_shop_offer_2_repressed_bottom": (823, 546, 983, 550),
            "reentered_shop_offer_2_repressed_art_upper": (827, 364, 949, 394),
            "reentered_shop_offer_2_repressed_art_lower": (827, 394, 979, 516),
        }
        for name, box in expected.items():
            self.assertEqual(
                crops[name],
                ("19e_reentered_second_offer_repressed_after_cancel", box),
            )

    def test_reentered_second_offer_repress_move_out_covers_restored_offer(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        self.assertEqual(
            crops["reentered_shop_offer_2_repressed_full"],
            ("19e_reentered_second_offer_repressed_after_cancel", (823, 360, 983, 550)),
        )
        self.assertEqual(
            crops["reentered_shop_offer_2_repressed_outside_full"],
            ("19f_reentered_second_offer_repressed_pointer_outside", (823, 360, 983, 550)),
        )

    def test_reentered_second_offer_repress_reentry_covers_restored_hold_feedback(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        self.assertEqual(
            crops["reentered_shop_offer_2_repressed_reentered_full"],
            ("19g_reentered_second_offer_repressed_pointer_reentered", (823, 360, 983, 550)),
        )

    def test_reentered_second_offer_repress_second_exit_covers_restored_offer(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        self.assertEqual(
            crops["reentered_shop_offer_2_repressed_outside_again_full"],
            ("19h_reentered_second_offer_repressed_pointer_outside_again", (823, 360, 983, 550)),
        )

    def test_reentered_second_offer_repress_cycle_cancel_covers_restored_offer(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        self.assertEqual(
            crops["reentered_shop_offer_2_repress_cancelled_after_reentry_cycle_full"],
            ("19i_reentered_second_offer_repress_cancelled_after_reentry_cycle", (823, 360, 983, 550)),
        )

    def test_reentered_second_offer_rehover_after_repress_cycle_covers_shared_art(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        expected = {
            "reentered_shop_offer_2_rehover_after_repress_cycle_art_upper": (827, 364, 949, 394),
            "reentered_shop_offer_2_rehover_after_repress_cycle_art_body": (827, 394, 979, 463),
            "reentered_shop_offer_2_rehover_after_repress_cycle_top": (823, 360, 983, 364),
            "reentered_shop_offer_2_rehover_after_repress_cycle_left": (823, 360, 827, 550),
            "reentered_shop_offer_2_rehover_after_repress_cycle_right_upper": (979, 360, 983, 463),
            "reentered_shop_offer_2_rehover_after_repress_cycle_bottom_left": (823, 546, 970, 550),
        }
        for name, box in expected.items():
            self.assertEqual(
                crops[name],
                ("19j_reentered_second_offer_rehover_after_repress_cycle_cancel", box),
            )

    def test_coin_exit_boundary_covers_panel_overlap_and_exit(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        self.assertEqual(
            crops["coin_panel_safe_hover"],
            ("01e_entry_coin_panel_hover", (1303, 885, 1468, 1009)),
        )
        self.assertEqual(
            crops["coin_panel_safe_click"],
            ("01e2_entry_coin_panel_click", (1303, 885, 1468, 1009)),
        )
        self.assertEqual(
            crops["coin_panel_safe_click_exit"],
            ("01e2_entry_coin_panel_click", (1410, 490, 1679, 962)),
        )
        self.assertEqual(
            crops["coin_exit_overlap_hover_panel"],
            ("01f_entry_coin_exit_overlap_hover", (1303, 885, 1510, 1009)),
        )
        self.assertEqual(
            crops["coin_exit_overlap_hover_exit"],
            ("01f_entry_coin_exit_overlap_hover", (1410, 490, 1679, 962)),
        )
        self.assertEqual(
            crops["coin_exit_overlap_click_panel"],
            ("01f2_entry_coin_exit_overlap_click", (1303, 885, 1510, 1009)),
        )
        self.assertEqual(
            crops["coin_exit_overlap_click_exit"],
            ("01f2_entry_coin_exit_overlap_click", (1410, 490, 1679, 962)),
        )
        self.assertEqual(
            crops["exit_transparent_gap_hover"],
            ("01g_entry_exit_transparent_gap_hover", (1410, 490, 1679, 962)),
        )
        self.assertEqual(
            crops["exit_transparent_gap_click"],
            ("01g2_entry_exit_transparent_gap_click", (1410, 490, 1679, 962)),
        )

    def test_open_bag_hover_cleared_covers_chest_and_inventory(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        self.assertEqual(
            crops["bag_open_hover_cleared_full"],
            ("07a_bag_open_hover_cleared", (313, 776, 549, 1009)),
        )
        self.assertEqual(
            crops["bag_open_hover_cleared_inventory"],
            ("07a_bag_open_hover_cleared", (502, 379, 1320, 818)),
        )

    def test_open_bag_rehover_covers_chest_and_inventory(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        self.assertEqual(
            crops["bag_open_rehover_full"],
            ("07a2_bag_open_hover", (313, 776, 549, 1009)),
        )
        self.assertEqual(
            crops["bag_open_rehover_inventory"],
            ("07a2_bag_open_hover", (502, 379, 1320, 818)),
        )

    def test_open_bag_pressed_covers_chest_and_inventory(self) -> None:
        crops = {name: (capture, box) for name, capture, box in MODULE.PIXEL_MATCH_CROPS}
        self.assertEqual(
            crops["bag_open_pressed_full"],
            ("07a3_bag_open_pressed", (313, 776, 549, 1009)),
        )
        self.assertEqual(
            crops["bag_open_pressed_inventory"],
            ("07a3_bag_open_pressed", (502, 379, 1320, 818)),
        )

    def test_party_first_click_reuses_the_authored_hover_effect_gate(self) -> None:
        effects = {
            name: (baseline_capture, effect_capture, box, direction)
            for (
                name,
                baseline_capture,
                effect_capture,
                box,
                _max_channel_delta,
                _min_eligible_pixels,
                _max_mean_absolute_effect_error,
                direction,
            ) in MODULE.EFFECT_MATCH_CROPS
        }
        self.assertEqual(
            effects["party_shadow_first_click"],
            (
                "05_purchase_complete",
                "06a_party_first_click",
                (603, 903, 682, 922),
                "brighten",
            ),
        )

    def test_party_second_click_reuses_the_authored_hover_effect_gate(self) -> None:
        effects = {
            name: (baseline_capture, effect_capture, box, direction)
            for (
                name,
                baseline_capture,
                effect_capture,
                box,
                _max_channel_delta,
                _min_eligible_pixels,
                _max_mean_absolute_effect_error,
                direction,
            ) in MODULE.EFFECT_MATCH_CROPS
        }
        self.assertEqual(
            effects["party_shadow_second_click"],
            (
                "05_purchase_complete",
                "06c_party_second_click",
                (781, 903, 860, 922),
                "brighten",
            ),
        )

    def test_party_third_click_reuses_the_authored_hover_effect_gate(self) -> None:
        effects = {
            name: (baseline_capture, effect_capture, box, direction)
            for (
                name,
                baseline_capture,
                effect_capture,
                box,
                _max_channel_delta,
                _min_eligible_pixels,
                _max_mean_absolute_effect_error,
                direction,
            ) in MODULE.EFFECT_MATCH_CROPS
        }
        self.assertEqual(
            effects["party_shadow_third_click"],
            (
                "10_party_full_purchase",
                "10b2_party_third_click",
                (957, 903, 1036, 922),
                "brighten",
            ),
        )

    def test_party_fourth_click_reuses_the_authored_hover_effect_gate(self) -> None:
        effects = {
            name: (baseline_capture, effect_capture, box, direction)
            for (
                name,
                baseline_capture,
                effect_capture,
                box,
                _max_channel_delta,
                _min_eligible_pixels,
                _max_mean_absolute_effect_error,
                direction,
            ) in MODULE.EFFECT_MATCH_CROPS
        }
        self.assertEqual(
            effects["party_shadow_fourth_click"],
            (
                "10_party_full_purchase",
                "10c2_party_fourth_click",
                (1137, 903, 1216, 922),
                "brighten",
            ),
        )


if __name__ == "__main__":
    unittest.main()
