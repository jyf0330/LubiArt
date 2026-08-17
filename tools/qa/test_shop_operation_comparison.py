#!/usr/bin/env python3
"""Regression tests for shop operation state parity gates."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


MODULE_PATH = Path(__file__).with_name("build_shop_operation_comparison.py")
SPEC = importlib.util.spec_from_file_location("build_shop_operation_comparison", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class ShopOperationComparisonTests(unittest.TestCase):
    def test_default_acceptance_is_fixed_to_nine_commands_and_five_visual_supplements(self) -> None:
        self.assertEqual(len(MODULE.ACCEPTANCE_OPERATIONS), 14)
        self.assertEqual(
            tuple(name for name, _label in MODULE.ACCEPTANCE_OPERATIONS),
            MODULE.ACCEPTANCE_OPERATION_NAMES,
        )
        self.assertEqual(len({name for name, _label in MODULE.ACCEPTANCE_OPERATIONS}), 14)

    def test_matching_state_returns_audit_summary(self) -> None:
        state = {
            "phase": "route",
            "coins": 14,
            "offer_count": 3,
            "roster_count": 2,
            "state_version": 4,
            "state_hash": "1b70deda932ac7b5",
        }
        self.assertEqual(MODULE.parity_summary("18_exit_to_route", state, dict(state)), state)
        self.assertEqual(
            MODULE.state_label(state),
            "状态：route · 金币 14 · 商品 3 · 队伍 2 · v4 · 1b70deda932ac7b5",
        )

    def test_matching_interaction_returns_semantic_summary(self) -> None:
        art = {
            "interaction": {
                "pointer_position": [578, 454],
                "hovered": {"action": "BUY_OFFER", "offer_id": "shop_001", "control": "Offer01"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        formal = {
            "interaction": {
                "pointer_position": [578, 454],
                "hovered": {"action": "BUY_OFFER", "offer_id": "shop_001", "control": "BuyOfferButton_00"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        summary = MODULE.interaction_summary("02_offer_hover", art, formal)
        self.assertEqual(summary["hovered"], {"action": "BUY_OFFER", "offer_id": "shop_001"})
        self.assertEqual(summary["art_controls"]["hovered"], "Offer01")
        self.assertEqual(summary["formal_controls"]["hovered"], "BuyOfferButton_00")
        self.assertEqual(
            MODULE.interaction_label(summary),
            "交互：鼠标 (578,454) · 悬停 BUY_OFFER/shop_001 · 焦点 none",
        )

    def test_refresh_hover_is_a_separate_non_mutating_operation(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [988, 754],
                "hovered": {"action": "ROLL_SHOP", "offer_id": "", "control": "RefreshButton"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        summary = MODULE.interaction_summary(
            "02b_refresh_hover",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["hovered"], {"action": "ROLL_SHOP", "offer_id": ""})
        self.assertIn(("02b_refresh_hover", "悬停刷新铃但不点击"), MODULE.OPERATIONS)

    def test_offer_pressed_requires_matching_offer_focus_before_cancel(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [578, 454],
                "hovered": {"action": "BUY_OFFER", "offer_id": "shop_001", "control": "Offer01"},
                "focused": {"action": "BUY_OFFER", "offer_id": "shop_001", "control": "Offer01"},
            }
        }
        summary = MODULE.interaction_summary(
            "02a_entry_first_offer_pressed",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["hovered"], {"action": "BUY_OFFER", "offer_id": "shop_001"})
        self.assertEqual(summary["focused"], {"action": "BUY_OFFER", "offer_id": "shop_001"})
        self.assertIn(
            ("02a_entry_first_offer_pressed", "按下第一件商品但尚未松开"),
            MODULE.OPERATIONS,
        )

    def test_second_offer_pressed_requires_matching_offer_focus_before_cancel(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [902, 454],
                "hovered": {"action": "BUY_OFFER", "offer_id": "shop_002", "control": "Offer02"},
                "focused": {"action": "BUY_OFFER", "offer_id": "shop_002", "control": "Offer02"},
            }
        }
        summary = MODULE.interaction_summary(
            "02a2_entry_second_offer_pressed",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["hovered"], {"action": "BUY_OFFER", "offer_id": "shop_002"})
        self.assertEqual(summary["focused"], {"action": "BUY_OFFER", "offer_id": "shop_002"})
        self.assertIn(
            ("02a2_entry_second_offer_pressed", "按下第二件商品但尚未松开"),
            MODULE.OPERATIONS,
        )

    def test_third_offer_pressed_requires_matching_offer_focus_before_cancel(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [1228, 470],
                "hovered": {"action": "BUY_OFFER", "offer_id": "shop_003", "control": "Offer03"},
                "focused": {"action": "BUY_OFFER", "offer_id": "shop_003", "control": "Offer03"},
            }
        }
        summary = MODULE.interaction_summary(
            "02a3_entry_third_offer_pressed",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["hovered"], {"action": "BUY_OFFER", "offer_id": "shop_003"})
        self.assertEqual(summary["focused"], {"action": "BUY_OFFER", "offer_id": "shop_003"})
        self.assertIn(
            ("02a3_entry_third_offer_pressed", "按下第三件商品但尚未松开"),
            MODULE.OPERATIONS,
        )

    def test_refresh_pressed_requires_matching_focus_before_release(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [988, 754],
                "hovered": {"action": "ROLL_SHOP", "offer_id": "", "control": "RefreshButton"},
                "focused": {"action": "ROLL_SHOP", "offer_id": "", "control": "RefreshButton"},
            }
        }
        summary = MODULE.interaction_summary(
            "02b2_refresh_pressed",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["hovered"], {"action": "ROLL_SHOP", "offer_id": ""})
        self.assertEqual(summary["focused"], {"action": "ROLL_SHOP", "offer_id": ""})
        self.assertIn(("02b2_refresh_pressed", "按下刷新铃但尚未松开"), MODULE.OPERATIONS)

    def test_paid_refresh_hover_keeps_the_refresh_action_without_focus(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [988, 754],
                "hovered": {"action": "ROLL_SHOP", "offer_id": "", "control": "RefreshButton"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        summary = MODULE.interaction_summary(
            "10d_paid_refresh_hover",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["hovered"], {"action": "ROLL_SHOP", "offer_id": ""})
        self.assertEqual(summary["focused"], {"action": "none", "offer_id": ""})
        self.assertIn(("10d_paid_refresh_hover", "悬停付费刷新铃但不点击"), MODULE.OPERATIONS)

    def test_paid_refresh_pressed_requires_matching_focus_before_release(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [988, 754],
                "hovered": {"action": "ROLL_SHOP", "offer_id": "", "control": "RefreshButton"},
                "focused": {"action": "ROLL_SHOP", "offer_id": "", "control": "RefreshButton"},
            }
        }
        summary = MODULE.interaction_summary(
            "10d2_paid_refresh_pressed",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["hovered"], {"action": "ROLL_SHOP", "offer_id": ""})
        self.assertEqual(summary["focused"], {"action": "ROLL_SHOP", "offer_id": ""})
        self.assertIn(("10d2_paid_refresh_pressed", "按下付费刷新铃但尚未松开"), MODULE.OPERATIONS)

    def test_exit_pressed_requires_matching_focus_before_release(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [1544, 726],
                "hovered": {"action": "EXIT_SHOP", "offer_id": "", "control": "ExitButton"},
                "focused": {"action": "EXIT_SHOP", "offer_id": "", "control": "ExitButton"},
            }
        }
        summary = MODULE.interaction_summary(
            "17b_exit_pressed",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["hovered"], {"action": "EXIT_SHOP", "offer_id": ""})
        self.assertEqual(summary["focused"], {"action": "EXIT_SHOP", "offer_id": ""})
        self.assertIn(("17b_exit_pressed", "按下退出牌但尚未松开"), MODULE.OPERATIONS)

    def test_exit_press_cancelled_returns_to_neutral_interaction(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [1850, 1030],
                "hovered": {"action": "none", "offer_id": "", "control": ""},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        summary = MODULE.interaction_summary(
            "17c_exit_press_cancelled",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["pointer_position"], [1850, 1030])
        self.assertEqual(summary["hovered"], {"action": "none", "offer_id": ""})
        self.assertEqual(summary["focused"], {"action": "none", "offer_id": ""})
        self.assertIn(("17c_exit_press_cancelled", "移出退出牌并松开取消"), MODULE.OPERATIONS)

    def test_exit_pressed_pointer_outside_keeps_focus_until_release(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [1850, 1030],
                "hovered": {"action": "none", "offer_id": "", "control": ""},
                "focused": {"action": "EXIT_SHOP", "offer_id": "", "control": "ExitButton"},
            }
        }
        summary = MODULE.interaction_summary(
            "17b2_exit_pressed_pointer_outside",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["pointer_position"], [1850, 1030])
        self.assertEqual(summary["hovered"], {"action": "none", "offer_id": ""})
        self.assertEqual(summary["focused"], {"action": "EXIT_SHOP", "offer_id": ""})
        self.assertIn(("17b2_exit_pressed_pointer_outside", "按住退出牌并移出"), MODULE.OPERATIONS)

    def test_exit_pressed_pointer_reentered_restores_hover_and_keeps_focus(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [1544, 726],
                "hovered": {"action": "EXIT_SHOP", "offer_id": "", "control": "ExitButton"},
                "focused": {"action": "EXIT_SHOP", "offer_id": "", "control": "ExitButton"},
            }
        }
        summary = MODULE.interaction_summary(
            "17b3_exit_pressed_pointer_reentered",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["pointer_position"], [1544, 726])
        self.assertEqual(summary["hovered"], {"action": "EXIT_SHOP", "offer_id": ""})
        self.assertEqual(summary["focused"], {"action": "EXIT_SHOP", "offer_id": ""})
        self.assertIn(("17b3_exit_pressed_pointer_reentered", "按住退出牌移出后重新移入"), MODULE.OPERATIONS)

    def test_exit_pressed_pointer_outside_again_clears_hover_and_keeps_focus(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [1850, 1030],
                "hovered": {"action": "none", "offer_id": "", "control": ""},
                "focused": {"action": "EXIT_SHOP", "offer_id": "", "control": "ExitButton"},
            }
        }
        summary = MODULE.interaction_summary(
            "17b4_exit_pressed_pointer_outside_again",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["pointer_position"], [1850, 1030])
        self.assertEqual(summary["hovered"], {"action": "none", "offer_id": ""})
        self.assertEqual(summary["focused"], {"action": "EXIT_SHOP", "offer_id": ""})
        self.assertIn(("17b4_exit_pressed_pointer_outside_again", "按住退出牌重新移出但尚未松开"), MODULE.OPERATIONS)

    def test_exit_repressed_after_cancel_restores_hover_and_focus(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [1544, 726],
                "hovered": {"action": "EXIT_SHOP", "offer_id": "", "control": "ExitButton"},
                "focused": {"action": "EXIT_SHOP", "offer_id": "", "control": "ExitButton"},
            }
        }
        summary = MODULE.interaction_summary(
            "17d_exit_repressed_after_cancel",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["pointer_position"], [1544, 726])
        self.assertEqual(summary["hovered"], {"action": "EXIT_SHOP", "offer_id": ""})
        self.assertEqual(summary["focused"], {"action": "EXIT_SHOP", "offer_id": ""})
        self.assertIn(("17d_exit_repressed_after_cancel", "取消后再次按住退出牌"), MODULE.OPERATIONS)

    def test_exit_repressed_pointer_outside_clears_hover_and_keeps_focus(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [1850, 1030],
                "hovered": {"action": "none", "offer_id": "", "control": ""},
                "focused": {"action": "EXIT_SHOP", "offer_id": "", "control": "ExitButton"},
            }
        }
        summary = MODULE.interaction_summary(
            "17e_exit_repressed_pointer_outside",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["pointer_position"], [1850, 1030])
        self.assertEqual(summary["hovered"], {"action": "none", "offer_id": ""})
        self.assertEqual(summary["focused"], {"action": "EXIT_SHOP", "offer_id": ""})
        self.assertIn(("17e_exit_repressed_pointer_outside", "取消后再次按住退出牌并移出"), MODULE.OPERATIONS)

    def test_exit_repressed_pointer_reentered_restores_hover_and_keeps_focus(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [1544, 726],
                "hovered": {"action": "EXIT_SHOP", "offer_id": "", "control": "ExitButton"},
                "focused": {"action": "EXIT_SHOP", "offer_id": "", "control": "ExitButton"},
            }
        }
        summary = MODULE.interaction_summary(
            "17f_exit_repressed_pointer_reentered",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["pointer_position"], [1544, 726])
        self.assertEqual(summary["hovered"], {"action": "EXIT_SHOP", "offer_id": ""})
        self.assertEqual(summary["focused"], {"action": "EXIT_SHOP", "offer_id": ""})
        self.assertIn(("17f_exit_repressed_pointer_reentered", "取消后再次按住移出后重新移入"), MODULE.OPERATIONS)

    def test_reenter_shop_after_exit_is_neutral_shop_visual_parity(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [1850, 1030],
                "hovered": {"action": "none", "offer_id": "", "control": ""},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        summary = MODULE.interaction_summary(
            "19_reenter_shop_after_exit",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["pointer_position"], [1850, 1030])
        self.assertIn(("19_reenter_shop_after_exit", "退出后重新进入商店"), MODULE.OPERATIONS)
        self.assertNotIn("19_reenter_shop_after_exit", MODULE.STATE_ONLY_VISUAL_OPERATIONS)

    def test_reentered_second_offer_hover_keeps_synchronized_identity(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [902, 454],
                "hovered": {"action": "BUY_OFFER", "offer_id": "shop_002", "control": "Offer02"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        summary = MODULE.interaction_summary(
            "19a_reentered_second_offer_hover",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["pointer_position"], [902, 454])
        self.assertEqual(summary["hovered"], {"action": "BUY_OFFER", "offer_id": "shop_002"})
        self.assertEqual(summary["focused"], {"action": "none", "offer_id": ""})
        self.assertIn(("19a_reentered_second_offer_hover", "重进商店后悬停第二件商品"), MODULE.OPERATIONS)
        self.assertNotIn("19a_reentered_second_offer_hover", MODULE.STATE_ONLY_VISUAL_OPERATIONS)

    def test_reentered_second_offer_press_cancel_rehover_repress_and_move_out_have_separate_interactions(self) -> None:
        pressed = {
            "interaction": {
                "pointer_position": [902, 454],
                "hovered": {"action": "BUY_OFFER", "offer_id": "shop_002", "control": "Offer02"},
                "focused": {"action": "BUY_OFFER", "offer_id": "shop_002", "control": "Offer02"},
            }
        }
        cancelled = {
            "interaction": {
                "pointer_position": [1850, 1030],
                "hovered": {"action": "none", "offer_id": "", "control": ""},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        rehovered = {
            "interaction": {
                "pointer_position": [902, 454],
                "hovered": {"action": "BUY_OFFER", "offer_id": "shop_002", "control": "Offer02"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        repressed = {
            "interaction": {
                "pointer_position": [902, 454],
                "hovered": {"action": "BUY_OFFER", "offer_id": "shop_002", "control": "Offer02"},
                "focused": {"action": "BUY_OFFER", "offer_id": "shop_002", "control": "Offer02"},
            }
        }
        repressed_outside = {
            "interaction": {
                "pointer_position": [1850, 1030],
                "hovered": {"action": "none", "offer_id": "", "control": ""},
                "focused": {"action": "BUY_OFFER", "offer_id": "shop_002", "control": "Offer02"},
            }
        }
        repressed_reentered = json.loads(json.dumps(repressed))
        repressed_outside_again = json.loads(json.dumps(repressed_outside))
        repress_cancelled_after_cycle = json.loads(json.dumps(cancelled))
        rehovered_after_repress_cycle = json.loads(json.dumps(rehovered))
        pressed_summary = MODULE.interaction_summary(
            "19b_reentered_second_offer_pressed", pressed, json.loads(json.dumps(pressed))
        )
        cancelled_summary = MODULE.interaction_summary(
            "19c_reentered_second_offer_press_cancelled", cancelled, json.loads(json.dumps(cancelled))
        )
        rehovered_summary = MODULE.interaction_summary(
            "19d_reentered_second_offer_rehover_after_cancel", rehovered, json.loads(json.dumps(rehovered))
        )
        repressed_summary = MODULE.interaction_summary(
            "19e_reentered_second_offer_repressed_after_cancel", repressed, json.loads(json.dumps(repressed))
        )
        repressed_outside_summary = MODULE.interaction_summary(
            "19f_reentered_second_offer_repressed_pointer_outside",
            repressed_outside,
            json.loads(json.dumps(repressed_outside)),
        )
        repressed_reentered_summary = MODULE.interaction_summary(
            "19g_reentered_second_offer_repressed_pointer_reentered",
            repressed_reentered,
            json.loads(json.dumps(repressed_reentered)),
        )
        repressed_outside_again_summary = MODULE.interaction_summary(
            "19h_reentered_second_offer_repressed_pointer_outside_again",
            repressed_outside_again,
            json.loads(json.dumps(repressed_outside_again)),
        )
        repress_cancelled_after_cycle_summary = MODULE.interaction_summary(
            "19i_reentered_second_offer_repress_cancelled_after_reentry_cycle",
            repress_cancelled_after_cycle,
            json.loads(json.dumps(repress_cancelled_after_cycle)),
        )
        rehovered_after_repress_cycle_summary = MODULE.interaction_summary(
            "19j_reentered_second_offer_rehover_after_repress_cycle_cancel",
            rehovered_after_repress_cycle,
            json.loads(json.dumps(rehovered_after_repress_cycle)),
        )
        self.assertEqual(pressed_summary["hovered"], {"action": "BUY_OFFER", "offer_id": "shop_002"})
        self.assertEqual(pressed_summary["focused"], {"action": "BUY_OFFER", "offer_id": "shop_002"})
        self.assertEqual(cancelled_summary["pointer_position"], [1850, 1030])
        self.assertEqual(cancelled_summary["hovered"], {"action": "none", "offer_id": ""})
        self.assertEqual(cancelled_summary["focused"], {"action": "none", "offer_id": ""})
        self.assertEqual(rehovered_summary["pointer_position"], [902, 454])
        self.assertEqual(rehovered_summary["hovered"], {"action": "BUY_OFFER", "offer_id": "shop_002"})
        self.assertEqual(rehovered_summary["focused"], {"action": "none", "offer_id": ""})
        self.assertEqual(repressed_summary["pointer_position"], [902, 454])
        self.assertEqual(repressed_summary["hovered"], {"action": "BUY_OFFER", "offer_id": "shop_002"})
        self.assertEqual(repressed_summary["focused"], {"action": "BUY_OFFER", "offer_id": "shop_002"})
        self.assertEqual(repressed_outside_summary["pointer_position"], [1850, 1030])
        self.assertEqual(repressed_outside_summary["hovered"], {"action": "none", "offer_id": ""})
        self.assertEqual(repressed_outside_summary["focused"], {"action": "BUY_OFFER", "offer_id": "shop_002"})
        self.assertEqual(repressed_reentered_summary["pointer_position"], [902, 454])
        self.assertEqual(repressed_reentered_summary["hovered"], {"action": "BUY_OFFER", "offer_id": "shop_002"})
        self.assertEqual(repressed_reentered_summary["focused"], {"action": "BUY_OFFER", "offer_id": "shop_002"})
        self.assertEqual(repressed_outside_again_summary["pointer_position"], [1850, 1030])
        self.assertEqual(repressed_outside_again_summary["hovered"], {"action": "none", "offer_id": ""})
        self.assertEqual(repressed_outside_again_summary["focused"], {"action": "BUY_OFFER", "offer_id": "shop_002"})
        self.assertEqual(repress_cancelled_after_cycle_summary["pointer_position"], [1850, 1030])
        self.assertEqual(repress_cancelled_after_cycle_summary["hovered"], {"action": "none", "offer_id": ""})
        self.assertEqual(repress_cancelled_after_cycle_summary["focused"], {"action": "none", "offer_id": ""})
        self.assertEqual(rehovered_after_repress_cycle_summary["pointer_position"], [902, 454])
        self.assertEqual(rehovered_after_repress_cycle_summary["hovered"], {"action": "BUY_OFFER", "offer_id": "shop_002"})
        self.assertEqual(rehovered_after_repress_cycle_summary["focused"], {"action": "none", "offer_id": ""})
        self.assertIn(("19b_reentered_second_offer_pressed", "重进商店后按下第二件商品但尚未松开"), MODULE.OPERATIONS)
        self.assertIn(("19c_reentered_second_offer_press_cancelled", "重进商店后移出并松开取消第二件商品"), MODULE.OPERATIONS)
        self.assertIn(("19d_reentered_second_offer_rehover_after_cancel", "取消后重新悬停重进商店第二件商品"), MODULE.OPERATIONS)
        self.assertIn(("19e_reentered_second_offer_repressed_after_cancel", "取消后重新悬停并再次按住重进商店第二件商品"), MODULE.OPERATIONS)
        self.assertIn(("19f_reentered_second_offer_repressed_pointer_outside", "取消后再次按住重进商店第二件商品并移出"), MODULE.OPERATIONS)
        self.assertIn(("19g_reentered_second_offer_repressed_pointer_reentered", "取消后再次按住移出并重新移入重进商店第二件商品"), MODULE.OPERATIONS)
        self.assertIn(("19h_reentered_second_offer_repressed_pointer_outside_again", "取消后再次按住移出重新移入后再次移出重进商店第二件商品"), MODULE.OPERATIONS)
        self.assertIn(("19i_reentered_second_offer_repress_cancelled_after_reentry_cycle", "再次按住移出重新移入再移出后松开取消重进商店第二件商品"), MODULE.OPERATIONS)
        self.assertIn(("19j_reentered_second_offer_rehover_after_repress_cycle_cancel", "第二次按压往返取消后重新悬停重进商店第二件商品"), MODULE.OPERATIONS)

    def test_exit_route_is_explicitly_state_only_visual_scope(self) -> None:
        self.assertEqual(MODULE.STATE_ONLY_VISUAL_OPERATIONS, {"18_exit_to_route"})

    def test_entry_second_empty_party_slot_has_no_occupied_identity(self) -> None:
        art = {
            "interaction": {
                "pointer_position": [820, 878],
                "hovered": {"action": "none", "offer_id": "", "control": "Party_Slot2"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        formal = json.loads(json.dumps(art))
        formal["interaction"]["hovered"]["control"] = ""
        summary = MODULE.interaction_summary(
            "01b_entry_second_empty_party_slot_hover",
            art,
            formal,
        )
        self.assertEqual(summary["pointer_position"], [820, 878])
        self.assertEqual(summary["hovered"], {"action": "none", "offer_id": ""})
        self.assertIn(
            ("01b_entry_second_empty_party_slot_hover", "悬停入口第二个空队伍槽"),
            MODULE.OPERATIONS,
        )

    def test_entry_second_empty_party_slot_click_remains_a_no_op(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [820, 878],
                "hovered": {"action": "none", "offer_id": "", "control": "Party_Slot2"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        summary = MODULE.interaction_summary(
            "01b2_entry_second_empty_party_slot_click",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["pointer_position"], [820, 878])
        self.assertEqual(summary["hovered"], {"action": "none", "offer_id": ""})
        self.assertIn(
            ("01b2_entry_second_empty_party_slot_click", "点击入口第二个空队伍槽"),
            MODULE.OPERATIONS,
        )

    def test_entry_fourth_empty_party_slot_covers_the_right_boundary(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [1176, 878],
                "hovered": {"action": "none", "offer_id": "", "control": "Party_Slot4"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        formal = json.loads(json.dumps(interaction))
        formal["interaction"]["hovered"]["control"] = ""
        summary = MODULE.interaction_summary(
            "01c_entry_fourth_empty_party_slot_hover",
            interaction,
            formal,
        )
        self.assertEqual(summary["pointer_position"], [1176, 878])
        self.assertEqual(summary["hovered"], {"action": "none", "offer_id": ""})
        self.assertIn(
            ("01c_entry_fourth_empty_party_slot_hover", "悬停入口第四个空队伍槽"),
            MODULE.OPERATIONS,
        )

    def test_entry_fourth_empty_party_slot_click_stays_semantically_empty(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [1176, 878],
                "hovered": {"action": "none", "offer_id": "", "control": "Party_Slot4"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        formal = json.loads(json.dumps(interaction))
        formal["interaction"]["hovered"]["control"] = ""
        summary = MODULE.interaction_summary(
            "01c2_entry_fourth_empty_party_slot_click",
            interaction,
            formal,
        )
        self.assertEqual(summary["pointer_position"], [1176, 878])
        self.assertEqual(summary["hovered"], {"action": "none", "offer_id": ""})
        self.assertIn(
            ("01c2_entry_fourth_empty_party_slot_click", "点击入口第四个空队伍槽"),
            MODULE.OPERATIONS,
        )

    def test_entry_third_empty_party_slot_covers_the_middle_aperture(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [996, 878],
                "hovered": {"action": "none", "offer_id": "", "control": "Party_Slot3"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        formal = json.loads(json.dumps(interaction))
        formal["interaction"]["hovered"]["control"] = ""
        summary = MODULE.interaction_summary(
            "01d_entry_third_empty_party_slot_hover",
            interaction,
            formal,
        )
        self.assertEqual(summary["pointer_position"], [996, 878])
        self.assertEqual(summary["hovered"], {"action": "none", "offer_id": ""})
        self.assertIn(
            ("01d_entry_third_empty_party_slot_hover", "悬停入口第三个空队伍槽"),
            MODULE.OPERATIONS,
        )

    def test_entry_third_empty_party_slot_click_stays_semantically_empty(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [996, 878],
                "hovered": {"action": "none", "offer_id": "", "control": "Party_Slot3"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        formal = json.loads(json.dumps(interaction))
        formal["interaction"]["hovered"]["control"] = ""
        summary = MODULE.interaction_summary(
            "01d2_entry_third_empty_party_slot_click",
            interaction,
            formal,
        )
        self.assertEqual(summary["pointer_position"], [996, 878])
        self.assertEqual(summary["hovered"], {"action": "none", "offer_id": ""})
        self.assertIn(
            ("01d2_entry_third_empty_party_slot_click", "点击入口第三个空队伍槽"),
            MODULE.OPERATIONS,
        )

    def test_closed_bag_hover_uses_the_shared_toggle_semantics(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [430, 892],
                "hovered": {"action": "TOGGLE_BAG", "offer_id": "", "control": "Bag_Button"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        formal = json.loads(json.dumps(interaction))
        formal["interaction"]["hovered"]["control"] = "ShopBagButton"
        summary = MODULE.interaction_summary("06d_bag_closed_hover", interaction, formal)
        self.assertEqual(summary["pointer_position"], [430, 892])
        self.assertEqual(summary["hovered"], {"action": "TOGGLE_BAG", "offer_id": ""})
        self.assertIn(("06d_bag_closed_hover", "悬停关闭态宝箱"), MODULE.OPERATIONS)

    def test_closed_bag_pressed_requires_matching_toggle_focus_before_cancel(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [430, 892],
                "hovered": {"action": "TOGGLE_BAG", "offer_id": "", "control": "Bag_Button"},
                "focused": {"action": "TOGGLE_BAG", "offer_id": "", "control": "Bag_Button"},
            }
        }
        formal = json.loads(json.dumps(interaction))
        formal["interaction"]["hovered"]["control"] = "ShopBagButton"
        formal["interaction"]["focused"]["control"] = "ShopBagButton"
        summary = MODULE.interaction_summary("06d2_bag_closed_pressed", interaction, formal)
        self.assertEqual(summary["pointer_position"], [430, 892])
        self.assertEqual(summary["hovered"], {"action": "TOGGLE_BAG", "offer_id": ""})
        self.assertEqual(summary["focused"], {"action": "TOGGLE_BAG", "offer_id": ""})
        self.assertIn(
            ("06d2_bag_closed_pressed", "按下关闭态宝箱但尚未松开"),
            MODULE.OPERATIONS,
        )

    def test_open_bag_hover_cleared_uses_the_neutral_pointer(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [1850, 1030],
                "hovered": {"action": "none", "offer_id": "", "control": ""},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        summary = MODULE.interaction_summary(
            "07a_bag_open_hover_cleared",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["pointer_position"], [1850, 1030])
        self.assertEqual(summary["hovered"], {"action": "none", "offer_id": ""})
        self.assertIn(
            ("07a_bag_open_hover_cleared", "鼠标移出打开态宝箱"),
            MODULE.OPERATIONS,
        )

    def test_open_bag_rehover_restores_the_toggle_semantics(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [430, 892],
                "hovered": {"action": "TOGGLE_BAG", "offer_id": "", "control": "Bag_Button"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        formal = json.loads(json.dumps(interaction))
        formal["interaction"]["hovered"]["control"] = "ShopBagButton"
        summary = MODULE.interaction_summary("07a2_bag_open_hover", interaction, formal)
        self.assertEqual(summary["pointer_position"], [430, 892])
        self.assertEqual(summary["hovered"], {"action": "TOGGLE_BAG", "offer_id": ""})
        self.assertIn(
            ("07a2_bag_open_hover", "重新悬停打开态宝箱"),
            MODULE.OPERATIONS,
        )

    def test_open_bag_pressed_requires_matching_toggle_focus_before_cancel(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [430, 892],
                "hovered": {"action": "TOGGLE_BAG", "offer_id": "", "control": "Bag_Button"},
                "focused": {"action": "TOGGLE_BAG", "offer_id": "", "control": "Bag_Button"},
            }
        }
        formal = json.loads(json.dumps(interaction))
        formal["interaction"]["hovered"]["control"] = "ShopBagButton"
        formal["interaction"]["focused"]["control"] = "ShopBagButton"
        summary = MODULE.interaction_summary("07a3_bag_open_pressed", interaction, formal)
        self.assertEqual(summary["pointer_position"], [430, 892])
        self.assertEqual(summary["hovered"], {"action": "TOGGLE_BAG", "offer_id": ""})
        self.assertEqual(summary["focused"], {"action": "TOGGLE_BAG", "offer_id": ""})
        self.assertIn(
            ("07a3_bag_open_pressed", "按下打开态宝箱但尚未松开"),
            MODULE.OPERATIONS,
        )

    def test_coin_panel_safe_hover_has_no_semantic_action(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [1388, 930],
                "hovered": {"action": "none", "offer_id": "", "control": ""},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        summary = MODULE.interaction_summary(
            "01e_entry_coin_panel_hover",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["pointer_position"], [1388, 930])
        self.assertEqual(summary["hovered"], {"action": "none", "offer_id": ""})

    def test_coin_panel_click_keeps_none_semantics(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [1388, 930],
                "hovered": {"action": "none", "offer_id": "", "control": ""},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        summary = MODULE.interaction_summary(
            "01e2_entry_coin_panel_click",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["pointer_position"], [1388, 930])
        self.assertEqual(summary["hovered"], {"action": "none", "offer_id": ""})
        self.assertIn(
            ("01e2_entry_coin_panel_click", "点击金币牌安全区"),
            MODULE.OPERATIONS,
        )

    def test_coin_exit_overlap_hover_blocks_exit_semantics(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [1412, 930],
                "hovered": {"action": "none", "offer_id": "", "control": ""},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        formal = json.loads(json.dumps(interaction))
        summary = MODULE.interaction_summary("01f_entry_coin_exit_overlap_hover", interaction, formal)
        self.assertEqual(summary["pointer_position"], [1412, 930])
        self.assertEqual(summary["hovered"], {"action": "none", "offer_id": ""})
        self.assertIn(
            ("01f_entry_coin_exit_overlap_hover", "悬停金币牌与退出牌交叠边缘"),
            MODULE.OPERATIONS,
        )

    def test_coin_exit_overlap_click_keeps_none_semantics(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [1412, 930],
                "hovered": {"action": "none", "offer_id": "", "control": ""},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        summary = MODULE.interaction_summary(
            "01f2_entry_coin_exit_overlap_click",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["pointer_position"], [1412, 930])
        self.assertEqual(summary["hovered"], {"action": "none", "offer_id": ""})
        self.assertIn(
            ("01f2_entry_coin_exit_overlap_click", "点击金币牌与退出牌交叠边缘"),
            MODULE.OPERATIONS,
        )

    def test_exit_transparent_gap_hover_and_click_keep_none_semantics(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [1544, 500],
                "hovered": {"action": "none", "offer_id": "", "control": ""},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        for operation, label in (
            ("01g_entry_exit_transparent_gap_hover", "悬停退出牌透明空隙"),
            ("01g2_entry_exit_transparent_gap_click", "点击退出牌透明空隙"),
        ):
            summary = MODULE.interaction_summary(
                operation,
                interaction,
                json.loads(json.dumps(interaction)),
            )
            self.assertEqual(summary["pointer_position"], [1544, 500])
            self.assertEqual(summary["hovered"], {"action": "none", "offer_id": ""})
            self.assertIn((operation, label), MODULE.OPERATIONS)

    def test_second_party_slot_hover_has_an_independent_pointer_gate(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [820, 878],
                "hovered": {"action": "PARTY_SLOT", "offer_id": "", "control": "PartySlotButton_1"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        summary = MODULE.interaction_summary(
            "06b_party_second_hover",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["pointer_position"], [820, 878])
        self.assertEqual(summary["hovered"], {"action": "PARTY_SLOT", "offer_id": ""})

    def test_first_party_slot_click_keeps_the_party_identity(self) -> None:
        art = {
            "interaction": {
                "pointer_position": [642, 878],
                "hovered": {"action": "PARTY_SLOT", "offer_id": "", "control": "Party_Slot"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        formal = json.loads(json.dumps(art))
        formal["interaction"]["hovered"]["control"] = "PartySlotButton_0"
        summary = MODULE.interaction_summary("06a_party_first_click", art, formal)
        self.assertEqual(summary["pointer_position"], [642, 878])
        self.assertEqual(summary["hovered"], {"action": "PARTY_SLOT", "offer_id": ""})
        self.assertIn(("06a_party_first_click", "点击第一名队伍宠物"), MODULE.OPERATIONS)

    def test_second_party_slot_click_keeps_the_party_identity(self) -> None:
        art = {
            "interaction": {
                "pointer_position": [820, 878],
                "hovered": {"action": "PARTY_SLOT", "offer_id": "", "control": "Party_Slot2"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        formal = json.loads(json.dumps(art))
        formal["interaction"]["hovered"]["control"] = "PartySlotButton_1"
        summary = MODULE.interaction_summary("06c_party_second_click", art, formal)
        self.assertEqual(summary["pointer_position"], [820, 878])
        self.assertEqual(summary["hovered"], {"action": "PARTY_SLOT", "offer_id": ""})
        self.assertIn(("06c_party_second_click", "点击第二名队伍宠物"), MODULE.OPERATIONS)

    def test_empty_bag_slot_hover_blocks_the_underlying_offer(self) -> None:
        art = {
            "interaction": {
                "pointer_position": [628, 496],
                "hovered": {"action": "BAG_SLOT", "offer_id": "", "control": "Bag_Slot"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        formal = json.loads(json.dumps(art))
        formal["interaction"]["hovered"]["control"] = "BagSlotButton_0"
        summary = MODULE.interaction_summary("07b_empty_bag_slot_hover", art, formal)
        self.assertEqual(summary["pointer_position"], [628, 496])
        self.assertEqual(summary["hovered"], {"action": "BAG_SLOT", "offer_id": ""})
        self.assertNotEqual(summary["formal_controls"]["hovered"], "BuyOfferButton_00")

    def test_empty_bag_slot_click_remains_a_no_op_bag_interaction(self) -> None:
        art = {
            "interaction": {
                "pointer_position": [628, 496],
                "hovered": {"action": "BAG_SLOT", "offer_id": "", "control": "Bag_Slot"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        formal = json.loads(json.dumps(art))
        formal["interaction"]["hovered"]["control"] = "BagSlotButton_0"
        summary = MODULE.interaction_summary("07c_empty_bag_slot_click", art, formal)
        self.assertEqual(summary["pointer_position"], [628, 496])
        self.assertEqual(summary["hovered"], {"action": "BAG_SLOT", "offer_id": ""})
        self.assertIn(("07c_empty_bag_slot_click", "点击空背包第一槽"), MODULE.OPERATIONS)

    def test_eighth_empty_bag_slot_covers_the_far_authored_boundary(self) -> None:
        art = {
            "interaction": {
                "pointer_position": [1182, 674],
                "hovered": {"action": "BAG_SLOT", "offer_id": "", "control": "Bag_Slot8"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        formal = json.loads(json.dumps(art))
        formal["interaction"]["hovered"]["control"] = "BagSlotButton_7"
        summary = MODULE.interaction_summary("07d_empty_bag_eighth_slot_hover", art, formal)
        self.assertEqual(summary["pointer_position"], [1182, 674])
        self.assertEqual(summary["hovered"], {"action": "BAG_SLOT", "offer_id": ""})

    def test_mixed_bag_keeps_the_far_empty_slot_interactive(self) -> None:
        art = {
            "interaction": {
                "pointer_position": [1182, 674],
                "hovered": {"action": "BAG_SLOT", "offer_id": "", "control": "Bag_Slot8"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        formal = json.loads(json.dumps(art))
        formal["interaction"]["hovered"]["control"] = "BagSlotButton_7"
        summary = MODULE.interaction_summary("15b_bag_pet_eighth_empty_slot_hover", art, formal)
        self.assertEqual(summary["pointer_position"], [1182, 674])
        self.assertEqual(summary["hovered"], {"action": "BAG_SLOT", "offer_id": ""})

    def test_mixed_bag_hover_clears_at_the_neutral_pointer(self) -> None:
        interaction = {
            "interaction": {
                "pointer_position": [1850, 1030],
                "hovered": {"action": "none", "offer_id": "", "control": ""},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        summary = MODULE.interaction_summary(
            "15c_bag_hover_cleared",
            interaction,
            json.loads(json.dumps(interaction)),
        )
        self.assertEqual(summary["pointer_position"], [1850, 1030])
        self.assertEqual(summary["hovered"], {"action": "none", "offer_id": ""})

    def test_occupied_bag_slot_click_keeps_the_slot_identity(self) -> None:
        art = {
            "interaction": {
                "pointer_position": [628, 496],
                "hovered": {"action": "BAG_SLOT", "offer_id": "", "control": "Bag_Slot"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        formal = json.loads(json.dumps(art))
        formal["interaction"]["hovered"]["control"] = "BagSlotButton_0"
        summary = MODULE.interaction_summary("15d_bag_pet_click", art, formal)
        self.assertEqual(summary["pointer_position"], [628, 496])
        self.assertEqual(summary["hovered"], {"action": "BAG_SLOT", "offer_id": ""})

    def test_full_party_tail_slots_have_independent_pointer_gates(self) -> None:
        for name, pointer in (
            ("10b_party_third_hover", [996, 878]),
            ("10b2_party_third_click", [996, 878]),
            ("10c_party_fourth_hover", [1176, 878]),
            ("10c2_party_fourth_click", [1176, 878]),
        ):
            interaction = {
                "interaction": {
                    "pointer_position": pointer,
                    "hovered": {"action": "PARTY_SLOT", "offer_id": "", "control": name},
                    "focused": {"action": "none", "offer_id": "", "control": ""},
                }
            }
            summary = MODULE.interaction_summary(
                name,
                interaction,
                json.loads(json.dumps(interaction)),
            )
            self.assertEqual(summary["pointer_position"], pointer)
            self.assertEqual(summary["hovered"], {"action": "PARTY_SLOT", "offer_id": ""})

    def test_entry_offer_tail_slots_have_independent_pointer_and_identity_gates(self) -> None:
        for name, pointer, offer_id in (
            ("02_entry_second_offer_hover", [902, 454], "shop_002"),
            ("02_entry_third_offer_hover", [1228, 470], "shop_003"),
        ):
            interaction = {
                "interaction": {
                    "pointer_position": pointer,
                    "hovered": {"action": "BUY_OFFER", "offer_id": offer_id, "control": name},
                    "focused": {"action": "none", "offer_id": "", "control": ""},
                }
            }
            summary = MODULE.interaction_summary(
                name,
                interaction,
                json.loads(json.dumps(interaction)),
            )
            self.assertEqual(summary["pointer_position"], pointer)
            self.assertEqual(summary["hovered"], {"action": "BUY_OFFER", "offer_id": offer_id})

    def test_entry_empty_slots_have_no_stale_purchase_identity(self) -> None:
        for name, pointer, art_control in (
            ("02c_entry_fourth_empty_slot_hover", [578, 704], "Offer04"),
            ("02d_entry_fifth_empty_slot_hover", [1228, 704], "Offer05"),
        ):
            art = {
                "interaction": {
                    "pointer_position": pointer,
                    "hovered": {"action": "none", "offer_id": "", "control": art_control},
                    "focused": {"action": "none", "offer_id": "", "control": ""},
                }
            }
            formal = json.loads(json.dumps(art))
            formal["interaction"]["hovered"]["control"] = ""
            summary = MODULE.interaction_summary(name, art, formal)
            self.assertEqual(summary["pointer_position"], pointer)
            self.assertEqual(summary["hovered"], {"action": "none", "offer_id": ""})
            self.assertEqual(summary["art_controls"]["hovered"], art_control)
            self.assertEqual(summary["formal_controls"]["hovered"], "")

    def test_fourth_empty_slot_click_remains_a_no_op(self) -> None:
        art = {
            "interaction": {
                "pointer_position": [578, 704],
                "hovered": {"action": "none", "offer_id": "", "control": "Offer04"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        formal = json.loads(json.dumps(art))
        formal["interaction"]["hovered"]["control"] = ""
        summary = MODULE.interaction_summary("02c2_entry_fourth_empty_slot_click", art, formal)
        self.assertEqual(summary["pointer_position"], [578, 704])
        self.assertEqual(summary["hovered"], {"action": "none", "offer_id": ""})
        self.assertIn(
            ("02c2_entry_fourth_empty_slot_click", "点击入口第四个空货孔"),
            MODULE.OPERATIONS,
        )

    def test_fifth_empty_slot_click_remains_a_no_op(self) -> None:
        art = {
            "interaction": {
                "pointer_position": [1228, 704],
                "hovered": {"action": "none", "offer_id": "", "control": "Offer05"},
                "focused": {"action": "none", "offer_id": "", "control": ""},
            }
        }
        formal = json.loads(json.dumps(art))
        formal["interaction"]["hovered"]["control"] = ""
        summary = MODULE.interaction_summary("02d2_entry_fifth_empty_slot_click", art, formal)
        self.assertEqual(summary["pointer_position"], [1228, 704])
        self.assertEqual(summary["hovered"], {"action": "none", "offer_id": ""})
        self.assertIn(
            ("02d2_entry_fifth_empty_slot_click", "点击入口第五个空货孔"),
            MODULE.OPERATIONS,
        )

    def test_paid_refresh_offers_have_independent_pointer_and_identity_gates(self) -> None:
        for name, pointer, offer_id in (
            ("12a_paid_refresh_first_offer_hover", [578, 454], "shop_001"),
            ("12b_paid_refresh_second_offer_hover", [902, 454], "shop_002"),
            ("12c_paid_refresh_third_offer_hover", [1228, 470], "shop_003"),
        ):
            interaction = {
                "interaction": {
                    "pointer_position": pointer,
                    "hovered": {"action": "BUY_OFFER", "offer_id": offer_id, "control": name},
                    "focused": {"action": "none", "offer_id": "", "control": ""},
                }
            }
            summary = MODULE.interaction_summary(name, interaction, json.loads(json.dumps(interaction)))
            self.assertEqual(summary["pointer_position"], pointer)
            self.assertEqual(summary["hovered"], {"action": "BUY_OFFER", "offer_id": offer_id})

    def test_free_refresh_offers_have_independent_pointer_and_identity_gates(self) -> None:
        for name, pointer, offer_id in (
            ("04a_refresh_first_offer_hover", [578, 454], "shop_001"),
            ("04b_refresh_second_offer_hover", [902, 454], "shop_002"),
            ("04c_refresh_third_offer_hover", [1228, 470], "shop_003"),
        ):
            interaction = {
                "interaction": {
                    "pointer_position": pointer,
                    "hovered": {"action": "BUY_OFFER", "offer_id": offer_id, "control": name},
                    "focused": {"action": "none", "offer_id": "", "control": ""},
                }
            }
            summary = MODULE.interaction_summary(name, interaction, json.loads(json.dumps(interaction)))
            self.assertEqual(summary["pointer_position"], pointer)
            self.assertEqual(summary["hovered"], {"action": "BUY_OFFER", "offer_id": offer_id})

    def test_mismatching_interaction_stops_comparison(self) -> None:
        art = {
            "interaction": {
                "pointer_position": [578, 454],
                "hovered": {"action": "BUY_OFFER", "offer_id": "shop_001"},
                "focused": {"action": "none", "offer_id": ""},
            }
        }
        formal = json.loads(json.dumps(art))
        formal["interaction"]["pointer_position"] = [579, 454]
        with self.assertRaisesRegex(SystemExit, "capture interaction mismatch for 02_offer_hover"):
            MODULE.interaction_summary("02_offer_hover", art, formal)

    def test_mismatching_state_stops_comparison(self) -> None:
        art = {
            "phase": "route",
            "coins": 14,
            "offer_count": 3,
            "roster_count": 2,
            "state_version": 4,
            "state_hash": "wrong",
        }
        formal = {
            "phase": "route",
            "coins": 14,
            "offer_count": 3,
            "roster_count": 2,
            "state_version": 4,
            "state_hash": "1b70deda932ac7b5",
        }
        with self.assertRaisesRegex(SystemExit, "capture state mismatch for 18_exit_to_route"):
            MODULE.parity_summary("18_exit_to_route", art, formal)

    def test_capture_manifest_requires_every_state_field(self) -> None:
        captures = [
            {
                "name": name,
                "phase": "shop",
                "coins": 16,
                "offer_count": 3,
                "interaction": {},
            }
            for name, _operation in MODULE.OPERATIONS
        ]
        with tempfile.TemporaryDirectory() as directory:
            manifest_path = Path(directory) / "capture_manifest.json"
            manifest_path.write_text(
                json.dumps({"side": "art_package", "passed": True, "captures": captures}),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(SystemExit, "capture state fields missing"):
                MODULE.capture_records(Path(directory), "art_package")


if __name__ == "__main__":
    unittest.main()
