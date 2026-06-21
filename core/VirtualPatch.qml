import QtQuick

Item {
    id: root

    property real minU: 0
    property real maxU: 0
    property real minV: 0
    property real maxV: 0
    property string tileServerUrl: ""
    property var matrixSizes: [[1, 1], [2, 2], [4, 4], [8, 8], [16, 16], [32, 32], [64, 64], [128, 128], [256, 256], [512, 512]]
    property int zLevel: {
        if (maxU <= minU || maxV <= minV)
            return 0;

        let widthU = maxU - minU;
        let desired_global_width = 2048 / widthU;
        let z = 0;
        for (let i = 0; i < matrixSizes.length; i++) {
            if (matrixSizes[i][0] * 512 >= desired_global_width) {
                z = i;
                break;
            }
        }
        if (z === 0 && matrixSizes[9][0] * 256 < desired_global_width)
            z = 9;

        return z;
    }
    property int numTilesX: matrixSizes[zLevel][0]
    property int numTilesY: matrixSizes[zLevel][1]
    property real patchWidthPx: (maxU - minU) * numTilesX * 256
    property real patchHeightPx: (maxV - minV) * numTilesY * 256
    property int maxTiles: 600
    property var activeTiles: ({
    })
    property var freeTiles: []
    property var textureProvider: patchSource

    function updateTiles() {
        if (maxU <= minU || maxV <= minV) {
            for (let key in activeTiles) {
                let idx = activeTiles[key];
                let item = tileRepeater.itemAt(idx);
                if (item)
                    item.tx = -1;

                freeTiles.push(idx);
            }
            activeTiles = {
            };
            return ;
        }
        let px_minX = minU * numTilesX * 256;
        let px_maxX = maxU * numTilesX * 256;
        let px_minY = minV * numTilesY * 256;
        let px_maxY = maxV * numTilesY * 256;
        let tx_start = Math.max(0, Math.floor(px_minX / 256));
        let tx_end = Math.min(numTilesX - 1, Math.floor(px_maxX / 256));
        let ty_start = Math.max(0, Math.floor(px_minY / 256));
        let ty_end = Math.min(numTilesY - 1, Math.floor(px_maxY / 256));
        if ((tx_end - tx_start + 1) * (ty_end - ty_start + 1) > maxTiles)
            return ;

        let newTiles = {
        };
        for (let tx = tx_start; tx <= tx_end; tx++) {
            for (let ty = ty_start; ty <= ty_end; ty++) {
                let key = root.zLevel + "_" + tx + "_" + ty;
                newTiles[key] = true;
            }
        }
        let newActiveTiles = {
        };
        let activeKeys = Object.keys(activeTiles);
        for (let i = 0; i < activeKeys.length; i++) {
            let key = activeKeys[i];
            let idx = activeTiles[key];
            let item = tileRepeater.itemAt(idx);
            if (!item)
                continue;

            let tMinU = item.tx / item.tItemNumX;
            let tMaxU = (item.tx + 1) / item.tItemNumX;
            let tMinV = item.ty / item.tItemNumY;
            let tMaxV = (item.ty + 1) / item.tItemNumY;
            let overlapU = (tMinU <= maxU && tMaxU >= minU);
            let overlapV = (tMinV <= maxV && tMaxV >= minV);
            let isCurrentZoom = (item.tz === root.zLevel);
            let distZoom = Math.abs(item.tz - root.zLevel);
            if (!overlapU || !overlapV || distZoom > 1 || (isCurrentZoom && newTiles[key] === undefined)) {
                item.tx = -1;
                freeTiles.push(idx);
            } else {
                newActiveTiles[key] = idx;
            }
        }
        activeTiles = newActiveTiles;
        for (let tx = tx_start; tx <= tx_end; tx++) {
            for (let ty = ty_start; ty <= ty_end; ty++) {
                let key = root.zLevel + "_" + tx + "_" + ty;
                if (activeTiles[key] === undefined) {
                    if (freeTiles.length > 0) {
                        let idx = freeTiles.pop();
                        activeTiles[key] = idx;
                        let item = tileRepeater.itemAt(idx);
                        if (item) {
                            item.tz = root.zLevel;
                            item.tItemNumX = root.numTilesX;
                            item.tItemNumY = root.numTilesY;
                            item.tx = tx;
                            item.ty = ty;
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        let freeList = [];
        for (let i = 0; i < maxTiles; i++) {
            freeList.push(i);
        }
        root.freeTiles = freeList;
    }
    onMinUChanged: updateTiles()
    onMaxUChanged: updateTiles()
    onMinVChanged: updateTiles()
    onMaxVChanged: updateTiles()

    Item {
        id: patchContainer

        width: Math.max(1, root.patchWidthPx)
        height: Math.max(1, root.patchHeightPx)
        visible: false

        Repeater {
            id: tileRepeater

            model: root.maxTiles

            Image {
                property int tx: -1
                property int ty: -1
                property int tz: -1
                property int tItemNumX: 1
                property int tItemNumY: 1

                visible: tx !== -1
                x: tx !== -1 ? (tx / tItemNumX - root.minU) * root.numTilesX * 256 : 0
                y: ty !== -1 ? (ty / tItemNumY - root.minV) * root.numTilesY * 256 : 0
                width: tx !== -1 ? 256 * (root.numTilesX / tItemNumX) : 0
                height: ty !== -1 ? 256 * (root.numTilesY / tItemNumY) : 0
                z: tz
                source: tx !== -1 && root.tileServerUrl !== "" ? (root.tileServerUrl + "/" + tz + "/" + tx + "/" + ty) : ""
                asynchronous: true
                sourceSize: Qt.size(256, 256)
                cache: false
                fillMode: Image.Stretch
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.InOutQuad
                    }

                }

            }

        }

    }

    ShaderEffectSource {
        id: patchSource

        sourceItem: patchContainer
        hideSource: true
        live: true
        textureSize: Qt.size(2048, 2048)
        format: ShaderEffectSource.RGB
    }

}
