// Tints an image to match the desktop wallpaper's ambient color at a known
// screen location. Reads the actual wallpaper file (not a screenshot), crops
// it to the given logical-desktop rect, and downsamples that crop to a
// single pixel via Canvas to get an average color - then applies it as a
// MultiEffect colorization over the source image, preserving its own
// shading/detail instead of flattening it with a plain color wash.
//
// widgetLogicalRect/logicalScreenSize come from this widget's entry in
// ItemGeometries-<res> in plasma-org.kde.plasma.desktop-appletsrc. If you
// move the widget, resize the screen, or change the wallpaper, update the
// properties where this component is instantiated - re-detecting any of
// that live is not worth the complexity for a background image.
import QtQuick
import QtQuick.Effects

Item {
    id: root

    property url imageSource
    property url wallpaperSource
    property rect widgetLogicalRect
    property size logicalScreenSize: Qt.size(1920, 1080)
    property real colorization: 0.45
    property real brightness: 0.0
    property real fillFactor: 0.9

    property color sampledColor: "#808080"

    Image {
        id: sourceImage
        source: root.imageSource
        fillMode: Image.PreserveAspectFit
        anchors.centerIn: parent
        width: parent.width * root.fillFactor
        height: parent.height * root.fillFactor
        visible: false
    }

    MultiEffect {
        anchors.fill: sourceImage
        source: sourceImage
        colorization: root.colorization
        colorizationColor: root.sampledColor
        brightness: root.brightness
    }

    Image {
        id: wallpaperImg
        source: root.wallpaperSource
        asynchronous: true
        visible: false
        onStatusChanged: if (status === Image.Ready) sampler.requestPaint()
    }

    Canvas {
        id: sampler
        width: 1
        height: 1
        onPaint: {
            if (wallpaperImg.status !== Image.Ready) return
            var ctx = getContext("2d")
            var scale = wallpaperImg.sourceSize.width / root.logicalScreenSize.width
            var r = root.widgetLogicalRect
            ctx.drawImage(wallpaperImg, r.x * scale, r.y * scale, r.width * scale, r.height * scale, 0, 0, 1, 1)
            var d = ctx.getImageData(0, 0, 1, 1).data
            root.sampledColor = Qt.rgba(d[0] / 255, d[1] / 255, d[2] / 255, 1.0)
        }
    }
}
