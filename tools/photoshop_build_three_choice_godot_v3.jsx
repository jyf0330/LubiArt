#target photoshop
app.displayDialogs = DialogModes.NO;

var repoRoot = new File($.fileName).parent.parent.fsName;
var root = repoRoot + "/outputs/three_choice_godot_psd_v3";
var exportRoot = root + "/exports";
var outputPath = root + "/screen_three_choice_godot_v3.psd";

function makeGroup(doc, name) {
    var group = doc.layerSets.add();
    group.name = name;
    return group;
}

function makeChildGroup(parent, name) {
    var group = parent.layerSets.add();
    group.name = name;
    return group;
}

function placePng(doc, group, fileName, layerName, left, top, visible) {
    var source = app.open(new File(exportRoot + "/" + fileName));
    source.selection.selectAll();
    source.selection.copy(true);
    source.close(SaveOptions.DONOTSAVECHANGES);

    app.activeDocument = doc;
    var layer = doc.paste();
    layer.name = layerName;
    var bounds = layer.bounds;
    layer.translate(left - bounds[0].as("px"), top - bounds[1].as("px"));
    layer.visible = visible;
    layer.move(group, ElementPlacement.INSIDE);
    return layer;
}

function placePortrait(doc, group, fileName, layerName, cardLeft, cardTop, visible) {
    // Photoshop 2025 cannot transform a hidden layer. Place and position the
    // portrait while visible, then restore its authored preview visibility.
    var layer = placePng(doc, group, fileName, layerName, 0, 0, true);
    var bounds = layer.bounds;
    var width = bounds[2].as("px") - bounds[0].as("px");
    var height = bounds[3].as("px") - bounds[1].as("px");
    var targetLeft = cardLeft + 160 - width / 2;
    var targetTop = cardTop + 370 - height;
    layer.translate(targetLeft - bounds[0].as("px"), targetTop - bounds[1].as("px"));
    layer.visible = visible;
    return layer;
}

function placeholder(doc, group, name, rect, visible) {
    app.activeDocument = doc;
    var layer = doc.artLayers.add();
    layer.name = name;
    doc.selection.select([
        [rect[0], rect[1]],
        [rect[2], rect[1]],
        [rect[2], rect[3]],
        [rect[0], rect[3]]
    ]);
    var color = new SolidColor();
    color.rgb.red = 0;
    color.rgb.green = 255;
    color.rgb.blue = 255;
    doc.selection.fill(color, ColorBlendMode.NORMAL, 20, false);
    doc.selection.deselect();
    layer.visible = visible;
    layer.move(group, ElementPlacement.INSIDE);
    return layer;
}

var doc = app.documents.add(1920, 1080, 72, "screen_three_choice_godot_v3", NewDocumentMode.RGB, DocumentFill.TRANSPARENT);
var merge = makeGroup(doc, "MERGE_TEXTURE");
var component = makeGroup(doc, "COMPONENT");
var state = makeGroup(doc, "STATE_RESOURCE");
var dynamic = makeGroup(doc, "DYNAMIC_FIELD");
var control = makeGroup(doc, "GODOT_CONTROL");
var ignore = makeGroup(doc, "IGNORE_REF");

placePng(doc, merge, "background.png", "background", 0, 0, true);
placePng(doc, merge, "building.png", "building", 255, 92, true);
placePng(doc, merge, "coin_panel_static.png", "coin_panel_static", 1303, 905, true);

var shopCard = makeChildGroup(component, "component_route_card_shop");
placePng(doc, shopCard, "route_icon_shop.png", "route_icon_shop_existing_reused", 575, 394, true);
placePortrait(doc, shopCard, "route_portrait_shop.png", "route_portrait_shop_existing_reused", 436, 346, true);
placePortrait(doc, shopCard, "route_portrait_shop_bai_xiaochang.png", "route_portrait_shop_bai_xiaochang", 436, 346, false);
placePortrait(doc, shopCard, "route_portrait_shop_variant_3.png", "route_portrait_shop_variant_3", 436, 346, false);
placePortrait(doc, shopCard, "route_portrait_shop_variant_5.png", "route_portrait_shop_variant_5", 436, 346, false);

