#!/usr/bin/env python3
import argparse
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from psd_extract_layers import decode_channel, parse_psd  # noqa: E402


OUT_DIR = ROOT / "outputs" / "three_choice_godot_psd_min_nodes_v1"
EXPORT_DIR = OUT_DIR / "exports"
PSD_LAYER_DIR = OUT_DIR / "psd_layers"
PSD_NAME = "screen_three_choice_godot_min_nodes_v1.psd"


UNITS = [
    {
        "name": "background",
        "category": "MERGE_TEXTURE",
        "layers": [5],
        "target_node": "Background",
        "purpose": "full screen static background",
    },
    {
        "name": "temple_base",
        "category": "MERGE_TEXTURE",
        "layers": [14, 15, 16, 51],
        "target_node": "TempleBase",
        "purpose": "static temple base with shared shadow merged into one render unit",
    },
    {
        "name": "route_card_shop_static",
        "category": "COMPONENT",
        "layers": [20, 37, 62, 64],
        "target_node": "RouteCard1/StaticArt",
        "purpose": "fixed shop card art merged from icon, portrait, incense, and smoke",
    },
    {
        "name": "route_card_event_static",
        "category": "COMPONENT",
        "layers": [24, 38, 61, 65],
        "target_node": "RouteCard2/StaticArt",
        "purpose": "fixed event card art merged from icon, portrait, incense, and smoke",
    },
    {
        "name": "route_card_reward_static",
        "category": "COMPONENT",
        "layers": [28, 34, 60, 66],
        "target_node": "RouteCard3/StaticArt",
        "purpose": "fixed reward card art merged from icon, portrait, incense, and smoke",
    },
    {
        "name": "route_highlight_shop",
        "category": "STATE_RESOURCE",
        "layers": [48],
        "target_node": "ChoiceShop/HoverState",
        "purpose": "hover or selected state texture",
        "visible": False,
    },
    {
        "name": "route_highlight_event",
        "category": "STATE_RESOURCE",
        "layers": [47],
        "target_node": "ChoiceEvent/HoverState",
        "purpose": "hover or selected state texture",
        "visible": False,
    },
    {
        "name": "route_highlight_reward",
        "category": "STATE_RESOURCE",
        "layers": [46],
        "target_node": "ChoiceReward/HoverState",
        "purpose": "hover or selected state texture",
        "visible": False,
    },
    {
        "name": "party_and_item_bar_base",
        "category": "MERGE_TEXTURE",
        "layers": [70, 77, 121, 122],
        "target_node": "StageHost/BottomBase",
        "purpose": "static party shelf, shelf shadow, item bar, and item slots merged into one render unit",
    },
    {
        "name": "top_hud_static",
        "category": "MERGE_TEXTURE",
        "layers": [84, 131, 132, 133, 134, 135, 139, 140],
        "target_node": "TopHud/StaticArt",
        "purpose": "static top frame, time dial, buttons, and coin icon merged into one render unit",
    },
    {
        "name": "bag_open_full",
        "category": "STATE_RESOURCE",
        "layers": [89, 90, 91],
        "target_node": "Bag/OpenState",
        "purpose": "bag open, foreground cover, and grid lines merged into one button state texture",
    },
    {
        "name": "bag_closed",
        "category": "STATE_RESOURCE",
        "layers": [88],
        "target_node": "Bag/ClosedState",
        "purpose": "bag closed state texture",
        "visible": False,
    },
    {
        "name": "bag_slot_empty",
        "category": "STATE_RESOURCE",
        "layers": [101],
        "target_node": "BagSlot/Empty",
        "purpose": "single repeated slot state resource",
    },
    {
        "name": "bag_slot_glow",
        "category": "STATE_RESOURCE",
        "layers": [102],
        "target_node": "BagSlot/Hover",
        "purpose": "single repeated slot hover resource",
        "visible": False,
    },
    {
        "name": "item_sell_highlight",
        "category": "STATE_RESOURCE",
        "layers": [123],
        "target_node": "ItemBar/SellHighlight",
        "purpose": "sell state highlight",
        "visible": False,
    },
    {
        "name": "item_selected_highlight",
        "category": "STATE_RESOURCE",
        "layers": [125, 126],
        "target_node": "ItemBar/SelectedHighlight",
        "purpose": "selected item highlight",
        "visible": False,
    },
]

