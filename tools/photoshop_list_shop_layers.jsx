#target photoshop
app.displayDialogs = DialogModes.NO;

var repoRoot = new File($.fileName).parent.parent.fsName;
var sourcePath = $.getenv("LUBI_SHOP_SOURCE_PSD");
var sourceName = "新商店2_三选建筑工作版_副本.psd";
var outFolder = new Folder(repoRoot + "/outputs/shop_godot_psd_v1");
if (!outFolder.exists) outFolder.create();
var outPath = outFolder.fsName + "/photoshop_layer_walk.tsv";

function px(value) {
    try { return Math.round(value.as("px")); } catch (e) { return 0; }
}

function clean(value) {
    return String(value).replace(/\t/g, " ").replace(/\r?\n/g, " ");
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

var sourceWasAlreadyOpen = false;
var source = locateSourceDocument();
var doc = source.duplicate("shop_layer_walk_read_only", false);
var lines = ["seq\ttype\tname\tvisible\topacity\tblend\tleft\ttop\tright\tbottom\tpath"];
var seq = 0;

function walk(container, path) {
    for (var i = 0; i < container.layers.length; i++) {
        var layer = container.layers[i];
        var currentPath = path.concat([layer.name]);
        if (layer.typename == "ArtLayer") {
            var b = layer.bounds;
            lines.push([
                seq++, "layer", clean(layer.name), layer.visible ? "true" : "false",
                layer.opacity, clean(layer.blendMode), px(b[0]), px(b[1]), px(b[2]), px(b[3]),
                clean(currentPath.join("/"))
            ].join("\t"));
        } else if (layer.typename == "LayerSet") {
            lines.push([
                seq++, "group", clean(layer.name), layer.visible ? "true" : "false",
                "", "", "", "", "", "", clean(currentPath.join("/"))
            ].join("\t"));
            walk(layer, currentPath);
        }
    }
}

walk(doc, []);
var out = new File(outPath);
out.encoding = "UTF8";
out.open("w");
out.write(lines.join("\n"));
out.close();
doc.close(SaveOptions.DONOTSAVECHANGES);
if (!sourceWasAlreadyOpen) source.close(SaveOptions.DONOTSAVECHANGES);
