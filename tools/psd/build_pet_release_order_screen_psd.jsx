#target photoshop

(function () {
    var originalDialogs = app.displayDialogs;
    var originalUnits = app.preferences.rulerUnits;
    app.displayDialogs = DialogModes.NO;
    app.preferences.rulerUnits = Units.PIXELS;

    var scriptFile = new File($.fileName);
    var projectRoot = scriptFile.parent.parent.parent;
    var sourceFile = new File(projectRoot.fsName + "/art/images/battle/hud/attack_timeline/source/screen_pet_release_order_transparent_v2.png");
    var outputDir = new Folder(projectRoot.fsName + "/art/images/battle/hud/attack_timeline/source_psd");
    var previewDir = new Folder(projectRoot.fsName + "/output");
    if (!outputDir.exists) outputDir.create();
    if (!previewDir.exists) previewDir.create();

    var psdFile = new File(outputDir.fsName + "/screen_pet_release_order_godot_v2.psd");
    var previewFile = new File(previewDir.fsName + "/screen_pet_release_order_godot_v2_preview.png");
    var doneFile = new File(previewDir.fsName + "/screen_pet_release_order_godot_v2_done.txt");
    var errorFile = new File(previewDir.fsName + "/screen_pet_release_order_godot_v2_error.txt");
    if (doneFile.exists) doneFile.remove();
    if (errorFile.exists) errorFile.remove();

    function rectSelection(doc, rect) {
        doc.selection.select([
            [rect[0], rect[1]],
            [rect[2], rect[1]],
            [rect[2], rect[3]],
            [rect[0], rect[3]]
        ]);
    }

    function addGroup(doc, name) {
        var group = doc.layerSets.add();
        group.name = name;
        return group;
    }

    var claimedRects = [];

    function intersectRect(a, b) {
        var left = Math.max(a[0], b[0]);
        var top = Math.max(a[1], b[1]);
        var right = Math.min(a[2], b[2]);
        var bottom = Math.min(a[3], b[3]);
        return right > left && bottom > top ? [left, top, right, bottom] : null;
    }

    function cropLayer(doc, sourceLayer, group, name, rect) {
        var layer = sourceLayer.duplicate();
        layer.name = name;
        doc.activeLayer = layer;
        rectSelection(doc, rect);
        doc.selection.invert();
        doc.selection.clear();
        doc.selection.deselect();
        // Transparent source pixels cannot be duplicated across layers: doing
        // so changes their alpha and color when Photoshop composites the PSD.
        // Earlier semantic layers own every overlap; later layers receive a
        // matching transparent hole, preserving the source composite exactly.
        for (var i = 0; i < claimedRects.length; i++) {
            var overlap = intersectRect(rect, claimedRects[i]);
            if (overlap !== null) {
                doc.activeLayer = layer;
                rectSelection(doc, overlap);
                doc.selection.clear();
                doc.selection.deselect();
            }
        }
        claimedRects.push(rect);
        layer.move(group, ElementPlacement.INSIDE);
        return layer;
    }

    function clearRect(doc, layer, rect) {
        doc.activeLayer = layer;
        rectSelection(doc, rect);
        doc.selection.clear();
        doc.selection.deselect();
    }

    function writeText(file, contents) {
        file.open("w");
        file.encoding = "UTF8";
        file.write(contents);
        file.close();
    }

    try {
        if (!sourceFile.exists) throw new Error("Missing source reference: " + sourceFile.fsName);

        var doc = app.open(sourceFile);
        doc.name = "screen_pet_release_order_godot_v2";
        var sourceLayer = doc.activeLayer;
        sourceLayer.name = "source_composite_working";

        var extractedRects = [];

        var referenceGroup = addGroup(doc, "00_reference_ignore");
        var referenceLayer = sourceLayer.duplicate();
        referenceLayer.name = "ref_fullscreen_original";
        referenceLayer.move(referenceGroup, ElementPlacement.INSIDE);
        referenceGroup.visible = false;

        var panelGroup = addGroup(doc, "01_ui_static_remainder");
        var panelRemainder = sourceLayer.duplicate();
        panelRemainder.name = "merge_unassigned_ui_details";
        panelRemainder.move(panelGroup, ElementPlacement.INSIDE);

        var headerGroup = addGroup(doc, "02_header");
        var titleRect = [48, 25, 760, 127];
        var modeRect = [1310, 25, 1580, 112];
        cropLayer(doc, sourceLayer, headerGroup, "merge_title_and_subtitle", titleRect);
        cropLayer(doc, sourceLayer, headerGroup, "label_mode_attack_timeline", modeRect);
        extractedRects.push(titleRect, modeRect);

        var timelineStaticGroup = addGroup(doc, "03_timeline_static");
        var trackRect = [165, 340, 1480, 384];
        var startRect = [132, 428, 270, 459];
        var endRect = [1415, 428, 1540, 459];
        cropLayer(doc, sourceLayer, timelineStaticGroup, "merge_timeline_track", trackRect);
        cropLayer(doc, sourceLayer, timelineStaticGroup, "label_battle_start", startRect);
        cropLayer(doc, sourceLayer, timelineStaticGroup, "label_round_end", endRect);
        extractedRects.push(trackRect, startRect, endRect);

        var markersGroup = addGroup(doc, "04_pet_markers");
        var cardLefts = [150, 327, 503, 680, 856, 1033, 1209, 1386];
        var badgeLefts = [126, 303, 480, 657, 834, 1011, 1188, 1365];
        var nameLefts = [151, 328, 505, 682, 859, 1036, 1212, 1389];
        for (var i = 0; i < 8; i++) {
            var markerGroup = markersGroup.layerSets.add();
            var markerIndex = i + 1;
            markerGroup.name = "component_pet_marker_" + (markerIndex < 10 ? "0" : "") + markerIndex;

            var badgeRect = [badgeLefts[i], 168, badgeLefts[i] + 54, 222];
            var cardRect = [cardLefts[i], 190, cardLefts[i] + 142, 337];
            var stemRect = [cardLefts[i] + 63, 329, cardLefts[i] + 72, 369];
            var nameRect = [nameLefts[i], 389, nameLefts[i] + 137, 432];

            cropLayer(doc, sourceLayer, markerGroup, "state_order_badge_" + markerIndex, badgeRect);
            cropLayer(doc, sourceLayer, markerGroup, "component_pet_frame_snapshot", cardRect);
            cropLayer(doc, sourceLayer, markerGroup, "merge_timeline_stem", stemRect);
            cropLayer(doc, sourceLayer, markerGroup, "label_pet_name", nameRect);
            extractedRects.push(badgeRect, cardRect, stemRect, nameRect);
        }

        var orderGroup = addGroup(doc, "05_order_summary");
        var orderRect = [205, 480, 1445, 532];
        cropLayer(doc, sourceLayer, orderGroup, "label_release_order", orderRect);
        extractedRects.push(orderRect);

        var statusGroup = addGroup(doc, "06_instruction_status");
        var statusRect = [259, 544, 1385, 609];
        cropLayer(doc, sourceLayer, statusGroup, "merge_status_panel_and_label", statusRect);
        extractedRects.push(statusRect);

        var actionGroup = addGroup(doc, "07_footer_actions");
        var resetRect = [530, 656, 793, 727];
        var playRect = [830, 656, 1115, 727];
        cropLayer(doc, sourceLayer, actionGroup, "state_reset_button_normal", resetRect);
        cropLayer(doc, sourceLayer, actionGroup, "state_play_button_normal", playRect);
        extractedRects.push(resetRect, playRect);

        for (var r = 0; r < extractedRects.length; r++) {
            clearRect(doc, panelRemainder, extractedRects[r]);
        }

        sourceLayer.remove();

        var psdOptions = new PhotoshopSaveOptions();
        psdOptions.layers = true;
        psdOptions.maximizeCompatibility = true;
        doc.saveAs(psdFile, psdOptions, true, Extension.LOWERCASE);

        var pngOptions = new PNGSaveOptions();
        pngOptions.compression = 6;
        pngOptions.interlaced = false;
        doc.saveAs(previewFile, pngOptions, true, Extension.LOWERCASE);

        writeText(doneFile, "PSD=" + psdFile.fsName + "\nPREVIEW=" + previewFile.fsName + "\n");
        doc.close(SaveOptions.DONOTSAVECHANGES);
    } catch (error) {
        writeText(errorFile, "Line " + error.line + ": " + error.message + "\n" + error.stack);
        throw error;
    } finally {
        app.preferences.rulerUnits = originalUnits;
        app.displayDialogs = originalDialogs;
    }
}());
