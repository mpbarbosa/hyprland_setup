import QtQuick

// One row of the picker: what the setup looks like, what it is called, and what it
// changes beyond colour.
Rectangle {
    id: card

    required property var setup
    required property var uiColors
    required property bool active
    required property bool selected

    signal clicked()

    radius: 8
    color: selected ? Qt.alpha(uiColors.accent, 0.16)
                    : hover.hovered ? Qt.alpha(uiColors.ink, 0.06)
                                    : "transparent"
    border.width: 1
    border.color: selected ? Qt.alpha(uiColors.accent, 0.55) : "transparent"

    HoverHandler { id: hover }
    TapHandler { onTapped: card.clicked() }

    BarPreview {
        id: thumb
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 10
        width: 128
        height: 44
        colors: card.setup.colors
        position: card.setup.position
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: thumb.right
        anchors.leftMargin: 14
        anchors.right: dot.left
        anchors.rightMargin: 10
        spacing: 3

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: card.setup.name
            color: card.uiColors.ink
            font.family: "Hack Nerd Font"
            font.pixelSize: 14
            font.bold: card.active
        }

        // Says what the setup actually changes. A stylesheet on its own is a recolour; a
        // config-<name>.jsonc beside it means the module layout moves too, which is a much
        // bigger commitment than a new accent and worth calling out before the bar restarts.
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: card.setup.ownConfig
                  ? "own layout · " + card.setup.position
                  : (card.setup.name === "default" ? "base config and stylesheet" : "recolours the base layout")
            color: card.uiColors["ink-muted"]
            font.family: "Hack Nerd Font"
            font.pixelSize: 11
        }
    }

    // Marks the running setup in place rather than reordering the list, so entries keep a
    // stable position between invocations and muscle memory keeps working.
    Rectangle {
        id: dot
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 14
        width: 8
        height: 8
        radius: 4
        visible: card.active
        color: card.uiColors["accent-alt"]
    }
}
