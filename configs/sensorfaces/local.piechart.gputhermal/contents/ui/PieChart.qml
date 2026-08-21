/*
    SPDX-FileCopyrightText: 2019 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2019 David Edmundson <davidedmundson@kde.org>
    SPDX-FileCopyrightText: 2019 Arjen Hiemstra <ahiemstra@heimr.nl>
    SPDX-FileCopyrightText: 2019 Kai Uwe Broulik <kde@broulik.de>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import org.kde.ksysguard.sensors as Sensors
import org.kde.ksysguard.faces as Faces

import org.kde.quickcharts as Charts
import org.kde.quickcharts.controls as ChartControls
import QtQuick.Effects

import "file:///home/hugin/.local/share/plasma-widgets-shared"
import "file:///home/hugin/.local/share/plasma-widgets-shared/gpu_widget_config.js" as GpuConfigModule

ChartControls.PieChartControl {
    id: chart

    property alias headingSensor: sensor.sensorId
    property alias sensors: sensorsModel.sensors
    property alias sensorsModel: sensorsModel

    property int updateRateLimit

    // Single source of truth for values shared with the bake scripts
    // (bake_moon.py, bake_gpu_overlay.py) - both sides read the same file
    // instead of hand-copied constants that drift out of sync silently. A
    // script-module import (not XMLHttpRequest - local-file XHR is disabled
    // by default in Qt6) - see gpu_widget_config.js and
    // ~/.local/share/scripts/widgets/widget_config.py, which parses the
    // same file on the Python side.
    readonly property var gpuConfig: GpuConfigModule.gpuWidgetConfig

    // How much bigger the moon renders than the ring's own bounding box -
    // referenced by both the background Image and the overlay Image below.
    readonly property real moonFillFactor: gpuConfig.moonFillFactor
    // Ring thickness as a fraction of the ring's own diameter, matching
    // exactly how bake_gpu_overlay.py computes its bevel band - so resizing
    // the widget scales the wedge and the baked overlay together instead of
    // one being a fixed theme-based pixel value (chart.thickness used to be
    // Kirigami.Units.largeSpacing) and the other a proportional guess.
    readonly property real ringThicknessRatio: gpuConfig.ringThicknessRatio


    Layout.minimumHeight: root.formFactor == Faces.SensorFace.Vertical ? width : Kirigami.Units.gridUnit

    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

    readonly property real rangeFrom: root.controller.faceConfiguration.rangeFrom *
                                      root.controller.faceConfiguration.rangeFromMultiplier

    readonly property real rangeTo: root.controller.faceConfiguration.rangeTo *
                                    root.controller.faceConfiguration.rangeToMultiplier

    chart.smoothEnds: root.controller.faceConfiguration.smoothEnds
    chart.fromAngle: root.controller.faceConfiguration.fromAngle
    chart.toAngle: root.controller.faceConfiguration.toAngle
    // Unqualified (not "chart.width" etc.) - within the root's own top-level
    // bindings, "chart" resolves to the inherited chart:pie alias property
    // (shadowing our own id), not our root id, so "chart.ringThicknessRatio"
    // silently returned undefined (pie has no such property) and broke the
    // wedge's thickness entirely. Bare property names resolve directly to
    // our own root without that ambiguity.
    chart.thickness: Math.min(width, height) * ringThicknessRatio

    range {
        from: chart.rangeFrom
        to: chart.rangeTo
        automatic: root.controller.faceConfiguration.rangeAuto
    }

    chart.backgroundColor: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.1)

    // Sits behind contentItem (the ring + center label) - Control's built-in
    // background hook, so no z-ordering fiddling needed.
    //
    // This is a statically pre-lit asset (see .../scratchpad/bake_moon.py,
    // and moon_gpu_lit.png here in plasma-widgets-shared) rather than a live
    // per-pixel shader effect - the rim-light direction/color was picked by
    // eye against this specific wallpaper (full diagonal southwest, neon
    // pink sampled from the character's hair highlight). True per-pixel
    // directional lighting needs a custom GPU shader (QML's MultiEffect only
    // does flat/global colorization, not per-pixel surface-normal math), and
    // a live "sample any wallpaper automatically" version would need a lot
    // more tuning to be reliable - baking a calibrated result is simpler and
    // was the agreed tradeoff for now. Rerun bake_moon.py with new angle/
    // color values if you change wallpaper or want to retune the look.
    //
    // Deliberately smaller than the ring (moonImageScale < 1, decoupled from
    // the overlay's own moonFillFactor) - the moon reads as a distinct
    // glowing sphere with the ring floating around it as a halo/reticle,
    // rather than the ring sitting on the moon's surface. That was the
    // original design for the old realistic moon photo, but this stylized
    // neon-glow moon already does its own "edge glow" as part of the art,
    // so stacking the ring's bevel glow on the same edge just made them
    // compete - separating them reads cleaner.
    background: Image {
        source: "file:///home/hugin/.local/share/plasma-widgets-shared/moon_gpu_lit.png"
        fillMode: Image.PreserveAspectFit
        anchors.centerIn: parent
        width: parent.width * chart.gpuConfig.moonImageScale
        height: parent.height * chart.gpuConfig.moonImageScale
    }

    Sensors.SensorDataModel {
        id: sensorsModel
        sensors: root.controller.highPrioritySensorIds
        updateRateLimit: chart.updateRateLimit
        sensorLabels: root.controller.sensorLabels
    }

    // Wedge fill is smoothed (see SmoothedValue.qml) rather than fed the raw
    // instantaneous reading directly, to cut down on jitter.
    Sensors.Sensor {
        id: valueSensor
        sensorId: root.controller.highPrioritySensorIds.length > 0 ? root.controller.highPrioritySensorIds[0] : ""
        updateRateLimit: chart.updateRateLimit
    }
    SmoothedValue {
        id: smoothedUsage
        target: valueSensor.value || 0
    }
    valueSources: Charts.ArraySource {
        array: [smoothedUsage.value]
    }
    chart.nameSource: Charts.ModelSource {
        roleName: "Name";
        model: sensorsModel;
        indexColumns: true
    }
    chart.shortNameSource: Charts.ModelSource {
        roleName: "ShortName";
        model: sensorsModel;
        indexColumns: true
    }
    // Temperature-driven color, independent of which sensors are actually
    // plotted as wedges. Color math lives in the shared ThermalColor.qml so
    // the CPU/GPU/Fan widgets don't each keep their own copy. Also smoothed,
    // though temperature is naturally much less jittery than usage.
    SmoothedValue {
        id: smoothedTemp
        target: tempSensor.value || 0
    }
    ThermalColor {
        id: thermal
        value: smoothedTemp.value
        // Overriding the shared blue->red default - cyan-blue sampled from
        // the wallpaper's neon skyline, shifting to orange at the hottest
        // end (not pink - pink is the moon's own rim-light color, and using
        // it here made the hot wedge blend into the moon's glow instead of
        // reading as a distinct object). Values from gpuConfig, not
        // hardcoded, same single-source-of-truth reasoning as moonFillFactor.
        coldColor: chart.gpuConfig.coldColorHex
        hotColor: chart.gpuConfig.hotColorHex
    }

    chart.colorSource: Charts.ArraySource {
        array: {
            var colors = []
            for (var i = 0; i < root.controller.highPrioritySensorIds.length; ++i) {
                colors.push(thermal.color)
            }
            return colors
        }
    }

    Sensors.Sensor {
        id: tempSensor
        sensorId: "gpu/gpu0/temperature"
        updateRateLimit: chart.updateRateLimit
    }

    Sensors.Sensor {
        id: sensor
        sensorId: root.controller.totalSensors.length > 0 ? root.controller.totalSensors[0] : ""
        updateRateLimit: chart.updateRateLimit
    }

    // All the structural/decorative bezel elements (highlight/shadow bevel,
    // end caps at the gap, tick marks, mounting brackets) are baked into
    // one static overlay PNG (see .../scripts/widgets/bake_gpu_overlay.py)
    // rather than built from QML shapes - none of it needs to track live
    // sensor data, only the same fixed ring/moon geometry relationship the
    // moon image itself uses (moonFillFactor), and fighting QML rotation/
    // clipping math for all of this repeatedly cost far more time than it
    // was worth. Trade-off: this is calibrated against the gap
    // (fromAngle/toAngle) that was configured when it was baked - rerun the
    // script if you reconfigure the gap significantly.
    Image {
        id: gpuOverlay
        source: "file:///home/hugin/.local/share/plasma-widgets-shared/gpu_overlay.png"
        fillMode: Image.PreserveAspectFit
        anchors.centerIn: parent
        width: parent.width * chart.moonFillFactor
        height: parent.height * chart.moonFillFactor
    }
    MultiEffect {
        anchors.fill: gpuOverlay
        source: gpuOverlay

        // Cast a real shadow onto the moon below the bezel, offset toward
        // northeast (opposite the 225deg/southwest light) - the key cue
        // that sells "this is a physical bezel mounted above the surface"
        // rather than a flat graphic sitting on it. (A baked-in shadow was
        // tried first - Image.transform's AFFINE offset produced real
        // artifacts, a bitten-out chunk of the moon's edge and color
        // bleeding past its silhouette - this live version is simpler and
        // doesn't have that problem.)
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.7)
        shadowOpacity: 0.7
        shadowBlur: 0.4
        shadowHorizontalOffset: 3
        shadowVerticalOffset: -3
    }

    UsedTotalDisplay {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width

        usedSensor: root.controller.totalSensors.length > 0 ? root.controller.totalSensors[0] : ""
        totalSensor: root.controller.totalSensors.length > 1 ? root.controller.totalSensors[1] : ""

        contentMargin: chart.chart.thickness
        updateRateLimit: chart.updateRateLimit
    }
}
