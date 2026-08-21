import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root

    property bool hasActiveWindow: false
    property bool activeIsMaximized: false
    property real buttonSize: 22
    property bool horizontal: true

    property string minimizeIcon: "window-minimize-symbolic"
    property string maximizeIcon: "window-maximize-symbolic"
    property string restoreIcon: "window-restore-symbolic"
    property string closeIcon: "window-close-symbolic"
    // Empty = follow the theme, matching WindowButton.iconColorOverride
    property string minimizeColor: ""
    property string maximizeColor: ""
    property string closeColor: ""

    // Blank by default (v1) - set to a valid icon name to show something
    // in the reserved space when there's no active window
    property string placeholderIconName: ""

    signal minimizeClicked()
    signal maximizeClicked()
    signal closeClicked()

    // The only thing that determines this item's reported size - must
    // never reference hasActiveWindow, or the panel layout would jump
    // around instead of keeping the space reserved.
    readonly property real contentLength: buttonSize * 3 + spacingLength * 2
    readonly property real spacingLength: Kirigami.Units.smallSpacing

    implicitWidth: horizontal ? contentLength : buttonSize
    implicitHeight: horizontal ? buttonSize : contentLength
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.minimumWidth: implicitWidth
    Layout.minimumHeight: implicitHeight
    Layout.maximumWidth: implicitWidth
    Layout.maximumHeight: implicitHeight

    GridLayout {
        anchors.fill: parent
        rows: root.horizontal ? 1 : 3
        columns: root.horizontal ? 3 : 1
        rowSpacing: root.spacingLength
        columnSpacing: root.spacingLength

        WindowButton {
            Layout.preferredWidth: root.buttonSize
            Layout.preferredHeight: root.buttonSize
            icon.name: root.minimizeIcon
            icon.width: root.buttonSize
            icon.height: root.buttonSize
            iconColorOverride: root.minimizeColor
            active: root.hasActiveWindow
            accessibleName: "Minimize"
            onClicked: root.minimizeClicked()
        }

        WindowButton {
            Layout.preferredWidth: root.buttonSize
            Layout.preferredHeight: root.buttonSize
            icon.name: root.activeIsMaximized ? root.restoreIcon : root.maximizeIcon
            icon.width: root.buttonSize
            icon.height: root.buttonSize
            iconColorOverride: root.maximizeColor
            active: root.hasActiveWindow
            accessibleName: root.activeIsMaximized ? "Restore" : "Maximize"
            onClicked: root.maximizeClicked()
        }

        WindowButton {
            Layout.preferredWidth: root.buttonSize
            Layout.preferredHeight: root.buttonSize
            icon.name: root.closeIcon
            icon.width: root.buttonSize
            icon.height: root.buttonSize
            iconColorOverride: root.closeColor
            active: root.hasActiveWindow
            accessibleName: "Close"
            onClicked: root.closeClicked()
        }
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: Math.round(root.buttonSize * 0.6)
        height: width
        source: root.placeholderIconName
        color: Kirigami.Theme.disabledTextColor
        visible: !root.hasActiveWindow && root.placeholderIconName !== ""
    }
}
