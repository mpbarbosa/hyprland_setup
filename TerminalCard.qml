import QtQuick

// One terminal in the panel's terminals page.
Rectangle {
    id: card

    required property var terminal      // { id, name, exec }
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

    Text {
        id: glyph
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 16
        // From an explicit codepoint, not a literal glyph. Nerd Font private-use
        // characters get silently stripped in transit — this one already came through as
        // an empty string once, which is the trap waybar/gen_waybar.py exists to avoid.
        text: String.fromCodePoint(0xf120)     // nf-fa-terminal
        color: card.uiColors.accent
        font.family: "Hack Nerd Font"
        font.pixelSize: 18
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: glyph.right
        anchors.leftMargin: 14
        anchors.right: dot.left
        anchors.rightMargin: 10
        spacing: 3

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: card.terminal.name
            color: card.uiColors.ink
            font.family: "Hack Nerd Font"
            font.pixelSize: 14
            font.bold: card.active
        }

        // The desktop id as well as the command, because two entries here are both simply
        // called "Terminal" — GNOME's and Ptyxis's — and the name alone cannot tell them
        // apart. The command is what actually gets run, so it is the honest label.
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: card.terminal.id + " · " + card.terminal.exec
            color: card.uiColors["ink-muted"]
            font.family: "Hack Nerd Font"
            font.pixelSize: 11
        }
    }

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
