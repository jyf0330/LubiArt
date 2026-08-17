#!/usr/bin/env python3
"""Build one art-package/formal-project comparison image per shop operation."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


OPERATIONS = (
    ("01_shop_entry", "进入基础商店"),
    ("01b_entry_second_empty_party_slot_hover", "悬停入口第二个空队伍槽"),
    ("01b2_entry_second_empty_party_slot_click", "点击入口第二个空队伍槽"),
    ("01c_entry_fourth_empty_party_slot_hover", "悬停入口第四个空队伍槽"),
    ("01c2_entry_fourth_empty_party_slot_click", "点击入口第四个空队伍槽"),
    ("01d_entry_third_empty_party_slot_hover", "悬停入口第三个空队伍槽"),
    ("01d2_entry_third_empty_party_slot_click", "点击入口第三个空队伍槽"),
    ("01e_entry_coin_panel_hover", "悬停金币牌安全区"),
    ("01e2_entry_coin_panel_click", "点击金币牌安全区"),
    ("01f_entry_coin_exit_overlap_hover", "悬停金币牌与退出牌交叠边缘"),
    ("01f2_entry_coin_exit_overlap_click", "点击金币牌与退出牌交叠边缘"),
    ("01g_entry_exit_transparent_gap_hover", "悬停退出牌透明空隙"),
    ("01g2_entry_exit_transparent_gap_click", "点击退出牌透明空隙"),
    ("02_offer_hover", "悬停第一件商品"),
    ("02a_entry_first_offer_pressed", "按下第一件商品但尚未松开"),
    ("02_entry_second_offer_hover", "悬停入口第二件商品"),
    ("02a2_entry_second_offer_pressed", "按下第二件商品但尚未松开"),
    ("02_entry_third_offer_hover", "悬停入口第三件商品"),
    ("02a3_entry_third_offer_pressed", "按下第三件商品但尚未松开"),
    ("02c_entry_fourth_empty_slot_hover", "指针移入入口第四个空货孔"),
    ("02c2_entry_fourth_empty_slot_click", "点击入口第四个空货孔"),
    ("02d_entry_fifth_empty_slot_hover", "指针移入入口第五个空货孔"),
    ("02d2_entry_fifth_empty_slot_click", "点击入口第五个空货孔"),
    ("02b_refresh_hover", "悬停刷新铃但不点击"),
    ("02b2_refresh_pressed", "按下刷新铃但尚未松开"),
    ("03_refresh_curtain", "点击刷新：红帘过程"),
    ("04_refresh_complete", "刷新动画完成"),
    ("04a_refresh_first_offer_hover", "悬停首次刷新后的第一件商品"),
    ("04b_refresh_second_offer_hover", "悬停首次刷新后的第二件商品"),
    ("04c_refresh_third_offer_hover", "悬停首次刷新后的第三件商品"),
    ("05_purchase_complete", "购买第一件商品完成"),
    ("06_party_hover", "悬停第一名队伍宠物"),
    ("06a_party_first_click", "点击第一名队伍宠物"),
    ("06b_party_second_hover", "悬停第二名队伍宠物"),
    ("06c_party_second_click", "点击第二名队伍宠物"),
    ("06d_bag_closed_hover", "悬停关闭态宝箱"),
    ("06d2_bag_closed_pressed", "按下关闭态宝箱但尚未松开"),
    ("07_bag_open", "点击宝箱打开背包"),
    ("07a_bag_open_hover_cleared", "鼠标移出打开态宝箱"),
    ("07a2_bag_open_hover", "重新悬停打开态宝箱"),
    ("07a3_bag_open_pressed", "按下打开态宝箱但尚未松开"),
    ("07b_empty_bag_slot_hover", "悬停空背包第一槽"),
    ("07c_empty_bag_slot_click", "点击空背包第一槽"),
    ("07d_empty_bag_eighth_slot_hover", "悬停空背包第八槽"),
    ("08_bag_closed", "再次点击宝箱关闭背包"),
    ("09_second_purchase", "购买第二件商品完成"),
    ("10_party_full_purchase", "购买第三件商品填满队伍"),
    ("10b_party_third_hover", "悬停第三名队伍宠物"),
    ("10b2_party_third_click", "点击第三名队伍宠物"),
    ("10c_party_fourth_hover", "悬停第四名队伍宠物"),
    ("10c2_party_fourth_click", "点击第四名队伍宠物"),
    ("10d_paid_refresh_hover", "悬停付费刷新铃但不点击"),
    ("10d2_paid_refresh_pressed", "按下付费刷新铃但尚未松开"),
    ("11_paid_refresh_curtain", "点击付费刷新：红帘过程"),
    ("12_paid_refresh_complete", "付费刷新动画完成"),
    ("12a_paid_refresh_first_offer_hover", "悬停付费刷新后的第一件商品"),
    ("12b_paid_refresh_second_offer_hover", "悬停付费刷新后的第二件商品"),
    ("12c_paid_refresh_third_offer_hover", "悬停付费刷新后的第三件商品"),
    ("13_bag_pet_purchase", "购买第五只宠物进入背包"),
    ("14_bag_with_pet_open", "打开已有宠物的背包"),
    ("15_bag_pet_hover", "悬停背包第一只宠物"),
    ("15b_bag_pet_eighth_empty_slot_hover", "已有宠物时悬停背包第八空槽"),
    ("15c_bag_hover_cleared", "移出背包清除槽高亮"),
    ("15d_bag_pet_click", "点击背包第一只宠物"),
    ("16_bag_with_pet_closed", "关闭已有宠物的背包"),
    ("17_exit_hover", "悬停商店退出牌"),
    ("17b_exit_pressed", "按下退出牌但尚未松开"),
    ("17b2_exit_pressed_pointer_outside", "按住退出牌并移出"),
    ("17b3_exit_pressed_pointer_reentered", "按住退出牌移出后重新移入"),
    ("17b4_exit_pressed_pointer_outside_again", "按住退出牌重新移出但尚未松开"),
    ("17c_exit_press_cancelled", "移出退出牌并松开取消"),
    ("17d_exit_repressed_after_cancel", "取消后再次按住退出牌"),
    ("17e_exit_repressed_pointer_outside", "取消后再次按住退出牌并移出"),
    ("17f_exit_repressed_pointer_reentered", "取消后再次按住移出后重新移入"),
    ("18_exit_to_route", "退出商店返回路线"),
    ("19_reenter_shop_after_exit", "退出后重新进入商店"),
    ("19a_reentered_second_offer_hover", "重进商店后悬停第二件商品"),
    ("19b_reentered_second_offer_pressed", "重进商店后按下第二件商品但尚未松开"),
    ("19c_reentered_second_offer_press_cancelled", "重进商店后移出并松开取消第二件商品"),
    ("19d_reentered_second_offer_rehover_after_cancel", "取消后重新悬停重进商店第二件商品"),
    ("19e_reentered_second_offer_repressed_after_cancel", "取消后重新悬停并再次按住重进商店第二件商品"),
    ("19f_reentered_second_offer_repressed_pointer_outside", "取消后再次按住重进商店第二件商品并移出"),
    ("19g_reentered_second_offer_repressed_pointer_reentered", "取消后再次按住移出并重新移入重进商店第二件商品"),
    ("19h_reentered_second_offer_repressed_pointer_outside_again", "取消后再次按住移出重新移入后再次移出重进商店第二件商品"),
    ("19i_reentered_second_offer_repress_cancelled_after_reentry_cycle", "再次按住移出重新移入再移出后松开取消重进商店第二件商品"),
    ("19j_reentered_second_offer_rehover_after_repress_cycle_cancel", "第二次按压往返取消后重新悬停重进商店第二件商品"),
)
ACCEPTANCE_OPERATION_NAMES = (
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
)
ACCEPTANCE_OPERATIONS = tuple(
    operation for operation in OPERATIONS if operation[0] in ACCEPTANCE_OPERATION_NAMES
)
STATE_ONLY_VISUAL_OPERATIONS = {"18_exit_to_route"}
STATE_FIELDS = (
    "phase",
    "coins",
    "offer_count",
    "roster_count",
    "state_version",
    "state_hash",
)
EXPECTED_INTERACTIONS = {
    "01_shop_entry": ([1850, 1030], "none", ""),
    "01b_entry_second_empty_party_slot_hover": ([820, 878], "none", ""),
    "01b2_entry_second_empty_party_slot_click": ([820, 878], "none", ""),
    "01c_entry_fourth_empty_party_slot_hover": ([1176, 878], "none", ""),
    "01c2_entry_fourth_empty_party_slot_click": ([1176, 878], "none", ""),
    "01d_entry_third_empty_party_slot_hover": ([996, 878], "none", ""),
    "01d2_entry_third_empty_party_slot_click": ([996, 878], "none", ""),
    "01e_entry_coin_panel_hover": ([1388, 930], "none", ""),
    "01e2_entry_coin_panel_click": ([1388, 930], "none", ""),
    "01f_entry_coin_exit_overlap_hover": ([1412, 930], "none", ""),
    "01f2_entry_coin_exit_overlap_click": ([1412, 930], "none", ""),
    "01g_entry_exit_transparent_gap_hover": ([1544, 500], "none", ""),
    "01g2_entry_exit_transparent_gap_click": ([1544, 500], "none", ""),
    "02_offer_hover": ([578, 454], "BUY_OFFER", "shop_001"),
    "02a_entry_first_offer_pressed": ([578, 454], "BUY_OFFER", "shop_001", "BUY_OFFER", "shop_001"),
    "02_entry_second_offer_hover": ([902, 454], "BUY_OFFER", "shop_002"),
    "02a2_entry_second_offer_pressed": ([902, 454], "BUY_OFFER", "shop_002", "BUY_OFFER", "shop_002"),
    "02_entry_third_offer_hover": ([1228, 470], "BUY_OFFER", "shop_003"),
    "02a3_entry_third_offer_pressed": ([1228, 470], "BUY_OFFER", "shop_003", "BUY_OFFER", "shop_003"),
    "02c_entry_fourth_empty_slot_hover": ([578, 704], "none", ""),
    "02c2_entry_fourth_empty_slot_click": ([578, 704], "none", ""),
    "02d_entry_fifth_empty_slot_hover": ([1228, 704], "none", ""),
    "02d2_entry_fifth_empty_slot_click": ([1228, 704], "none", ""),
    "02b_refresh_hover": ([988, 754], "ROLL_SHOP", ""),
    "02b2_refresh_pressed": ([988, 754], "ROLL_SHOP", "", "ROLL_SHOP"),
    "03_refresh_curtain": ([988, 754], "ROLL_SHOP", ""),
    "04_refresh_complete": ([988, 754], "ROLL_SHOP", ""),
    "04a_refresh_first_offer_hover": ([578, 454], "BUY_OFFER", "shop_001"),
    "04b_refresh_second_offer_hover": ([902, 454], "BUY_OFFER", "shop_002"),
    "04c_refresh_third_offer_hover": ([1228, 470], "BUY_OFFER", "shop_003"),
    "05_purchase_complete": ([1850, 1030], "none", ""),
    "06_party_hover": ([642, 878], "PARTY_SLOT", ""),
    "06a_party_first_click": ([642, 878], "PARTY_SLOT", ""),
    "06b_party_second_hover": ([820, 878], "PARTY_SLOT", ""),
    "06c_party_second_click": ([820, 878], "PARTY_SLOT", ""),
    "06d_bag_closed_hover": ([430, 892], "TOGGLE_BAG", ""),
    "06d2_bag_closed_pressed": ([430, 892], "TOGGLE_BAG", "", "TOGGLE_BAG"),
    "07_bag_open": ([430, 892], "TOGGLE_BAG", ""),
    "07a_bag_open_hover_cleared": ([1850, 1030], "none", ""),
    "07a2_bag_open_hover": ([430, 892], "TOGGLE_BAG", ""),
    "07a3_bag_open_pressed": ([430, 892], "TOGGLE_BAG", "", "TOGGLE_BAG"),
    "07b_empty_bag_slot_hover": ([628, 496], "BAG_SLOT", ""),
    "07c_empty_bag_slot_click": ([628, 496], "BAG_SLOT", ""),
    "07d_empty_bag_eighth_slot_hover": ([1182, 674], "BAG_SLOT", ""),
    "08_bag_closed": ([430, 892], "TOGGLE_BAG", ""),
    "09_second_purchase": ([1850, 1030], "none", ""),
    "10_party_full_purchase": ([1850, 1030], "none", ""),
    "10b_party_third_hover": ([996, 878], "PARTY_SLOT", ""),
    "10b2_party_third_click": ([996, 878], "PARTY_SLOT", ""),
    "10c_party_fourth_hover": ([1176, 878], "PARTY_SLOT", ""),
    "10c2_party_fourth_click": ([1176, 878], "PARTY_SLOT", ""),
    "10d_paid_refresh_hover": ([988, 754], "ROLL_SHOP", ""),
    "10d2_paid_refresh_pressed": ([988, 754], "ROLL_SHOP", "", "ROLL_SHOP"),
    "11_paid_refresh_curtain": ([988, 754], "ROLL_SHOP", ""),
    "12_paid_refresh_complete": ([988, 754], "ROLL_SHOP", ""),
    "12a_paid_refresh_first_offer_hover": ([578, 454], "BUY_OFFER", "shop_001"),
    "12b_paid_refresh_second_offer_hover": ([902, 454], "BUY_OFFER", "shop_002"),
    "12c_paid_refresh_third_offer_hover": ([1228, 470], "BUY_OFFER", "shop_003"),
    "13_bag_pet_purchase": ([1850, 1030], "none", ""),
    "14_bag_with_pet_open": ([430, 892], "TOGGLE_BAG", ""),
    "15_bag_pet_hover": ([628, 496], "BAG_SLOT", ""),
    "15b_bag_pet_eighth_empty_slot_hover": ([1182, 674], "BAG_SLOT", ""),
    "15c_bag_hover_cleared": ([1850, 1030], "none", ""),
    "15d_bag_pet_click": ([628, 496], "BAG_SLOT", ""),
    "16_bag_with_pet_closed": ([430, 892], "TOGGLE_BAG", ""),
    "17_exit_hover": ([1544, 726], "EXIT_SHOP", ""),
    "17b_exit_pressed": ([1544, 726], "EXIT_SHOP", "", "EXIT_SHOP"),
    "17b2_exit_pressed_pointer_outside": ([1850, 1030], "none", "", "EXIT_SHOP"),
    "17b3_exit_pressed_pointer_reentered": ([1544, 726], "EXIT_SHOP", "", "EXIT_SHOP"),
    "17b4_exit_pressed_pointer_outside_again": ([1850, 1030], "none", "", "EXIT_SHOP"),
    "17c_exit_press_cancelled": ([1850, 1030], "none", ""),
    "17d_exit_repressed_after_cancel": ([1544, 726], "EXIT_SHOP", "", "EXIT_SHOP"),
    "17e_exit_repressed_pointer_outside": ([1850, 1030], "none", "", "EXIT_SHOP"),
    "17f_exit_repressed_pointer_reentered": ([1544, 726], "EXIT_SHOP", "", "EXIT_SHOP"),
    "18_exit_to_route": ([1544, 726], "none", ""),
    "19_reenter_shop_after_exit": ([1850, 1030], "none", ""),
    "19a_reentered_second_offer_hover": ([902, 454], "BUY_OFFER", "shop_002"),
    "19b_reentered_second_offer_pressed": ([902, 454], "BUY_OFFER", "shop_002", "BUY_OFFER", "shop_002"),
    "19c_reentered_second_offer_press_cancelled": ([1850, 1030], "none", ""),
    "19d_reentered_second_offer_rehover_after_cancel": ([902, 454], "BUY_OFFER", "shop_002"),
    "19e_reentered_second_offer_repressed_after_cancel": ([902, 454], "BUY_OFFER", "shop_002", "BUY_OFFER", "shop_002"),
    "19f_reentered_second_offer_repressed_pointer_outside": ([1850, 1030], "none", "", "BUY_OFFER", "shop_002"),
    "19g_reentered_second_offer_repressed_pointer_reentered": ([902, 454], "BUY_OFFER", "shop_002", "BUY_OFFER", "shop_002"),
    "19h_reentered_second_offer_repressed_pointer_outside_again": ([1850, 1030], "none", "", "BUY_OFFER", "shop_002"),
    "19i_reentered_second_offer_repress_cancelled_after_reentry_cycle": ([1850, 1030], "none", ""),
    "19j_reentered_second_offer_rehover_after_repress_cycle_cancel": ([902, 454], "BUY_OFFER", "shop_002"),
}
FONT_CANDIDATES = (
    Path("/System/Library/Fonts/PingFang.ttc"),
    Path("/System/Library/Fonts/Supplemental/Arial Unicode.ttf"),
)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for candidate in FONT_CANDIDATES:
        if candidate.is_file():
            return ImageFont.truetype(str(candidate), size=size)
    return ImageFont.load_default()


def capture_records(
    directory: Path,
    expected_side: str,
    expected_operations: tuple[tuple[str, str], ...] = OPERATIONS,
) -> dict[str, dict]:
    path = directory / "capture_manifest.json"
    if not path.is_file():
        raise SystemExit(f"missing capture manifest: {path}")
    manifest = json.loads(path.read_text(encoding="utf-8"))
    if not manifest.get("passed", False):
        raise SystemExit(f"capture manifest is not passing: {path}")
    if manifest.get("side") != expected_side:
        raise SystemExit(
            f"capture side mismatch for {path}: {manifest.get('side')!r} != {expected_side!r}"
        )
    records = {str(record.get("name", "")): record for record in manifest.get("captures", [])}
    expected_names = {name for name, _operation in expected_operations}
    if set(records) != expected_names:
        raise SystemExit(
            f"capture names mismatch for {path}: {sorted(records)} != {sorted(expected_names)}"
        )
    for name, record in records.items():
        missing_fields = [field for field in STATE_FIELDS if field not in record]
        if missing_fields:
            raise SystemExit(f"capture state fields missing for {name} in {path}: {missing_fields}")
        if not isinstance(record.get("interaction"), dict):
            raise SystemExit(f"capture interaction missing for {name} in {path}")
    return records


def parity_summary(name: str, art: dict, formal: dict) -> dict:
    mismatches = {
        field: {"art": art.get(field), "formal": formal.get(field)}
        for field in STATE_FIELDS
        if art.get(field) != formal.get(field)
    }
    if mismatches:
        raise SystemExit(f"capture state mismatch for {name}: {json.dumps(mismatches, ensure_ascii=False)}")
    return {field: art.get(field) for field in STATE_FIELDS}


def _semantic_control(value: object) -> dict[str, str]:
    control = value if isinstance(value, dict) else {}
    return {
        "action": str(control.get("action", "")),
        "offer_id": str(control.get("offer_id", "")),
    }


def interaction_summary(name: str, art: dict, formal: dict) -> dict:
    art_interaction = art.get("interaction", {})
    formal_interaction = formal.get("interaction", {})
    art_pointer = list(art_interaction.get("pointer_position", []))
    formal_pointer = list(formal_interaction.get("pointer_position", []))
    art_hovered = _semantic_control(art_interaction.get("hovered"))
    formal_hovered = _semantic_control(formal_interaction.get("hovered"))
    art_focused = _semantic_control(art_interaction.get("focused"))
    formal_focused = _semantic_control(formal_interaction.get("focused"))
    expected = EXPECTED_INTERACTIONS[name]
    expected_pointer, expected_action, expected_offer_id = expected[:3]
    expected_focus_action = expected[3] if len(expected) > 3 else "none"
    expected_focus_offer_id = expected[4] if len(expected) > 4 else ""
    mismatches = {
        "pointer": [art_pointer, formal_pointer, expected_pointer],
        "hovered": [art_hovered, formal_hovered, {"action": expected_action, "offer_id": expected_offer_id}],
        "focused": [art_focused, formal_focused, {"action": expected_focus_action, "offer_id": expected_focus_offer_id}],
    }
    if (
        art_pointer != formal_pointer
        or art_pointer != expected_pointer
        or art_hovered != formal_hovered
        or art_hovered != {"action": expected_action, "offer_id": expected_offer_id}
        or art_focused != formal_focused
        or art_focused != {"action": expected_focus_action, "offer_id": expected_focus_offer_id}
    ):
        raise SystemExit(
            f"capture interaction mismatch for {name}: "
            f"{json.dumps(mismatches, ensure_ascii=False)}"
        )
    return {
        "pointer_position": art_pointer,
        "hovered": art_hovered,
        "focused": art_focused,
        "art_controls": {
            "hovered": str(art_interaction.get("hovered", {}).get("control", "")),
            "focused": str(art_interaction.get("focused", {}).get("control", "")),
        },
        "formal_controls": {
            "hovered": str(formal_interaction.get("hovered", {}).get("control", "")),
            "focused": str(formal_interaction.get("focused", {}).get("control", "")),
        },
    }


def state_label(state: dict) -> str:
    return (
        f"状态：{state.get('phase', '')} · 金币 {state.get('coins', 0)} · "
        f"商品 {state.get('offer_count', 0)} · 队伍 {state.get('roster_count', 0)} · "
        f"v{state.get('state_version', -1)} · {state.get('state_hash', '')}"
    )


def interaction_label(interaction: dict) -> str:
    pointer = interaction.get("pointer_position", [0, 0])
    hovered = interaction.get("hovered", {})
    focused = interaction.get("focused", {})
    hovered_value = str(hovered.get("action", "none"))
    if hovered.get("offer_id"):
        hovered_value += "/" + str(hovered["offer_id"])
    return (
        f"交互：鼠标 ({pointer[0]},{pointer[1]}) · 悬停 {hovered_value} · "
        f"焦点 {focused.get('action', 'none')}"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--art-dir", type=Path, required=True)
    parser.add_argument("--formal-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument(
        "--diagnostic-full",
        action="store_true",
        help="build the historical exhaustive micro-interaction matrix instead of the 14-image acceptance set",
    )
    args = parser.parse_args()
    selected_operations = OPERATIONS if args.diagnostic_full else ACCEPTANCE_OPERATIONS
    art_captures = capture_records(args.art_dir, "art_package", selected_operations)
    formal_captures = capture_records(args.formal_dir, "formal_project", selected_operations)
    state_parity = {
        name: parity_summary(name, art_captures[name], formal_captures[name])
        for name, _operation in selected_operations
    }
    interaction_parity = {
        name: interaction_summary(name, art_captures[name], formal_captures[name])
        for name, _operation in selected_operations
    }
    args.output_dir.mkdir(parents=True, exist_ok=True)
    title_font = font(30)
    label_font = font(24)
    records = []
    for name, operation in selected_operations:
        art_path = args.art_dir / f"{name}.png"
        formal_path = args.formal_dir / f"{name}.png"
        if not art_path.is_file() or not formal_path.is_file():
            raise SystemExit(f"missing comparison input for {name}")
        with Image.open(art_path) as art_source, Image.open(formal_path) as formal_source:
            art = art_source.convert("RGB")
            formal = formal_source.convert("RGB")
        if art.size != (1920, 1080) or formal.size != (1920, 1080):
            raise SystemExit(f"{name} must be 1920x1080 on both sides: {art.size} / {formal.size}")
        header = 164
        canvas = Image.new("RGB", (3840, 1080 + header), (19, 22, 24))
        canvas.paste(art, (0, header))
        canvas.paste(formal, (1920, header))
        draw = ImageDraw.Draw(canvas)
        draw.rectangle((0, 0, 3839, header - 1), fill=(20, 24, 27))
        draw.line((1919, 0, 1919, 1080 + header - 1), fill=(250, 208, 128), width=3)
        draw.text((24, 14), f"操作：{operation}", font=title_font, fill=(248, 224, 177))
        if name in STATE_ONLY_VISUAL_OPERATIONS:
            draw.text((24, 54), "左：美术包独立路线（本步只核对状态/交互）", font=label_font, fill=(220, 230, 224))
            draw.text((1944, 54), "右：正式项目独立路线（不声明视觉一致）", font=label_font, fill=(220, 230, 224))
        else:
            draw.text((24, 54), "左：美术包独立项目（同步正式展示数据后）", font=label_font, fill=(220, 230, 224))
            draw.text((1944, 54), "右：正式项目同一步操作", font=label_font, fill=(220, 230, 224))
        draw.text((24, 90), state_label(state_parity[name]), font=label_font, fill=(164, 218, 191))
        draw.text((24, 126), interaction_label(interaction_parity[name]), font=label_font, fill=(155, 196, 232))
        output = args.output_dir / f"{name}_art_vs_formal.png"
        canvas.save(output, optimize=True)
        records.append({
            "name": name,
            "operation": operation,
            "file": output.name,
            "art_source": art_path.name,
            "art_sha256": digest(art_path),
            "formal_source": formal_path.name,
            "formal_sha256": digest(formal_path),
            "comparison_sha256": digest(output),
            "layout": "art_package_left_formal_project_right",
            "visual_scope": (
                "state_and_interaction_only_adjacent_route"
                if name in STATE_ONLY_VISUAL_OPERATIONS
                else "shop_art_visual_parity"
            ),
            "size": [3840, 1244],
            "state_parity": state_parity[name],
            "interaction_parity": interaction_parity[name],
        })
    manifest = {
        "schema": "ysbzs.shop-operation-comparison.v1",
        "comparison_rule": "one_operation_one_image",
        "profile": "diagnostic_full" if args.diagnostic_full else "fixed_seed_acceptance_14",
        "left": "art_package_runtime_after_formal_reference_sync",
        "right": "formal_project_runtime",
        "copied_mock_code": False,
        "state_fields_checked": list(STATE_FIELDS),
        "interaction_fields_checked": ["pointer_position", "hovered.action", "hovered.offer_id", "focused.action"],
        "comparisons": records,
    }
    (args.output_dir / "comparison_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"SHOP_OPERATION_COMPARISON_OK pairs={len(records)} output={args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
