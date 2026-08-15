#target photoshop
app.displayDialogs = DialogModes.NO;

var repoRoot = new File($.fileName).parent.parent.fsName;
var sourcePath = repoRoot + "/art/images/shop/source_psd/screen_shop_godot_v1.psd";
var outputFolder = new Folder(repoRoot + "/outputs/shop_godot_psd_v1");
if (!outputFolder.exists) outputFolder.create();
var outputPath = outputFolder.fsName + "/screen_shop_godot_v1_preview.png";

var doc = app.open(new File(sourcePath));
var options = new ExportOptionsSaveForWeb();
options.format = SaveDocumentType.PNG;
options.PNG8 = false;
options.transparency = true;
options.interlaced = false;
options.includeProfile = false;
doc.exportDocument(new File(outputPath), ExportType.SAVEFORWEB, options);
doc.close(SaveOptions.DONOTSAVECHANGES);
