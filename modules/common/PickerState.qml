pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The last answer the helper gave, kept so the picker paints real rows on its first frame
// instead of an empty sheet. `waybar-setup list` costs about 100ms — short, but a picker
// that appears blank and fills in a beat later reads as slower than one that is.
//
// The cache is never trusted for longer than that: a live refresh starts at the same time
// and replaces it the moment it lands, so a stylesheet added since the last run shows up
// after one frame rather than not at all.
//
// What is cached is the helper's raw stdout, not parsed rows. Parsed rows would have to
// survive a round trip through JSON — colours included — and that is a second parsing path
// to keep in step with the first. Caching the text means there is only ever one.
Singleton {
    id: root

    property alias state: adapter
    property bool ready: false

    readonly property string dir: {
        var base = Quickshell.env("XDG_STATE_HOME");
        if (!base)
            base = Quickshell.env("HOME") + "/.local/state";
        return base + "/hyprland-setup";
    }

    FileView {
        id: file
        path: root.dir + "/picker.json"

        onLoaded: root.ready = true
        onLoadFailed: err => {
            // A missing file is the normal first run, not an error worth surfacing: write
            // the defaults out so the next launch has something to read. FileView creates
            // the parent directories itself.
            root.ready = true;
            if (err === FileViewError.FileNotFound)
                writeTimer.restart();
        }

        adapter: JsonAdapter {
            id: adapter
            property string listOutput: ""
            property string current: ""
        }
    }

    // Debounced because both values are set in the same turn when a refresh lands, and
    // writing the file twice for one update is pointless disk traffic.
    function save() {
        writeTimer.restart();
    }

    Timer {
        id: writeTimer
        interval: 120
        onTriggered: file.writeAdapter()
    }
}
