#target photoshop
app.displayDialogs = DialogModes.NO;

var repoRoot = new File($.fileName).parent.parent.fsName;
var sourcePath = $.getenv("LUBI_THREE_CHOICE_SOURCE_PSD");
if (!sourcePath) {
    throw new Error("Set LUBI_THREE_CHOICE_SOURCE_PSD to the original artist PSD before listing layers.");
}
var outPath = repoRoot + "/outputs/photoshop_layer_walk_v3.tsv";

function px(value) {
    try {
        return Math.round(value.as("px"));
    } catch (e) {
        return 0;
    }
}

function clean(value) {
    return String(value).replace(/\t/g, " ").replace(/\r?\n/g, " ");
}

var doc = app.open(new File(sourcePath));
var lines = ["seq\ttype\tname\tvisible\topacity\tblend\tleft\ttop\tright\tbottom\tpath"];
var seq = 0;

function walk(container, path) {
    for (var i = 0; i < container.layers.length; i++) {
        var layer = container.layers[i];
        var currentPath = path.concat([layer.name]);
        if (layer.typename == "ArtLayer") {
            var b = layer.bounds;
            lines.push([
                seq++,
                "layer",
                clean(layer.name),
                layer.visible ? "true" : "false",
                layer.opacity,
                clean(layer.blendMode),
                px(b[0]), px(b[1]), px(b[2]), px(b[3]),
                clean(currentPath.join("/"))
            ].join("\t"));
        } else if (layer.typename == "LayerSet") {
            lines.push([
                seq++,
                "group",
                clean(layer.name),
                layer.visible ? "true" : "false",
                "",
                "",
                "", "", "", "",
                clean(currentPath.join("/"))
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
