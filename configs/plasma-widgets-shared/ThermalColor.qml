// Shared cold->hot color mapping used by all our custom thermal widgets
// (CPU piechart, GPU piechart, Fan monitor). Edit the defaults here once
// and every widget that imports this file picks up the change - that's
// the whole point of pulling it out of each widget individually.
//
// Note: Kirigami.ColorUtils.linearInterpolation is NOT a plain RGB blend
// between two arbitrary hues (verified: even at ratio 1.0 it barely moves
// off the first color), so we blend channels by hand here instead.
import QtQuick

QtObject {
    property real value: 0
    property real fromValue: 45
    property real toValue: 85
    property color coldColor: "#3DAEE9"
    property color hotColor: "#ED1515"

    readonly property real ratio: Math.max(0, Math.min(1, (value - fromValue) / (toValue - fromValue)))

    readonly property color color: Qt.rgba(
        coldColor.r + (hotColor.r - coldColor.r) * ratio,
        coldColor.g + (hotColor.g - coldColor.g) * ratio,
        coldColor.b + (hotColor.b - coldColor.b) * ratio,
        1.0
    )
}
