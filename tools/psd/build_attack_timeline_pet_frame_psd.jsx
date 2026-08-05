#target photoshop

(function () {
    var originalDialogs = app.displayDialogs;
    var originalUnits = app.preferences.rulerUnits;
    app.displayDialogs = DialogModes.NO;
    app.preferences.rulerUnits = Units.PIXELS;

    var scriptFile = new File($.fileName);
    var projectRoot = scriptFile.parent.parent.parent;
    var assetRoot = new Folder(projectRoot.fsName + "/art/images/battle/hud/attack_timeline/pet_frame");
    var outputDir = new Folder(assetRoot.fsName + "/source_psd");
    var previewDir = new Folder(projectRoot.fsName + "/output");
    if (!outputDir.exists) outputDir.create();
    if (!previewDir.exists) previewDir.create();

    var errorFile = new File(previewDir.fsName + "/attack_timeline_pet_frame_psd_v2_error.txt");
    if (errorFile.exists) errorFile.remove();

    function solidColor(hex) {
        var value = new SolidColor();
        value.rgb.red = parseInt(hex.substring(0, 2), 16);
        value.rgb.green = parseInt(hex.substring(2, 4), 16);
        value.rgb.blue = parseInt(hex.substring(4, 6), 16);
        return value;
    }

    function addLayer(doc, group, name) {
        var layer = doc.artLayers.add();
        layer.name = name;
        layer.move(group, ElementPlacement.INSIDE);
        doc.activeLayer = layer;
        return layer;
    }

    function selectEllipse(doc, left, top, right, bottom) {
        var descriptor = new ActionDescriptor();
        var reference = new ActionReference();
        reference.putProperty(charIDToTypeID("Chnl"), charIDToTypeID("fsel"));
        descriptor.putReference(charIDToTypeID("null"), reference);
        var ellipse = new ActionDescriptor();
        ellipse.putUnitDouble(charIDToTypeID("Top "), charIDToTypeID("#Pxl"), top);
        ellipse.putUnitDouble(charIDToTypeID("Left"), charIDToTypeID("#Pxl"), left);
        ellipse.putUnitDouble(charIDToTypeID("Btom"), charIDToTypeID("#Pxl"), bottom);
        ellipse.putUnitDouble(charIDToTypeID("Rght"), charIDToTypeID("#Pxl"), right);
        descriptor.putObject(charIDToTypeID("T   "), charIDToTypeID("Elps"), ellipse);
        executeAction(charIDToTypeID("setd"), descriptor, DialogModes.NO);
    }

    function fillEllipse(doc, layer, left, top, right, bottom, fillColor) {
        doc.activeLayer = layer;
        selectEllipse(doc, left, top, right, bottom);
        doc.selection.fill(fillColor, ColorBlendMode.NORMAL, 100, false);
        doc.selection.deselect();
    }

    function fillRect(doc, layer, left, top, right, bottom, fillColor) {
        doc.activeLayer = layer;
        doc.selection.select([[left, top], [right, top], [right, bottom], [left, bottom]]);
        doc.selection.fill(fillColor, ColorBlendMode.NORMAL, 100, false);
        doc.selection.deselect();
    }

    function placeNative(doc, file, group, name, yOffset) {
        if (!file.exists) throw new Error("Missing asset: " + file.fsName);
        var source = app.open(file);
        var placed = source.activeLayer.duplicate(doc, ElementPlacement.PLACEATBEGINNING);
        source.close(SaveOptions.DONOTSAVECHANGES);
        app.activeDocument = doc;
        placed.name = name;
        placed.translate(0, yOffset || 0);
        placed.move(group, ElementPlacement.INSIDE);
        return placed;
    }

    function placeInsetBackground(doc, file, group, name) {
        var placed = placeNative(doc, file, group, name, 0);
        var bounds = placed.bounds;
        var width = bounds[2].as("px") - bounds[0].as("px");
        var targetVisibleWidth = 190;
        var scale = targetVisibleWidth / width;
        placed.resize(scale * 100, scale * 100, AnchorPosition.MIDDLECENTER);
        bounds = placed.bounds;
        var centerX = (bounds[0].as("px") + bounds[2].as("px")) / 2;
        var centerY = (bounds[1].as("px") + bounds[3].as("px")) / 2;
        placed.translate(110 - centerX, 110 - centerY);
        return placed;
    }

    function placePet(doc, file, group, name, usedRect) {
        if (!file.exists) throw new Error("Missing pet: " + file.fsName);
        var source = app.open(file);
        if (usedRect && usedRect.length === 4) {
            source.crop([
                usedRect[0],
                usedRect[1],
                usedRect[0] + usedRect[2],
                usedRect[1] + usedRect[3]
            ]);
        }
        var placed = source.activeLayer.duplicate(doc, ElementPlacement.PLACEATBEGINNING);
        source.close(SaveOptions.DONOTSAVECHANGES);
        app.activeDocument = doc;
        placed.name = name;
        var bounds = placed.bounds;
        var width = bounds[2].as("px") - bounds[0].as("px");
        var height = bounds[3].as("px") - bounds[1].as("px");
        var scale = Math.min(160 / width, 150 / height);
        placed.resize(scale * 100, scale * 100, AnchorPosition.MIDDLECENTER);
        bounds = placed.bounds;
        var currentCenterX = (bounds[0].as("px") + bounds[2].as("px")) / 2;
        var currentBottom = bounds[3].as("px");
        placed.translate(110 - currentCenterX, 192 - currentBottom);
        placed.move(group, ElementPlacement.INSIDE);
        return placed;
    }

    function addText(doc, group, name, contents, x, y, size) {
        var layer = addLayer(doc, group, name);
        layer.kind = LayerKind.TEXT;
        layer.textItem.contents = contents;
        layer.textItem.position = [x, y];
        layer.textItem.size = size;
        layer.textItem.justification = Justification.CENTER;
        layer.textItem.color = solidColor("3D2B18");
        layer.textItem.antiAliasMethod = AntiAlias.NONE;
        return layer;
    }

    try {
        var doc = app.documents.add(220, 220, 72, "component_attack_timeline_pet_frame_godot_v2", NewDocumentMode.RGB, DocumentFill.TRANSPARENT, 1, BitsPerChannelType.EIGHT);

        var referenceGroup = doc.layerSets.add();
        referenceGroup.name = "00_reference_ignore";
        referenceGroup.visible = false;
        while (doc.artLayers.length > 0) doc.artLayers[0].remove();

        var backgrounds = doc.layerSets.add();
        backgrounds.name = "01_background_states";
        var backgroundKinds = ["earth", "fire", "ice", "light", "mechanical", "nature", "shadow", "water", "wind"];
        for (var i = 0; i < backgroundKinds.length; i++) {
            var kind = backgroundKinds[i];
            var background = placeInsetBackground(
                doc,
                new File(assetRoot.fsName + "/backgrounds/creature_card_background_" + kind + "_001.png"),
                backgrounds,
                "state_background_" + kind
            );
            background.visible = kind === "nature";
        }

        var petGroup = doc.layerSets.add();
        petGroup.name = "02_pet_slot";
        placePet(
            doc,
            new File(projectRoot.fsName + "/art/images/shared/pets/sheets/slices/pet_style_001_gold_mascot.png"),
            petGroup,
            "icon_pet",
            [158, 132, 709, 704]
        );

        var frames = doc.layerSets.add();
        frames.name = "03_frame_states";
        var qualities = ["bronze", "silver", "gold", "diamond"];
        for (var q = 0; q < qualities.length; q++) {
            var quality = qualities[q];
            var frame = placeNative(
                doc,
                new File(assetRoot.fsName + "/top_frames/creature_card_top_frame_" + quality + "_001.png"),
                frames,
                "state_frame_" + quality,
                0
            );
            frame.visible = quality === "bronze";
        }

        var controls = doc.layerSets.add();
        controls.name = "04_control";
        var hit = addLayer(doc, controls, "hit_card");
        fillRect(doc, hit, 0, 0, 220, 220, solidColor("FF00FF"));
        hit.opacity = 20;
        hit.visible = false;

        var psdFile = new File(outputDir.fsName + "/component_attack_timeline_pet_frame_godot_v2.psd");
        var psdOptions = new PhotoshopSaveOptions();
        psdOptions.layers = true;
        psdOptions.maximizeCompatibility = true;
        doc.saveAs(psdFile, psdOptions, true, Extension.LOWERCASE);

        var previewFile = new File(previewDir.fsName + "/component_attack_timeline_pet_frame_godot_v2_preview.png");
        var pngOptions = new PNGSaveOptions();
        pngOptions.compression = 6;
        pngOptions.interlaced = false;
        doc.saveAs(previewFile, pngOptions, true, Extension.LOWERCASE);

        doc.close(SaveOptions.DONOTSAVECHANGES);
        app.preferences.rulerUnits = originalUnits;
        app.displayDialogs = originalDialogs;
    } catch (error) {
        errorFile.open("w");
        errorFile.encoding = "UTF8";
        errorFile.write("Line " + error.line + ": " + error.message + "\n" + error.stack);
        errorFile.close();
        app.preferences.rulerUnits = originalUnits;
        app.displayDialogs = originalDialogs;
        throw error;
    }
}());
