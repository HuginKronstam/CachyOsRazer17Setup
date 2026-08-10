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

ChartControls.PieChartControl {
    id: chart

    property alias headingSensor: sensor.sensorId
    property alias sensors: sensorsModel.sensors
    property alias sensorsModel: sensorsModel

    property int updateRateLimit

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
    chart.thickness: Kirigami.Units.largeSpacing

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
    background: Image {
        source: "file:///home/hugin/.local/share/plasma-widgets-shared/moon_gpu_lit.png"
        fillMode: Image.PreserveAspectFit
        anchors.centerIn: parent
        // >1.0 so the moon extends past the ring's outer edge instead of
        // sitting slightly inside it - the ring should read as sitting on
        // the moon's face, not the moon peeking out from behind the ring.
        width: parent.width * 1.15
        height: parent.height * 1.15
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
        // Overriding the shared blue->red default: cyan-blue sampled from
        // the wallpaper's neon skyline, shifting to the same pink used for
        // the moon's rim-light at the hottest end - keeps this widget's
        // whole palette tied to its actual background.
        coldColor: "#04CEFC"
        hotColor: "#CD1D71"
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

    // Carved-groove look: a light/dark stroke pair straddling each of the
    // ring's true edges (outer and inner), instead of one flat border - so
    // it reads as a channel sunk into the moon's surface rather than a
    // disc pasted on top. Thin and only barely anti-aliased, not blurred,
    // since a real groove has a crisp edge - the shading does the work.
    Item {
        id: ringBorderLayer
        anchors.fill: parent
        visible: false

        readonly property real outerD: Math.min(parent.width, parent.height)
        readonly property real innerD: outerD - 2 * chart.chart.thickness
        readonly property real strokeW: 1.2

        // Outer wall of the groove: highlight just outside the edge, shadow
        // just inside it.
        Rectangle {
            anchors.centerIn: parent
            width: ringBorderLayer.outerD + ringBorderLayer.strokeW
            height: width
            radius: width / 2
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.35)
            border.width: ringBorderLayer.strokeW
        }
        Rectangle {
            anchors.centerIn: parent
            width: ringBorderLayer.outerD - ringBorderLayer.strokeW
            height: width
            radius: width / 2
            color: "transparent"
            border.color: Qt.rgba(0, 0, 0, 0.55)
            border.width: ringBorderLayer.strokeW
        }
        // Inner wall of the groove: shadow just outside the edge (deeper
        // into the ring band), highlight just inside it (back up onto the
        // moon's surface).
        Rectangle {
            anchors.centerIn: parent
            width: ringBorderLayer.innerD + ringBorderLayer.strokeW
            height: width
            radius: width / 2
            color: "transparent"
            border.color: Qt.rgba(0, 0, 0, 0.55)
            border.width: ringBorderLayer.strokeW
        }
        Rectangle {
            anchors.centerIn: parent
            width: ringBorderLayer.innerD - ringBorderLayer.strokeW
            height: width
            radius: width / 2
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.35)
            border.width: ringBorderLayer.strokeW
        }
    }
    MultiEffect {
        anchors.fill: ringBorderLayer
        source: ringBorderLayer
        blurEnabled: true
        blur: 0.04
        blurMax: 3
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
