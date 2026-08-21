pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    readonly property bool horizontal: plasmoid.formFactor === PlasmaCore.Types.Horizontal
    readonly property string visibilityPolicy: plasmoid.configuration.visibilityPolicy

    // The actual panel containment (BasicAppletContainer.qml) reads
    // applet.Layout.minimumWidth/preferredWidth/maximumWidth (the QtQuick
    // Layouts attached properties) - confirmed by reading its source. It
    // does NOT read bare minimumWidth/minimumHeight properties on the
    // applet the way an older (Plasma 5-era) applet might.
    //
    // The PRIMARY axis (length - width when horizontal) is pinned to a
    // fixed value from buttonRow's own implicit size and never stretches -
    // that's what keeps the reserved space fixed instead of collapsing or
    // growing with hasActiveWindow.
    //
    // The PERPENDICULAR axis (thickness - height when horizontal) uses
    // Layout.fillHeight/fillWidth instead of a fixed value, so the row
    // stretches us to match the real panel thickness. This is deliberately
    // NOT read from our own buttonRow size - Plasmoid.containment.height
    // doesn't exist as a readable property (confirmed: assigning it here
    // crashed with "Unable to assign [undefined] to double"), and pinning
    // our own Layout.preferredHeight to a value that itself depends on
    // buttonSize-from-root.height would be circular. fillHeight/fillWidth
    // lets the row assign root.height/width externally instead, which
    // buttonSize below can then safely read back from.
    Layout.fillWidth: !horizontal
    Layout.fillHeight: horizontal

    Layout.minimumWidth: horizontal ? buttonRow.implicitWidth : 0
    Layout.preferredWidth: horizontal ? buttonRow.implicitWidth : -1
    Layout.maximumWidth: horizontal ? buttonRow.implicitWidth : Infinity

    Layout.minimumHeight: horizontal ? 0 : buttonRow.implicitHeight
    Layout.preferredHeight: horizontal ? -1 : buttonRow.implicitHeight
    Layout.maximumHeight: horizontal ? Infinity : buttonRow.implicitHeight

    // While the panel itself is in edit mode (Add Widgets / arranging
    // applets), force the buttons to show regardless of visibilityPolicy or
    // whether a window is actually active - so the widget's real footprint
    // is visible while placing/arranging it, matching how every other
    // panel applet behaves in edit mode.
    readonly property bool inEditMode: Plasmoid.containment && Plasmoid.containment.corona && Plasmoid.containment.corona.editMode

    // AlwaysVisible: show buttons whenever any window exists, even if focus
    // is currently on nothing (e.g. clicked the desktop).
    // ActiveWindow (default): show buttons only while a window is actually
    // active/focused.
    // ActiveMaximizedWindow: show buttons only while the active window is
    // also maximized.
    readonly property bool showButtons: {
        if (inEditMode)
            return true;
        if (visibilityPolicy === "AlwaysVisible")
            return tasksBridge.taskCount > 0;
        if (visibilityPolicy === "ActiveMaximizedWindow")
            return tasksBridge.hasActiveWindow && tasksBridge.activeIsMaximized;
        return tasksBridge.hasActiveWindow;
    }

    TasksModelBridge {
        id: tasksBridge
    }

    // .local override: empty (the default) means "follow the theme" - these
    // read straight from this plasmoid's own per-user config (kcfg), set via
    // kwriteconfig6 as documented in config/main.xml. No file-reading of any
    // kind is involved (QML's file:// XMLHttpRequest GET/PUT are both
    // disabled by default and would silently never work under plasmashell).
    ButtonRow {
        id: buttonRow
        anchors.fill: parent

        horizontal: root.horizontal
        hasActiveWindow: root.showButtons
        activeIsMaximized: tasksBridge.activeIsMaximized

        // 80% of the actual taskbar thickness. Safe to read root.height/width
        // here (unlike a naive first attempt) because Layout.fillHeight
        // above makes the panel's row assign root.height externally, not
        // derived from our own preferredHeight - so there's no cycle.
        // Falls back to a fixed constant before that first assignment
        // happens (root.height/width starts at 0).
        buttonSize: (root.horizontal ? root.height : root.width) > 0
            ? Math.round((root.horizontal ? root.height : root.width) * 0.8)
            : Kirigami.Units.iconSizes.smallMedium

        minimizeIcon: plasmoid.configuration.overrideMinimizeIcon || "window-minimize-symbolic"
        maximizeIcon: plasmoid.configuration.overrideMaximizeIcon || "window-maximize-symbolic"
        restoreIcon: plasmoid.configuration.overrideRestoreIcon || "window-restore-symbolic"
        closeIcon: plasmoid.configuration.overrideCloseIcon || "window-close-symbolic"

        minimizeColor: plasmoid.configuration.overrideMinimizeColor
        maximizeColor: plasmoid.configuration.overrideMaximizeColor
        closeColor: plasmoid.configuration.overrideCloseColor

        onMinimizeClicked: tasksBridge.toggleMinimize()
        onMaximizeClicked: tasksBridge.toggleMaximize()
        onCloseClicked: tasksBridge.close()
    }
}