DYNAMIC_FIELDS = [
    {
        "name": "txt_day_hour",
        "source_layers": [136],
        "target_node": "TopBar/DayHourLabel",
        "purpose": "runtime day and hour text",
    },
    {
        "name": "txt_coin_amount",
        "source_layers": [85],
        "target_node": "Coin/AmountLabel",
        "purpose": "runtime coin amount text",
    },
    {
        "name": "slot_party_pet_1",
        "source_layers": [81],
        "target_node": "PartySlots/Slot1",
        "purpose": "runtime pet icon slot",
    },
    {
        "name": "slot_party_pet_2",
        "source_layers": [80],
        "target_node": "PartySlots/Slot2",
        "purpose": "runtime pet icon slot",
    },
    {
        "name": "slot_party_pet_3",
        "source_layers": [79],
        "target_node": "PartySlots/Slot3",
        "purpose": "runtime pet icon slot",
    },
    {
        "name": "slot_party_pet_4",
        "source_layers": [78],
        "target_node": "PartySlots/Slot4",
        "purpose": "runtime pet icon slot",
    },
]


def source_layer_image(psd, layer):
    width = layer["width"]
    height = layer["height"]
    if width <= 0 or height <= 0:
        return None
    channels = {}
    data = psd["data"]
    for channel in layer["channels"]:
        payload = data[channel["offset"] : channel["offset"] + channel["length"]]
        channels[channel["id"]] = decode_channel(payload, width, height)
    red = channels.get(0, bytes([0] * width * height))
    green = channels.get(1, red)
    blue = channels.get(2, red)
    alpha = channels.get(-1, bytes([255] * width * height))
    rgba = bytearray(width * height * 4)
    rgba[0::4] = red
    rgba[1::4] = green
    rgba[2::4] = blue
    rgba[3::4] = alpha
    image = Image.frombytes("RGBA", (width, height), bytes(rgba))
    if layer["opacity"] < 255:
        a = image.getchannel("A").point(lambda value: value * layer["opacity"] // 255)
        image.putalpha(a)
    return image


def alpha_over(dst, src, left, top):
    canvas_w, canvas_h = dst.size
    src_w, src_h = src.size
    x0 = max(0, left)
    y0 = max(0, top)
    x1 = min(canvas_w, left + src_w)
    y1 = min(canvas_h, top + src_h)
    if x1 <= x0 or y1 <= y0:
        return
    src_crop = src.crop((x0 - left, y0 - top, x1 - left, y1 - top))
    dst.alpha_composite(src_crop, (x0, y0))


def render_unit(psd, layers_by_index, layer_indices):
    canvas = Image.new("RGBA", (psd["width"], psd["height"]), (0, 0, 0, 0))
    sources = []
    for index in layer_indices:
        layer = layers_by_index[index]
        image = source_layer_image(psd, layer)
        if image is None:
            continue
        alpha_over(canvas, image, layer["left"], layer["top"])
        sources.append(layer)
    bbox = canvas.getchannel("A").getbbox()
    if bbox is None:
        return None, None, sources
    return canvas.crop(bbox), bbox, sources


def layer_summary(layer):
    return {
        "index": layer["index"],
        "name": layer["name"],
        "kind": layer["kind"],
        "visible": layer["visible"],
        "bbox": [layer["left"], layer["top"], layer["right"], layer["bottom"]],
        "opacity": layer["opacity"],
        "blend_mode": layer["blend_mode"],
    }


def build_manifest(psd, unit_items, dynamic_items, source_psd):
    classification = {}
    for unit in unit_items:
        for layer in unit["source_layers"]:
            classification[layer["index"]] = {
                "category": unit["category"],
                "unit": unit["name"],
                "exported": True,
            }
    for field in dynamic_items:
        for layer in field["source_layers"]:
            classification[layer["index"]] = {
                "category": "DYNAMIC_FIELD",
                "unit": field["name"],
                "exported": False,
            }

    source_layers = []
    for layer in psd["layers"]:
        item = layer_summary(layer)
        item.update(
            classification.get(
                layer["index"],
                {
                    "category": "IGNORE",
                    "unit": "",
                    "exported": False,
                    "reason": "legacy variant, hidden reference, folder marker, or non-runtime source layer",
                },
            )
        )
        source_layers.append(item)

    return {
        "schema_version": 1,
        "screen_type": "screen_three_choice",
        "source_psd_name": source_psd.name,
        "canvas": {"width": psd["width"], "height": psd["height"]},
        "output_psd": PSD_NAME,
        "notes": [
            "Godot-facing PSD derived from the provided three-choice art PSD.",
            "Dynamic text and runtime pet icons are represented as placeholder geometry, not exported art.",
            "Fixed decorations that move and change together are merged into single render units.",
        ],
        "runtime_units": unit_items,
        "dynamic_fields": dynamic_items,
        "source_layer_classification": source_layers,
    }


def make_photoshop_js(manifest):
    script = f"""#target photoshop
app.displayDialogs = DialogModes.NO;

var rootPath = "{OUT_DIR.as_posix()}";
var manifestPath = rootPath + "/godot_psd_manifest.json";
var outputPsdPath = rootPath + "/{PSD_NAME}";

function readText(path) {{
    var file = new File(path);
    file.encoding = "UTF8";
    file.open("r");
    var text = file.read();
    file.close();
    return text;
}}

function px(value) {{
    try {{
        return Math.round(value.as("px"));
    }} catch (e) {{
        return 0;
    }}
}}

function group(parent, name) {{
    var layerSet = parent.layerSets.add();
    layerSet.name = name;
    return layerSet;
}}

function importLayer(doc, parentGroup, item) {{
    var sourceFile = new File(rootPath + "/" + item.psd_layer_path);
    if (!sourceFile.exists) return;

    var layerDoc = app.open(sourceFile);
    layerDoc.selection.selectAll();
    layerDoc.selection.copy();
    layerDoc.close(SaveOptions.DONOTSAVECHANGES);

    app.activeDocument = doc;
    doc.paste();
    var layer = doc.activeLayer;
    layer.name = item.name;
    layer.opacity = Math.max(0, Math.min(100, item.opacity_percent));
    layer.visible = item.visible ? true : false;

    layer.move(parentGroup, ElementPlacement.INSIDE);
}}

function addPlaceholder(doc, parentGroup, item) {{
    app.activeDocument = doc;
    var layer = doc.artLayers.add();
    layer.name = item.name;
    var b = item.bbox;
    doc.selection.select([[b[0], b[1]], [b[2], b[1]], [b[2], b[3]], [b[0], b[3]]]);
    var color = new SolidColor();
    color.rgb.red = 0;
    color.rgb.green = 200;
    color.rgb.blue = 255;
    doc.selection.fill(color, ColorBlendMode.NORMAL, 100, false);
    doc.selection.deselect();
    layer.opacity = 28;
    layer.visible = false;
    layer.move(parentGroup, ElementPlacement.INSIDE);
    layer.visible = false;
}}

var manifest = eval("(" + readText(manifestPath) + ")");
var doc = app.documents.add(
    manifest.canvas.width,
    manifest.canvas.height,
    72,
    "screen_three_choice_godot_v1",
    NewDocumentMode.RGB,
    DocumentFill.TRANSPARENT
);
var emptyBase = doc.activeLayer;

var rootGroup = doc.layerSets.add();
rootGroup.name = "screen_three_choice";
var groups = {{}};
groups["MERGE_TEXTURE"] = group(rootGroup, "MERGE_TEXTURE");
groups["COMPONENT"] = group(rootGroup, "COMPONENT");
groups["STATE_RESOURCE"] = group(rootGroup, "STATE_RESOURCE");
groups["DYNAMIC_FIELD"] = group(rootGroup, "DYNAMIC_FIELD");
groups["GODOT_CONTROL"] = group(rootGroup, "GODOT_CONTROL");
groups["IGNORE_REF"] = group(rootGroup, "IGNORE_REF");

for (var i = 0; i < manifest.runtime_units.length; i++) {{
    var unit = manifest.runtime_units[i];
    importLayer(doc, groups[unit.category] || groups["MERGE_TEXTURE"], unit);
}}

for (var j = 0; j < manifest.dynamic_fields.length; j++) {{
    addPlaceholder(doc, groups["DYNAMIC_FIELD"], manifest.dynamic_fields[j]);
}}
for (var k = 0; k < groups["DYNAMIC_FIELD"].artLayers.length; k++) {{
    groups["DYNAMIC_FIELD"].artLayers[k].visible = false;
}}
groups["DYNAMIC_FIELD"].visible = false;

try {{
    emptyBase.remove();
}} catch (e) {{}}

var saveOptions = new PhotoshopSaveOptions();
saveOptions.layers = true;
doc.saveAs(new File(outputPsdPath), saveOptions, true, Extension.LOWERCASE);
doc.close(SaveOptions.DONOTSAVECHANGES);
"""
    return script


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source_psd", help="Source art PSD used to derive the Godot-facing PSD")
    args = parser.parse_args()

    source_psd = Path(args.source_psd).expanduser()
    if not source_psd.exists():
        raise FileNotFoundError(source_psd)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    PSD_LAYER_DIR.mkdir(parents=True, exist_ok=True)

    psd = parse_psd(source_psd)
    layers_by_index = {layer["index"]: layer for layer in psd["layers"]}

    unit_items = []
    preview = Image.new("RGBA", (psd["width"], psd["height"]), (0, 0, 0, 0))
    for unit in UNITS:
        image, bbox, sources = render_unit(psd, layers_by_index, unit["layers"])
        if image is None:
            continue
        export_path = EXPORT_DIR / f"{unit['name']}.png"
        image.save(export_path)
        psd_layer = Image.new("RGBA", (psd["width"], psd["height"]), (0, 0, 0, 0))
        alpha_over(psd_layer, image, bbox[0], bbox[1])
        psd_layer_path = PSD_LAYER_DIR / f"{unit['name']}.png"
        psd_layer.save(psd_layer_path)
        visible = unit.get("visible", True)
        if visible:
            alpha_over(preview, image, bbox[0], bbox[1])
        unit_items.append(
            {
                "name": unit["name"],
                "category": unit["category"],
                "export_path": str(export_path.relative_to(OUT_DIR)),
                "psd_layer_path": str(psd_layer_path.relative_to(OUT_DIR)),
                "bbox": list(bbox),
                "size": [bbox[2] - bbox[0], bbox[3] - bbox[1]],
                "visible": visible,
                "opacity_percent": 100,
                "target_node": unit["target_node"],
                "purpose": unit["purpose"],
                "source_layers": [layer_summary(layer) for layer in sources],
                "classification": unit["category"],
                "nine_slice": None,
            }
        )

    dynamic_items = []
    for field in DYNAMIC_FIELDS:
        source_layers = [layers_by_index[index] for index in field["source_layers"]]
        left = min(layer["left"] for layer in source_layers)
        top = min(layer["top"] for layer in source_layers)
        right = max(layer["right"] for layer in source_layers)
        bottom = max(layer["bottom"] for layer in source_layers)
        dynamic_items.append(
            {
                "name": field["name"],
                "category": "DYNAMIC_FIELD",
                "bbox": [left, top, right, bottom],
                "size": [right - left, bottom - top],
                "visible": False,
                "target_node": field["target_node"],
                "purpose": field["purpose"],
                "source_layers": [layer_summary(layer) for layer in source_layers],
                "export_path": None,
                "classification": "DYNAMIC_FIELD",
            }
        )

    manifest = build_manifest(psd, unit_items, dynamic_items, source_psd)
    (OUT_DIR / "godot_psd_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    preview.convert("RGB").save(OUT_DIR / "preview_visible_units.png")
    (OUT_DIR / "build_godot_psd.jsx").write_text(make_photoshop_js(manifest), encoding="utf-8")
    print(json.dumps({"out_dir": str(OUT_DIR), "runtime_units": len(unit_items)}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
