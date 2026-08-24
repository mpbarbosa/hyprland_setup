import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.modules.common

// The picker itself: a full-screen overlay layer with a card floating in it, the same
// shape wofi takes, so the two pickers feel like the same gesture.
PanelWindow {
    id: picker

    required property var setups
    required property string current
    required property var uiColors
    required property string error

    signal applyRequested(string name)
    signal dismissed()

    property int selection: 0
    property string query: ""

    // Row geometry lives here rather than in the delegate because the sheet has to size
    // itself from the model alone. Reading list.contentHeight instead would make the
    // sheet's height depend on the list's, and the list's on the sheet's — the geometry
    // then settles a frame late, which is exactly long enough for the initial
    // positionViewAtIndex to run against an unlaid-out view and do nothing.
    readonly property int rowHeight: 62
    readonly property int rowSpacing: 4

    // Ranked, not just filtered: a plain substring test puts catppuccin above tokyo-night
    // for "tn" and offers no way to type an abbreviation at all.
    readonly property var filtered: Fuzzy.filter(setups, query, "name")

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "waybar-setup-picker"
    // Exclusive rather than OnDemand: the picker is modal and is driven by typing, and
    // OnDemand would leave the first keystroke going to whatever was focused underneath.
    //
    // A HyprlandFocusGrab was tried here and removed. Under Exclusive it never clears, so
    // it is dead weight; under OnDemand the surface never holds focus, the grab clears
    // immediately and the picker dismisses itself within seconds of opening. It is the
    // right primitive for a sidebar that does not cover the screen, not for a full-screen
    // modal whose backdrop already catches outside clicks.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // ListView assigns currentIndex itself whenever the model changes, which silently
    // destroys a declarative binding to it. So the view is driven imperatively from
    // `selection` instead, and re-driven whenever the model swaps underneath it.
    function syncView() {
        list.currentIndex = selection;
        Qt.callLater(function () {
            if (selection >= 0 && selection < list.count)
                list.positionViewAtIndex(selection, ListView.Contain);
        });
    }

    onSelectionChanged: syncView()

    function move(delta) {
        if (filtered.length === 0)
            return;
        selection = (selection + delta + filtered.length) % filtered.length;
    }

    function activate() {
        if (selection >= 0 && selection < filtered.length)
            picker.applyRequested(filtered[selection].name);
    }

    // Re-anchor on the running setup whenever the list or the filter changes, so the
    // selection starts somewhere meaningful instead of always at the top.
    function resetSelection() {
        for (var i = 0; i < filtered.length; i++) {
            if (filtered[i].name === current) {
                selection = i;
                return;
            }
        }
        selection = 0;
    }

    onFilteredChanged: resetSelection()
    onCurrentChanged: resetSelection()

    // Dimming the desktop is what makes the overlay read as modal; without it the sheet
    // looks like a window that merely happens to be on top.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
    }

    // Clicking the dimmed area outside the card dismisses, which is the one gesture every
    // overlay is expected to have.
    MouseArea {
        anchors.fill: parent
        onClicked: picker.dismissed()
    }

    Rectangle {
        id: sheet
        anchors.centerIn: parent
        width: 460
        // 118 is the chrome above the list: 2x16 margins, the title row, the search field
        // and the two gaps between them. Guessing high here leaves dead space under a
        // short filtered list.
        height: Math.min(picker.height - 140,
                         118 + Math.max(picker.rowHeight,
                                        picker.filtered.length * (picker.rowHeight + picker.rowSpacing) - picker.rowSpacing))
        radius: 14
        color: picker.uiColors["ground-solid"]
        border.width: 1
        border.color: Qt.alpha(picker.uiColors.accent, 0.45)

        // Swallow clicks so they do not reach the dismiss area behind.
        MouseArea { anchors.fill: parent }

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Item {
                width: parent.width
                height: title.height

                Text {
                    id: title
                    text: "Waybar setup"
                    color: picker.uiColors.ink
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 17
                    font.bold: true
                }

                Text {
                    anchors.right: parent.right
                    anchors.baseline: title.baseline
                    text: picker.setups.length + " available · " + picker.current + " live"
                    color: picker.uiColors["ink-muted"]
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 11
                }
            }

            Rectangle {
                width: parent.width
                height: 32
                radius: 6
                color: Qt.alpha(picker.uiColors["ink-faint"], 0.18)

                TextInput {
                    id: search
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: picker.uiColors.ink
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 13
                    focus: true
                    selectByMouse: true
                    selectionColor: Qt.alpha(picker.uiColors.accent, 0.5)
                    onTextChanged: picker.query = text

                    Keys.onUpPressed: picker.move(-1)
                    Keys.onDownPressed: picker.move(1)
                    Keys.onReturnPressed: picker.activate()
                    Keys.onEnterPressed: picker.activate()
                    Keys.onEscapePressed: picker.dismissed()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text === ""
                        text: "Type to filter…"
                        color: picker.uiColors["ink-faint"]
                        font: search.font
                    }
                }
            }

            ListView {
                id: list
                width: parent.width
                height: parent.height - y
                clip: true
                spacing: picker.rowSpacing
                model: picker.filtered
                boundsBehavior: Flickable.StopAtBounds

                // The list arrives after the window does, so the view has to be re-pointed
                // at the selection once the rows actually exist.
                onCountChanged: Qt.callLater(picker.syncView)
                onHeightChanged: Qt.callLater(picker.syncView)
                Component.onCompleted: Qt.callLater(picker.syncView)

                delegate: SetupCard {
                    required property var modelData
                    required property int index

                    width: list.width
                    height: picker.rowHeight
                    setup: modelData
                    uiColors: picker.uiColors
                    active: modelData.name === picker.current
                    selected: index === picker.selection
                    onClicked: picker.applyRequested(modelData.name)
                }
            }
        }

        // Errors from the helper surface here rather than only in the log, because a picker
        // that silently lists nothing is indistinguishable from one that is still loading.
        Rectangle {
            visible: picker.error !== ""
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 8
            height: msg.implicitHeight + 12
            radius: 6
            color: Qt.alpha(picker.uiColors.crit, 0.18)

            Text {
                id: msg
                anchors.fill: parent
                anchors.margins: 6
                wrapMode: Text.Wrap
                text: picker.error
                color: picker.uiColors.crit
                font.family: "Hack Nerd Font"
                font.pixelSize: 11
            }
        }
    }

    Text {
        anchors.horizontalCenter: sheet.horizontalCenter
        anchors.top: sheet.bottom
        anchors.topMargin: 10
        text: "↑↓ move · Enter apply · Esc cancel"
        color: Qt.alpha(picker.uiColors.ink, 0.55)
        font.family: "Hack Nerd Font"
        font.pixelSize: 11
    }
}
