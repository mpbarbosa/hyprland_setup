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

    required property bool islandRunning
    required property var terminals
    required property string currentTerminal

    signal applyRequested(string name)
    signal terminalRequested(string exec)
    signal islandToggleRequested()
    signal dismissed()

    property int selection: 0
    property string query: ""
    property string page: "setups"          // "setups" | "terminals"

    // Row geometry lives here rather than in the delegate because the sheet has to size
    // itself from the model alone. Reading list.contentHeight instead would make the
    // sheet's height depend on the list's, and the list's on the sheet's — the geometry
    // then settles a frame late, which is exactly long enough for the initial
    // positionViewAtIndex to run against an unlaid-out view and do nothing.
    readonly property int rowHeight: 62
    readonly property int rowSpacing: 4

    // Both pages are lists of named things, so they share one filter, one selection and
    // one set of keys; only what Enter does with the result differs.
    readonly property var items: page === "setups" ? setups : terminals

    // Ranked, not just filtered: a plain substring test puts catppuccin above tokyo-night
    // for "tn" and offers no way to type an abbreviation at all.
    readonly property var filtered: Fuzzy.filter(items, query, "name")

    function activeList() {
        return page === "setups" ? list : termList;
    }

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
        var v = picker.activeList();
        v.currentIndex = selection;
        Qt.callLater(function () {
            var w = picker.activeList();
            if (selection >= 0 && selection < w.count)
                w.positionViewAtIndex(selection, ListView.Contain);
        });
    }

    onSelectionChanged: syncView()

    function move(delta) {
        if (filtered.length === 0)
            return;
        selection = (selection + delta + filtered.length) % filtered.length;
    }

    function activate() {
        if (selection < 0 || selection >= filtered.length)
            return;
        if (page === "setups")
            picker.applyRequested(filtered[selection].name);
        else
            picker.terminalRequested(filtered[selection].exec);
    }

    // With no query, the running setup is the meaningful place to start. Once something
    // has been typed it is the best match instead: the list is ranked, so index 0 is what
    // the query asked for, and staying anchored on the running setup would make Enter
    // apply the wrong one whenever that setup happens to match too — typing "tn" ranks
    // tokyo-night first but would have applied a still-matching catppuccin.
    function resetSelection() {
        var target = 0;
        if (query === "") {
            for (var i = 0; i < filtered.length; i++) {
                var hit = page === "setups" ? filtered[i].name === current
                                            : filtered[i].exec === currentTerminal;
                if (hit) {
                    target = i;
                    break;
                }
            }
        }
        selection = target;
        syncView();   // the assignment is often a no-op, and the view still has to follow
    }

    onFilteredChanged: resetSelection()
    onCurrentChanged: resetSelection()
    onPageChanged: resetSelection()

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
                         118 + 58 + 38 + Math.max(picker.rowHeight,
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
                    text: "Hyprland setup"
                    color: picker.uiColors.ink
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 17
                    font.bold: true
                }

                Text {
                    anchors.right: parent.right
                    anchors.baseline: title.baseline
                    text: picker.page === "setups"
                          ? picker.setups.length + " setups · " + picker.current + " live"
                          : picker.terminals.length + " terminals installed"
                    color: picker.uiColors["ink-muted"]
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 11
                }
            }

            // Two pages rather than one longer list: a terminal is not a waybar setup, and
            // the rows carry different things. Tab moves between them so the panel stays
            // reachable without the mouse.
            Row {
                spacing: 6

                Repeater {
                    model: [
                        { key: "setups",    label: "Waybar" },
                        { key: "terminals", label: "Terminal" }
                    ]

                    Rectangle {
                        required property var modelData
                        readonly property bool on: picker.page === modelData.key

                        width: tabText.implicitWidth + 24
                        height: 26
                        radius: 13
                        color: on ? Qt.alpha(picker.uiColors.accent, 0.20)
                                  : tabHover.hovered ? Qt.alpha(picker.uiColors.ink, 0.07)
                                                     : "transparent"
                        border.width: 1
                        border.color: on ? Qt.alpha(picker.uiColors.accent, 0.55)
                                         : Qt.alpha(picker.uiColors["ink-faint"], 0.3)

                        HoverHandler { id: tabHover }
                        TapHandler { onTapped: picker.page = modelData.key }

                        Text {
                            id: tabText
                            anchors.centerIn: parent
                            text: modelData.label
                            color: parent.on ? picker.uiColors.ink : picker.uiColors["ink-muted"]
                            font.family: "Hack Nerd Font"
                            font.pixelSize: 12
                        }
                    }
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
                    // The rest of this panel is driven from the keyboard, so the island
                    // row is too rather than being the one mouse-only control in it.
                    Keys.onTabPressed: picker.page = (picker.page === "setups" ? "terminals" : "setups")
                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_I && (event.modifiers & Qt.ControlModifier)) {
                            picker.islandToggleRequested();
                            event.accepted = true;
                        }
                    }

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
                // Leaves room for the island row below; without subtracting it the list
                // claims the remainder and the row is laid out past the sheet's edge.
                height: parent.height - y - islandRow.height - parent.spacing
                clip: true
                spacing: picker.rowSpacing
                visible: picker.page === "setups"
                // The hidden page gets an empty model rather than the shared one: a
                // SetupCard handed a terminal row would bind against colours it has not
                // got, and fill the log with it.
                model: picker.page === "setups" ? picker.filtered : []
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

            ListView {
                id: termList
                width: parent.width
                // Same expression as the setups list rather than a reference to it: an
                // invisible Column child keeps its last y, so borrowing its height would
                // size this from wherever the other list happened to stop being shown.
                height: parent.height - y - islandRow.height - parent.spacing
                clip: true
                spacing: picker.rowSpacing
                visible: picker.page === "terminals"
                model: picker.page === "terminals" ? picker.filtered : []
                boundsBehavior: Flickable.StopAtBounds

                onCountChanged: Qt.callLater(picker.syncView)
                onHeightChanged: Qt.callLater(picker.syncView)
                Component.onCompleted: Qt.callLater(picker.syncView)

                delegate: TerminalCard {
                    required property var modelData
                    required property int index

                    width: termList.width
                    height: picker.rowHeight
                    terminal: modelData
                    uiColors: picker.uiColors
                    active: modelData.exec === picker.currentTerminal
                    selected: index === picker.selection
                    onClicked: picker.terminalRequested(modelData.exec)
                }
            }

            // Not a waybar setup, so it sits apart from the list rather than in it: the
            // island is a separate process with its own lifetime, and the only thing the
            // panel does is start and stop it.
            Rectangle {
                id: islandRow
                width: parent.width
                height: 46
                radius: 8
                color: islandHover.hovered ? Qt.alpha(picker.uiColors.ink, 0.06) : "transparent"
                border.width: 1
                border.color: Qt.alpha(picker.uiColors["ink-faint"], 0.35)

                HoverHandler { id: islandHover }
                TapHandler { onTapped: picker.islandToggleRequested() }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    spacing: 2

                    Text {
                        text: "Dynamic island"
                        color: picker.uiColors.ink
                        font.family: "Hack Nerd Font"
                        font.pixelSize: 13
                    }
                    Text {
                        text: "volume and media, under the bar"
                        color: picker.uiColors["ink-muted"]
                        font.family: "Hack Nerd Font"
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    width: 46
                    height: 22
                    radius: height / 2
                    color: picker.islandRunning ? picker.uiColors["accent-alt"]
                                                : Qt.alpha(picker.uiColors["ink-faint"], 0.35)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        y: 3
                        x: picker.islandRunning ? parent.width - width - 3 : 3
                        color: picker.uiColors["ground-solid"]
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    }
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
        text: "↑↓ move · Tab page · Enter apply · Ctrl+I island · Esc cancel"
        color: Qt.alpha(picker.uiColors.ink, 0.55)
        font.family: "Hack Nerd Font"
        font.pixelSize: 11
    }
}
