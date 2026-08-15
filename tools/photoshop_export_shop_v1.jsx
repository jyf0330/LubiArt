#target photoshop
app.displayDialogs = DialogModes.NO;

var repoRoot = new File($.fileName).parent.parent.fsName;
var sourcePath = $.getenv("LUBI_SHOP_SOURCE_PSD");
var sourceName = "新商店2_三选建筑工作版_副本.psd";
var outputRoot = repoRoot + "/outputs/shop_godot_psd_v1/raw_full_canvas";

var units = [
    {name: "background", paths: [
        "背景/exec-75b199e0-f71a-4586-97ac-2b46a3a3451c",
        "外围阴影"
    ]},
    {name: "background_no_outer_shadow", paths: [
        "背景/exec-75b199e0-f71a-4586-97ac-2b46a3a3451c"
    ]},
    {name: "shop_facade", paths: [
        "商店主要界面/调色/Color Balance 1 copy 2",
        "商店主要界面/遮挡柜台",
        "商店主要界面/柜台阴影",
        "商店主要界面/商店底图"
    ]},
    {name: "merchant_default", paths: [
        "商店主要界面/调色/Color Balance 1 copy 2",
        "商店主要界面/商人立绘"
    ]},
    {name: "refresh_curtain", paths: [
        "商店主要界面/调色/Color Balance 1 copy 2",
        "商店主要界面/刷新帘子/帘子右",
        "商店主要界面/刷新帘子/帘子左",
        "商店主要界面/刷新帘子/帘子中"
    ]},
    {name: "refresh_bell_normal", paths: [
        "商店主要界面/调色/Color Balance 1 copy 2",
        "商店主要界面/刷新铃铛/刷新铃铛"
    ]},
    {name: "refresh_bell_hover", paths: [
        "商店主要界面/调色/Color Balance 1 copy 2",
        "商店主要界面/刷新铃铛/刷新铃铛",
        "商店主要界面/刷新铃铛/铃铛高亮"
    ]}
];

function ensureFolder(path) {
    var folder = new Folder(path);
    if (!folder.exists) folder.create();
}

function locateSourceDocument() {
    for (var i = 0; i < app.documents.length; i++) {
        var candidate = app.documents[i];
        if (sourcePath) {
            try {
                if (candidate.fullName.fsName == new File(sourcePath).fsName) {
                    sourceWasAlreadyOpen = true;
                    return candidate;
                }
            } catch (e) {}
        }
        if (candidate.name == sourceName) {
            sourceWasAlreadyOpen = true;
            return candidate;
        }
    }
    if (!sourcePath) throw new Error("Set LUBI_SHOP_SOURCE_PSD or open " + sourceName + " in Photoshop.");
    return app.open(new File(sourcePath));
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

ensureFolder(repoRoot + "/outputs");
ensureFolder(repoRoot + "/outputs/shop_godot_psd_v1");
ensureFolder(outputRoot);
var sourceWasAlreadyOpen = false;
var source = locateSourceDocument();
for (var unitIndex = 0; unitIndex < units.length; unitIndex++) {
    var unit = units[unitIndex];
    var doc = source.duplicate("shop_export_" + unit.name, false);
    hideArtLayers(doc);
    for (var pathIndex = 0; pathIndex < unit.paths.length; pathIndex++) revealPath(doc, unit.paths[pathIndex]);
    exportPng24(doc, outputRoot + "/" + unit.name + ".png");
    doc.close(SaveOptions.DONOTSAVECHANGES);
}
if (!sourceWasAlreadyOpen) source.close(SaveOptions.DONOTSAVECHANGES);