var eventCard = makeChildGroup(component, "component_route_card_event");
placePng(doc, eventCard, "route_icon_event.png", "route_icon_event_existing_reused", 890, 394, true);
placePortrait(doc, eventCard, "route_portrait_event.png", "route_portrait_event_existing_reused", 747, 346, true);
placePortrait(doc, eventCard, "route_portrait_event_herb_merchant.png", "route_portrait_event_herb_merchant", 747, 346, false);
placePortrait(doc, eventCard, "route_portrait_event_fish_merchant.png", "route_portrait_event_fish_merchant", 747, 346, false);
placePortrait(doc, eventCard, "route_portrait_event_ox_merchant.png", "route_portrait_event_ox_merchant", 747, 346, false);

var rewardCard = makeChildGroup(component, "component_route_card_reward");
placePng(doc, rewardCard, "route_icon_reward.png", "route_icon_reward_existing_reused", 1201, 394, true);
placePortrait(doc, rewardCard, "route_portrait_reward.png", "route_portrait_reward_existing_reused", 1072, 346, true);
placePortrait(doc, rewardCard, "route_portrait_reward_short_samurai.png", "route_portrait_reward_short_samurai", 1072, 346, false);
placePortrait(doc, rewardCard, "route_portrait_reward_variant_4.png", "route_portrait_reward_variant_4", 1072, 346, false);

placePng(doc, state, "route_highlight_shop.png", "route_highlight_shop_hover_selected", 442, 349, false);
placePng(doc, state, "route_highlight_event.png", "route_highlight_event_hover_selected", 753, 346, false);
placePng(doc, state, "route_highlight_reward.png", "route_highlight_reward_hover_selected", 1078, 349, false);
placePng(doc, state, "exit_normal.png", "exit_normal", 1410, 510, true);
placePng(doc, state, "exit_hover.png", "exit_hover", 1410, 510, false);
placePng(doc, state, "bag_closed.png", "bag_closed", 313, 796, true);
// The open-state texture keeps its full canvas origin at x=313, while its
// first visible alpha column is authored at local x=1 after leak cleanup.
placePng(doc, state, "bag_open_full.png", "bag_open", 314, 796, false);
placePng(doc, state, "party_shelf.png", "party_shelf_static_above_chest", 519, 607, true);
placePng(doc, state, "bag_inventory_base.png", "bag_inventory_base", 502, 399, false);
placePng(doc, state, "bag_item_highlight.png", "bag_item_hover", 542, 430, false);

placeholder(doc, dynamic, "txt_coin_amount", [1373, 937, 1436, 965], false);
placeholder(doc, dynamic, "slot_party_pet_1", [560, 813, 724, 983], false);
placeholder(doc, dynamic, "slot_party_pet_2", [738, 813, 902, 983], false);
placeholder(doc, dynamic, "slot_party_pet_3", [914, 813, 1078, 983], false);
placeholder(doc, dynamic, "slot_party_pet_4", [1094, 813, 1258, 983], false);
var bagSlotRects = [
    [551, 443, 705, 589], [740, 443, 894, 589], [929, 443, 1083, 589], [1118, 443, 1272, 589],
    [551, 611, 705, 757], [740, 611, 894, 757], [929, 611, 1083, 757], [1118, 611, 1272, 757]
];
for (var i = 0; i < bagSlotRects.length; i++) {
    placeholder(doc, dynamic, "slot_bag_item_" + (i + 1), bagSlotRects[i], false);
}

placeholder(doc, control, "hit_exit_button_TextureButton", [1410, 510, 1679, 982], false);
placeholder(doc, control, "dim_bag_overlay_ColorRect_49pct", [0, 0, 1920, 1080], false);

var obsolete = doc.artLayers.add();
obsolete.name = "obsolete_incense_smoke_do_not_export";
obsolete.visible = false;
obsolete.move(ignore, ElementPlacement.INSIDE);

var saveOptions = new PhotoshopSaveOptions();
saveOptions.layers = true;
saveOptions.embedColorProfile = true;
saveOptions.alphaChannels = true;
doc.saveAs(new File(outputPath), saveOptions, true, Extension.LOWERCASE);
doc.close(SaveOptions.DONOTSAVECHANGES);
