import QtQuick

// A miniature of the bar a setup would produce, drawn from that setup's own resolved
// colours and oriented by the position its config actually asks for.
//
// Real screenshots were the alternative and are not practical: producing one means
// starting waybar under the setup first, which is the very thing the user has not
// decided to do yet. A mock costs nothing and answers the two questions a picker is
// really asked — what colour is it, and where does it sit.
Item {
    id: preview

    required property var colors      // token name -> QML colour, already resolved
    required property string position // top | bottom | left | right

    readonly property bool vertical: position === "left" || position === "right"
    readonly property int thickness: 15
    readonly property int pill: 9

    // The bar is drawn against a stand-in for the desktop behind it, because a bar's
    // surface colour means nothing without something to sit on — and for the light setup
    // it is the difference between "white rectangle" and a legible bar.
    Rectangle {
        anchors.fill: parent
        radius: 4
        color: Qt.darker(preview.colors["ground-solid"], 1.9)
        border.width: 1
        border.color: Qt.alpha(preview.colors["ink-faint"], 0.45)
        clip: true

        Rectangle {
            id: bar
            color: preview.colors["ground-solid"]

            // Anchored to the edge the config names, so "vertical" is legible as a shape
            // before the name is even read.
            anchors {
                top: preview.position !== "bottom" ? parent.top : undefined
                bottom: preview.position !== "top" ? parent.bottom : undefined
                left: preview.position !== "right" ? parent.left : undefined
                right: preview.position !== "left" ? parent.right : undefined
            }
            width: preview.vertical ? preview.thickness : undefined
            height: preview.vertical ? undefined : preview.thickness

            // Workspaces
            Grid {
                columns: preview.vertical ? 1 : 3
                spacing: 2
                anchors {
                    top: preview.vertical ? parent.top : undefined
                    topMargin: 3
                    horizontalCenter: preview.vertical ? parent.horizontalCenter : undefined
                    left: preview.vertical ? undefined : parent.left
                    leftMargin: 3
                    verticalCenter: preview.vertical ? undefined : parent.verticalCenter
                }
                Repeater {
                    model: preview.vertical ? 2 : 3
                    Rectangle {
                        required property int index
                        width: preview.vertical ? preview.pill : (index === 0 ? preview.pill + 3 : preview.pill)
                        height: preview.vertical && index === 0 ? preview.pill + 3 : preview.pill
                        radius: 3
                        color: index === 0 ? preview.colors.accent
                                           : Qt.alpha(preview.colors["ink-faint"], 0.55)
                    }
                }
            }

            // Window title. A bar of ink rather than real text: at this size glyphs render
            // as a smudge, while a rule reads as "a title" instantly. Dropped entirely when
            // the bar is vertical, because the vertical config carries no centre modules.
            Rectangle {
                visible: !preview.vertical
                anchors.centerIn: parent
                width: 34
                height: 2
                radius: 1
                color: Qt.alpha(preview.colors["ink-muted"], 0.8)
            }

            // Status cluster: tray, sensors, clock.
            Grid {
                columns: preview.vertical ? 1 : 3
                spacing: 2
                anchors {
                    bottom: preview.vertical ? parent.bottom : undefined
                    bottomMargin: 3
                    horizontalCenter: preview.vertical ? parent.horizontalCenter : undefined
                    right: preview.vertical ? undefined : parent.right
                    rightMargin: 3
                    verticalCenter: preview.vertical ? undefined : parent.verticalCenter
                }
                Repeater {
                    model: [preview.colors.warn, preview.colors["accent-alt"], preview.colors.ink]
                    Rectangle {
                        required property color modelData
                        required property int index
                        readonly property bool clock: index === 2
                        width: preview.vertical ? preview.pill : (clock ? preview.pill + 5 : preview.pill)
                        height: preview.vertical && clock ? preview.pill + 5 : preview.pill
                        radius: 2
                        color: Qt.alpha(modelData, clock ? 0.9 : 0.85)
                    }
                }
            }
        }
    }
}
