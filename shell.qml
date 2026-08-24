import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

// Entry point. Everything that talks to the system lives here; Picker and its delegates
// only ever see already-resolved values, which keeps the drawing code free of paths,
// processes and CSS.
ShellRoot {
    id: root

    // Resolved from the QML file's own location rather than hardcoded, so the repo runs
    // from wherever it was cloned. Process wants a plain path, not a file:// URL.
    readonly property string helper: Qt.resolvedUrl("scripts/waybar-setup").toString().replace(/^file:\/\//, "")
    readonly property string islandBin: Qt.resolvedUrl("bin/island").toString().replace(/^file:\/\//, "")

    property var setups: []
    property string current: "default"
    property string error: ""

    // Fallbacks for the window chrome before `list` has come back, and for any token a
    // stylesheet and the shared palette both leave undefined. These match the palette's
    // own defaults so the first frame does not flash a different colour scheme.
    readonly property var fallbackColors: ({
        "ground-solid": "#141414",
        "ink": "#e6e6e6",
        "ink-muted": "#9aa9b1",
        "ink-faint": "#7a7a7a",
        "accent": "#33ccff",
        "accent-alt": "#00ff99",
        "warn": "#ffcc33",
        "crit": "#ff5555"
    })

    // The picker paints itself in the colours of the setup that is live right now, so it
    // reads as part of the bar it edits rather than as a dialog borrowed from elsewhere.
    readonly property var uiColors: {
        for (var i = 0; i < setups.length; i++)
            if (setups[i].name === current)
                return setups[i].colors;
        return fallbackColors;
    }

    // @define-color values are CSS, and the palette uses rgba() for translucent surfaces.
    // QML colours understand #rrggbb but not rgba(), so the conversion happens once, here,
    // while rows are being built.
    function cssColor(value, fallback) {
        if (!value)
            return fallback;
        if (value.charAt(0) === "#")
            return value;
        var m = /^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+)\s*)?\)$/.exec(value);
        if (m)
            return Qt.rgba(m[1] / 255, m[2] / 255, m[3] / 255,
                           m[4] === undefined ? 1 : parseFloat(m[4]));
        return fallback;
    }

    // `list` leads with a header line naming its columns, so this maps by name and adding
    // a colour token to the helper needs no change here.
    function parseSetups(text) {
        var lines = text.split("\n").filter(function (l) { return l.trim() !== ""; });
        if (lines.length < 2)
            return [];

        var head = lines[0].split("\t");
        var rows = [];
        for (var i = 1; i < lines.length; i++) {
            var cells = lines[i].split("\t");
            var colors = {};
            var row = { colors: colors, name: "", ownConfig: false, position: "top" };

            for (var c = 0; c < head.length; c++) {
                var key = head[c];
                var value = cells[c] === undefined ? "" : cells[c];
                if (key === "name")
                    row.name = value;
                else if (key === "own_config")
                    row.ownConfig = value === "1";
                else if (key === "position")
                    row.position = value === "" ? "top" : value;
                else
                    colors[key] = cssColor(value, fallbackColors[key] || "#808080");
            }

            // A stylesheet that defines none of the tokens still has to draw, so anything
            // the resolver came back empty-handed on falls back to the palette default.
            for (var key2 in fallbackColors)
                if (colors[key2] === undefined)
                    colors[key2] = fallbackColors[key2];

            rows.push(row);
        }
        return rows;
    }

    // Paint from the cache first, then let the live answer replace it. Guarded on the
    // list being empty so a refresh that has already landed is never overwritten by a
    // stale cache arriving late.
    function seedFromCache() {
        if (root.setups.length > 0)
            return;
        if (PickerState.state.listOutput !== "")
            root.setups = root.parseSetups(PickerState.state.listOutput);
        if (PickerState.state.current !== "")
            root.current = PickerState.state.current;
    }

    Component.onCompleted: seedFromCache()

    Connections {
        target: PickerState
        function onReadyChanged() { root.seedFromCache(); }
    }

    Process {
        id: lister
        running: true
        command: [root.helper, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.setups = root.parseSetups(this.text);
                PickerState.state.listOutput = this.text;
                PickerState.save();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim() !== "") root.error = this.text.trim()
        }
        onExited: function (code) {
            if (code !== 0 && root.error === "")
                root.error = "waybar-setup list failed (exit " + code + ")";
        }
    }

    Process {
        id: currentProc
        running: true
        command: [root.helper, "current"]
        stdout: StdioCollector {
            onStreamFinished: {
                var name = this.text.trim();
                if (name !== "") {
                    root.current = name;
                    PickerState.state.current = name;
                    PickerState.save();
                }
            }
        }
    }

    // The island is a separate long-lived process, so the panel reports and flips it
    // rather than owning it — closing the panel must not take the island down with it.
    property bool islandRunning: false

    Process {
        id: islandStatus
        running: true
        command: [root.islandBin, "status"]
        stdout: StdioCollector {
            onStreamFinished: root.islandRunning = this.text.trim() === "running"
        }
    }

    Process {
        id: islandToggle
        command: [root.islandBin, "toggle"]
        // Re-ask rather than assume: starting can fail, and a toggle that lies about the
        // result is worse than one that takes a moment to tell the truth.
        onExited: islandRecheck.restart()
    }

    Timer {
        id: islandRecheck
        interval: 500
        onTriggered: islandStatus.running = true
    }

    Process {
        id: applier
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim() !== "") root.error = this.text.trim()
        }
        // Applying tears down the running bar and starts a new one. Quitting only once the
        // helper has returned means the shell outlives the pkill; quitting on `running`
        // going false would race the restart and could leave the desktop with no bar.
        onExited: function (code) {
            if (code === 0)
                Qt.quit();
            else
                picker.visible = true;   // apply failed, so put the picker back with the error
        }
    }

    function apply(name) {
        root.error = "";
        picker.visible = false;          // dismiss on the click, not on the restart finishing
        applier.command = [root.helper, "apply", name];
        applier.running = true;
    }

    // A backstop for an apply that never returns: better to leave a stray shell process
    // behind than to hold an invisible exclusive-keyboard layer over the desktop.
    Timer {
        running: !picker.visible
        interval: 5000
        onTriggered: Qt.quit()
    }

    Picker {
        id: picker
        setups: root.setups
        current: root.current
        uiColors: root.uiColors
        error: root.error
        onApplyRequested: function (name) { root.apply(name); }
        islandRunning: root.islandRunning
        onIslandToggleRequested: islandToggle.running = true
        onDismissed: Qt.quit()
    }
}
