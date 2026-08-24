import QtQuick

// The island itself: a rounded slab that changes size to fit whatever it is currently
// saying, and says nothing at all when nothing has happened.
//
// The whole idea rests on the morph, so width and height are animated and everything
// inside is laid out from them rather than the other way round — a Layout that resizes
// its parent fights the animation and the pill stutters.
Item {
    id: pill

    required property var colors
    required property string mode        // "" | "volume" | "media"
    required property string title
    required property string subtitle
    required property string glyph
    required property real progress      // 0..1, only drawn when >= 0
    required property bool showProgress

    readonly property bool open: mode !== ""

    implicitWidth: open ? 320 : 92
    implicitHeight: open ? 58 : 10

    Behavior on implicitWidth  { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.7 } }
    Behavior on implicitHeight { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.7 } }

    Rectangle {
        id: slab
        anchors.fill: parent
        radius: height / 2
        color: pill.colors["ground-solid"]
        border.width: 1
        border.color: Qt.alpha(pill.colors.accent, pill.open ? 0.45 : 0.18)

        // Collapsed, the pill is a hint that the island exists at all; a full-strength
        // slab sitting under the bar doing nothing reads as a rendering glitch.
        opacity: pill.open ? 1 : 0.55
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Item {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            opacity: pill.open ? 1 : 0
            visible: opacity > 0
            // Held back until the slab has most of its width, so the text is never
            // painted wider than the box it is in.
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.InOutQuad } }

            Text {
                id: icon
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                text: pill.glyph
                color: pill.colors.accent
                font.family: "Hack Nerd Font"
                font.pixelSize: 20
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: icon.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                spacing: 3

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: pill.title
                    color: pill.colors.ink
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 13
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    visible: !pill.showProgress && pill.subtitle !== ""
                    text: pill.subtitle
                    color: pill.colors["ink-muted"]
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 11
                }

                Rectangle {
                    visible: pill.showProgress
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Qt.alpha(pill.colors["ink-faint"], 0.4)

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, pill.progress))
                        height: parent.height
                        radius: parent.radius
                        color: pill.colors.accent
                        Behavior on width { NumberAnimation { duration: 120 } }
                    }
                }
            }
        }
    }
}
