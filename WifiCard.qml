import QtQuick

// One network in the panel's Wi-Fi page.
Rectangle {
    id: card

    required property var network        // { ssid, signal, security, saved, active }
    required property var uiColors
    required property bool active
    required property bool selected

    signal clicked()

    // nmcli reports 0-100. Four bars is what every other client shows, so the thresholds
    // are the usual quarters rather than anything derived from dBm.
    readonly property int bars: network.signal >= 75 ? 4
                              : network.signal >= 50 ? 3
                              : network.signal >= 25 ? 2 : 1
    readonly property bool secured: network.security !== ""

    radius: 8
    color: selected ? Qt.alpha(uiColors.accent, 0.16)
                    : hover.hovered ? Qt.alpha(uiColors.ink, 0.06)
                                    : "transparent"
    border.width: 1
    border.color: selected ? Qt.alpha(uiColors.accent, 0.55) : "transparent"

    HoverHandler { id: hover }
    TapHandler { onTapped: card.clicked() }

    // Drawn rather than set from a Nerd Font codepoint, for BarPreview's reason and one
    // more: the wifi-strength glyphs live in the Material Design private-use block, so a
    // font built without that block renders four different networks as four identical
    // tofu boxes — and strength is the one thing this row exists to show.
    Row {
        id: meter
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 16
        spacing: 2

        Repeater {
            model: 4

            Rectangle {
                required property int index
                width: 3
                height: 5 + index * 4
                anchors.bottom: parent.bottom
                radius: 1
                color: index < card.bars ? card.uiColors.accent
                                         : Qt.alpha(card.uiColors["ink-faint"], 0.35)
            }
        }
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: meter.right
        anchors.leftMargin: 14
        anchors.right: dot.left
        anchors.rightMargin: 10
        spacing: 3

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: card.network.ssid
            color: card.uiColors.ink
            font.family: "Hack Nerd Font"
            font.pixelSize: 14
            font.bold: card.active
        }

        // What Enter is about to do, which is the question this page is really asked. A
        // saved network connects straight away; an unsaved secured one stops to ask for a
        // password; an open one just joins, and saying so is a warning as much as a label.
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: (card.secured ? card.network.security : "open")
                  + " · " + card.network.signal + "%"
                  + (card.network.saved ? " · saved" : "")
            color: card.secured || card.network.saved ? card.uiColors["ink-muted"]
                                                      : card.uiColors.warn
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
