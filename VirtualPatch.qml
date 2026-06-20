import QtQuick

Item {
    id: root

    property real minU: 0.0
    property real maxU: 0.0
    property real minV: 0.0
    property real maxV: 0.0

    property var matrixSizes: [
        [2, 1],
        [3, 2],
        [5, 3],
        [10, 5],
        [20, 10],
        [40, 20],
        [80, 40],
        [160, 80]
    ]

    property int zLevel: {
        if (maxU <= minU || maxV <= minV) return 0;
        let widthU = maxU - minU;
        let desired_global_width = 2048.0 / widthU;
        
        let z = 0;
        for (let i = 0; i < matrixSizes.length; i++) {
            if (matrixSizes[i][0] * 512 >= desired_global_width) {
                z = i;
                break;
            }
        }
        if (z === 0 && matrixSizes[7][0] * 512 < desired_global_width) z = 7;
        return z;
    }
    
    property int numTilesX: matrixSizes[zLevel][0]
    property int numTilesY: matrixSizes[zLevel][1]

    property real patchWidthPx: (maxU - minU) * numTilesX * 512
    property real patchHeightPx: (maxV - minV) * numTilesY * 512

    ListModel {
        id: tilesModel
    }

    onMinUChanged: updateTiles()
    onMaxUChanged: updateTiles()
    onMinVChanged: updateTiles()
    onMaxVChanged: updateTiles()

    function updateTiles() {
        if (maxU <= minU || maxV <= minV) {
            tilesModel.clear();
            return;
        }
        
        let px_minX = minU * numTilesX * 512;
        let px_maxX = maxU * numTilesX * 512;
        let px_minY = minV * numTilesY * 512;
        let px_maxY = maxV * numTilesY * 512;

        let tx_start = Math.max(0, Math.floor(px_minX / 512));
        let tx_end = Math.min(numTilesX - 1, Math.floor(px_maxX / 512));
        let ty_start = Math.max(0, Math.floor(px_minY / 512));
        let ty_end = Math.min(numTilesY - 1, Math.floor(px_maxY / 512));

        // Prevent too many tiles if something goes wrong
        if ((tx_end - tx_start + 1) * (ty_end - ty_start + 1) > 100) return;

        // Build a set of what is currently in the model
        let currentTiles = {};
        for (let i = 0; i < tilesModel.count; i++) {
            let item = tilesModel.get(i);
            currentTiles[item.zLevel + "_" + item.tx + "_" + item.ty] = i;
        }

        let newTiles = {};

        for (let tx = tx_start; tx <= tx_end; tx++) {
            for (let ty = ty_start; ty <= ty_end; ty++) {
                let key = root.zLevel + "_" + tx + "_" + ty;
                newTiles[key] = true;
                
                if (currentTiles[key] === undefined) {
                    // Not in model, add it!
                    tilesModel.append({
                        "tx": tx,
                        "ty": ty,
                        "zLevel": root.zLevel
                    });
                }
            }
        }

        // Remove old tiles that are no longer needed
        // Iterate backwards because we are removing items
        for (let i = tilesModel.count - 1; i >= 0; i--) {
            let item = tilesModel.get(i);
            let key = item.zLevel + "_" + item.tx + "_" + item.ty;
            if (newTiles[key] === undefined) {
                tilesModel.remove(i);
            }
        }
    }

    Item {
        id: patchContainer
        width: Math.max(1, root.patchWidthPx)
        height: Math.max(1, root.patchHeightPx)
        visible: false

        Repeater {
            model: tilesModel
            Image {
                x: (model.tx / root.numTilesX - root.minU) * root.numTilesX * 512
                y: (model.ty / root.numTilesY - root.minV) * root.numTilesY * 512
                width: 512
                height: 512
                source: Qt.resolvedUrl("tiles/" + model.zLevel + "/" + model.tx + "/" + model.ty + ".jpeg")
                asynchronous: true
                fillMode: Image.Stretch
            }
        }
    }

    ShaderEffectSource {
        id: patchSource
        sourceItem: patchContainer
        hideSource: true
        live: true
    }

    property var textureProvider: patchSource
}
