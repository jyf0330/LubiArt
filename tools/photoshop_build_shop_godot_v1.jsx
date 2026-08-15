#target photoshop
app.displayDialogs = DialogModes.NO;

var repoRoot = new File($.fileName).parent.parent.fsName;
var exportRoot = repoRoot + "/art/images/shop/screen_shop_godot_v1";
var outputFolder = new Folder(repoRoot + "/art/images/shop/source_psd");
if (!outputFolder.exists) outputFolder.create();
var outputPath = outputFolder.fsName + "/screen_shop_godot_v1.psd";

function makeGroup(doc, name) {
    var group = doc.layerSets.add();
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

function placeholder(doc, group, name, rect, colorValues, visible) {
    app.activeDocument = doc;
    var layer = doc.artLayers.add();
    layer.name = name;
    doc.selection.select([
        [rect[0], rect[1]], [rect[2], rect[1]],
        [rect[2], rect[3]], [rect[0], rect[3]]
    ]);
    var color = new SolidColor();
    color.rgb.red = colorValues[0];
    color.rgb.green = colorValues[1];
    color.rgb.blue = colorValues[2];
    doc.selection.fill(color, ColorBlendMode.NORMAL, 18, false);
    doc.selection.deselect();
    layer.visible = visible;
    layer.move(group, ElementPlacement.INSIDE);
    return layer;
}

var doc = app.documents.add(1920, 1080, 72, "screen_shop_godot_v1", NewDocumentMode.RGB, DocumentFill.TRANSPARENT);
var merge = makeGroup(doc, "MERGE_TEXTURE");
var dynamic = makeGroup(doc, "DYNAMIC_FIELD");
var state = makeGroup(doc, "STATE_RESOURCE");
var control = makeGroup(doc, "GODOT_CONTROL");
var ignore = makeGroup(doc, "IGNORE_REF_SHARED_UI");

placePng(doc, merge, "background.png", "background", 0, 0, true);
placePng(doc, merge, "shop_facade.png", "shop_facade_complete_psd_base", 31, 76, true);
placePng(doc, dynamic, "merchant_default.png", "merchant_default_dynamic_fallback", 813, 566, true);
placePng(doc, state, "refresh_curtain.png", "refresh_curtain_refresh_only", 492, 313, false);
placePng(doc, state, "refresh_bell_normal.png", "refresh_button_normal", 945, 705, true);
placePng(doc, state, "refresh_bell_hover.png", "refresh_button_hover_pressed_focused", 945, 705, false);

var offerRects = [
    [498, 360, 658, 550], [823, 360, 983, 550], [1148, 360, 1308, 550],
    [498, 610, 658, 800], [1148, 610, 1308, 800]
];
for (var i = 0; i < offerRects.length; i++) {
    placeholder(doc, control, "slot_offer_" + (i + 1) + "_Button", offerRects[i], [0, 255, 210], false);
    placeholder(doc, dynamic, "txt_offer_price_" + (i + 1), [offerRects[i][0] + 56, offerRects[i][3] - 32, offerRects[i][2] - 12, offerRects[i][3] - 4], [255, 220, 64], false);
}
placeholder(doc, control, "hit_refresh_button_TextureButton", [945, 705, 1034, 791], [0, 255, 210], false);
placeholder(doc, dynamic, "slot_merchant_dynamic", [813, 566, 990, 768], [255, 160, 48], false);

placeholder(doc, ignore, "ref_shared_bag_and_party", [313, 607, 1258, 1029], [80, 160, 255], false);
placeholder(doc, ignore, "ref_shared_coin_panel", [1303, 905, 1468, 1029], [80, 160, 255], false);
placeholder(doc, ignore, "ref_shared_exit_button", [1410, 510, 1679, 982], [80, 160, 255], false);
placeholder(doc, ignore, "ref_shared_bag_overlay", [502, 399, 1320, 838], [80, 160, 255], false);

var saveOptions = new PhotoshopSaveOptions();
saveOptions.layers = true;
saveOptions.embedColorProfile = true;
saveOptions.alphaChannels = true;
doc.saveAs(new File(outputPath), saveOptions, true, Extension.LOWERCASE);
doc.close(SaveOptions.DONOTSAVECHANGES);
