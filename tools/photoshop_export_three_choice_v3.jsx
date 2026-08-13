#target photoshop
app.displayDialogs = DialogModes.NO;

var repoRoot = new File($.fileName).parent.parent.fsName;
var sourcePath = $.getenv("LUBI_THREE_CHOICE_SOURCE_PSD");
if (!sourcePath) {
    throw new Error("Set LUBI_THREE_CHOICE_SOURCE_PSD to the original artist PSD before exporting.");
}
var outputRoot = repoRoot + "/outputs/three_choice_godot_psd_v3/raw_full_canvas";

var units = [
    {name: "background", paths: ["新背景"]},
    {name: "building", paths: ["调色", "三选/三选", "三选/外围阴影"]},
    {name: "building_ungraded", paths: ["三选/三选", "三选/外围阴影"]},
    {name: "party_shelf", paths: ["调色", "三选/队伍栏位/队伍栏位"]},
    {name: "party_shelf_ungraded", paths: ["三选/队伍栏位/队伍栏位"]},
    {name: "route_highlight_1", paths: ["三选/新三选高亮/高亮1"]},
    {name: "route_highlight_2", paths: ["三选/新三选高亮/高亮2"]},
    {name: "route_highlight_3", paths: ["三选/新三选高亮/高亮3"]},
    {name: "route_icon_1", paths: ["三选/三选立绘/Group 1/图层 53"]},
    {name: "route_icon_2", paths: ["三选/三选立绘/Group 2/图层 51"]},
    {name: "route_icon_3", paths: ["三选/三选立绘/Group 3/图层 81"]},
    {name: "portrait_slot_1_bai_xiaochang", paths: ["三选/三选立绘/Group 1/白小常"]},
    {name: "portrait_slot_1_variant_3", paths: ["三选/三选立绘/Layer 3"]},
    {name: "portrait_slot_1_variant_5", paths: ["三选/三选立绘/Layer 5"]},
    {name: "portrait_slot_2_herb_merchant", paths: ["三选/三选立绘/Group 2/采药商"]},
    {name: "portrait_slot_2_fish_merchant", paths: ["三选/三选立绘/鱼商人"]},
    {name: "portrait_slot_2_ox_merchant", paths: ["三选/三选立绘/牛头商人"]},
    {name: "portrait_slot_3_short_samurai", paths: ["三选/三选立绘/Group 3/矮武士"]},
    {name: "portrait_slot_3_variant_4", paths: ["三选/三选立绘/Layer 4"]},
    {name: "exit_normal", paths: ["调色", "三选/退出门/退出"]},
    {name: "exit_normal_ungraded", paths: ["三选/退出门/退出"]},
    {name: "exit_hover", paths: ["调色", "三选/退出门/退出", "三选/退出门/退出选择高亮/退出帘子掀开", "三选/退出门/退出选择高亮/箭头高亮"]},
    {name: "exit_hover_ungraded", paths: ["三选/退出门/退出", "三选/退出门/退出选择高亮/退出帘子掀开", "三选/退出门/退出选择高亮/箭头高亮"]},
    {name: "bag_closed", paths: ["调色", "三选/背包/背包"]},
    {name: "bag_closed_ungraded", paths: ["三选/背包/背包"]},
    {name: "bag_open", paths: ["调色", "三选/背包/背包打开"]},
    {name: "bag_open_ungraded", paths: ["三选/背包/背包打开"]},
    {name: "bag_inventory_base", paths: ["三选/打开背包/底图", "三选/打开背包/背包栏位"]},
    {name: "bag_item_highlight", paths: ["三选/打开背包/发光", "三选/打开背包/高亮"]},
    {name: "coin_panel_static", paths: ["调色", "三选/金币/金币数量框", "三选/金币/金币标"]},
    {name: "coin_panel_static_ungraded", paths: ["三选/金币/金币数量框", "三选/金币/金币标"]}
];

function ensureFolder(path) {
    var folder = new Folder(path);
    if (!folder.exists) folder.create();
}

function hideArtLayers(container) {
    for (var i = 0; i < container.layers.length; i++) {
        var layer = container.layers[i];
        if (layer.typename == "ArtLayer") {
            layer.visible = false;
        } else if (layer.typename == "LayerSet") {
            layer.visible = true;
            hideArtLayers(layer);
        }
    }
}

function findDirectLayer(container, name) {
    for (var i = 0; i < container.layers.length; i++) {
        if (container.layers[i].name == name) return container.layers[i];
    }
    return null;
}

function revealPath(doc, path) {
    var parts = path.split("/");
    var container = doc;
    var layer = null;
    for (var i = 0; i < parts.length; i++) {
        layer = findDirectLayer(container, parts[i]);
        if (layer == null) throw new Error("Missing Photoshop layer path: " + path);
        layer.visible = true;
        if (i < parts.length - 1) {
            if (layer.typename != "LayerSet") throw new Error("Non-group path segment: " + parts[i]);
            container = layer;
        }
    }
}

function exportPng24(doc, path) {
    app.activeDocument = doc;
    var options = new ExportOptionsSaveForWeb();
    options.format = SaveDocumentType.PNG;
    options.PNG8 = false;
    options.transparency = true;
    options.interlaced = false;
    options.includeProfile = false;
    doc.exportDocument(new File(path), ExportType.SAVEFORWEB, options);
}

ensureFolder(outputRoot);
var source = app.open(new File(sourcePath));
for (var unitIndex = 0; unitIndex < units.length; unitIndex++) {
    var unit = units[unitIndex];
    var doc = source.duplicate("three_choice_export_" + unit.name, false);
    hideArtLayers(doc);
    for (var pathIndex = 0; pathIndex < unit.paths.length; pathIndex++) {
        revealPath(doc, unit.paths[pathIndex]);
    }
    exportPng24(doc, outputRoot + "/" + unit.name + ".png");
    doc.close(SaveOptions.DONOTSAVECHANGES);
}
source.close(SaveOptions.DONOTSAVECHANGES);
