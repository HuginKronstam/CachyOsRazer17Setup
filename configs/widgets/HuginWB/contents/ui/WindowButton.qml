import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

PC3.ToolButton {
    id: button

    // Empty string = follow the theme (the whole point of PC3.ToolButton
    // over a hand-rolled Rectangle+MouseArea: Kirigami.Theme.colorSet below
    // properly scopes Kirigami.Theme.textColor to the actual Plasma color
    // scheme, and the button's own background/hover/press states are
    // themed automatically the same way every other Plasma panel button is
    // - this is what the earlier hand-rolled version was missing entirely.
    property string iconColorOverride: ""
    property bool active: false
    property string accessibleName: ""

    flat: true
    Kirigami.Theme.colorSet: Kirigami.Theme.Button

    icon.name: "" // set by the caller via the icon.name grouped property
    icon.color: iconColorOverride !== "" ? iconColorOverride : Kirigami.Theme.textColor

    enabled: active
    // Layout size stays fixed regardless of active (opacity doesn't affect
    // layout) - this is what keeps the reserved space blank instead of
    // collapsing when there's no active window.
    opacity: active ? 1 : 0

    display: PC3.ToolButton.IconOnly
    Accessible.name: accessibleName
}
