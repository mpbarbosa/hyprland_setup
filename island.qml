import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import QtQuick

// A dynamic island for this desktop: a pill under the bar that wakes up when something
// happens worth a glance — the volume moved, the track changed — and goes quiet again.
//
// It is a separate quickshell config from the picker on purpose. The picker is launched
// on a key, applies one thing and exits; the island has to outlive every switch. One
// process cannot sensibly be both.
ShellRoot {
    id: root

    readonly property string helper: Qt.resolvedUrl("scripts/waybar-setup").toString().replace(/^file:\/\//, "")
    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/waybar/theme"

    readonly property var fallbackColors: ({
        "ground-solid": "#141414", "ink": "#e6e6e6", "ink-muted": "#9aa9b1",
        "ink-faint": "#7a7a7a", "accent": "#33ccff", "accent-alt": "#00ff99",
        "warn": "#ffcc33", "crit": "#ff5555"
    })
    property var colors: fallbackColors

    // ------------------------------------------------------------------ what it says
    property string mode: ""
    property string title: ""
    property string subtitle: ""
    property string glyph: ""
    property real progress: -1
    property bool showProgress: false

    // Bindings fire once on startup as they take their initial value, and an island that
    // announces the current volume every time you log in is a bug. Nothing is shown until
    // the sources have settled.
    property bool armed: false
    Timer { running: true; interval: 1200; onTriggered: root.armed = true }

    function show(kind, t, sub, g, prog) {
        if (!armed)
            return;
        root.mode = kind;
        root.title = t;
        root.subtitle = sub || "";
        root.glyph = g;
        root.progress = prog === undefined ? -1 : prog;
        root.showProgress = prog !== undefined;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: 2600
        onTriggered: root.mode = ""
    }

    // ------------------------------------------------------------------ volume
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: sink && sink.audio ? sink.audio : null

    function volumeGlyph(v, muted) {
        if (muted || v <= 0.001) return "󰝟";
        if (v < 0.34) return "󰕿";
        if (v < 0.67) return "󰖀";
        return "󰕾";
    }

    Connections {
        target: root.sinkAudio
        enabled: root.sinkAudio !== null
        function onVolumeChanged() {
            var v = root.sinkAudio.volume;
            root.show("volume", root.sinkAudio.muted ? "Muted" : "Volume " + Math.round(v * 100) + "%",
                      "", root.volumeGlyph(v, root.sinkAudio.muted), v);
        }
        function onMutedChanged() {
            var v = root.sinkAudio.volume;
            root.show("volume", root.sinkAudio.muted ? "Muted" : "Volume " + Math.round(v * 100) + "%",
                      "", root.volumeGlyph(v, root.sinkAudio.muted), v);
        }
    }

    // ------------------------------------------------------------------ media
    readonly property var player: Mpris.players && Mpris.players.values.length > 0
                                  ? Mpris.players.values[0] : null

    Connections {
        target: root.player
        enabled: root.player !== null
        function onTrackTitleChanged() { root.announceTrack(); }
        function onIsPlayingChanged()  { root.announceTrack(); }
    }

    function announceTrack() {
        if (!player || !player.trackTitle)
            return;
        root.show("media", player.trackTitle, player.trackArtist || player.identity,
                  player.isPlaying ? "󰎆" : "󰏤");
    }

    // ------------------------------------------------------------------ palette
    // The same resolved colours the picker draws with, so the island wears whatever the
    // bar is wearing. Re-read when the theme state file changes, which is how a switch
    // reaches a process that was already running.
    Process {
        id: lister
        running: true
        command: [root.helper, "list"]
        stdout: StdioCollector {
            onStreamFinished: root.colors = root.parseActive(this.text)
        }
    }

    Process {
        id: currentProc
        running: true
        command: [root.helper, "current"]
        stdout: StdioCollector {
            onStreamFinished: {
                var n = this.text.trim();
                if (n !== "" && n !== root.activeName) {
                    root.activeName = n;
                    lister.running = true;      // re-read with the new active theme in mind
                }
            }
        }
    }

    property string activeName: ""

    FileView {
        path: root.stateFile
        watchChanges: true
        onFileChanged: refresh.restart()
    }

    Timer {
        id: refresh
        interval: 250
        onTriggered: currentProc.running = true
    }

    function cssColor(value, fallback) {
        if (!value) return fallback;
        if (value.charAt(0) === "#") return value;
        var m = /^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+)\s*)?\)$/.exec(value);
        if (m) return Qt.rgba(m[1] / 255, m[2] / 255, m[3] / 255, m[4] === undefined ? 1 : parseFloat(m[4]));
        return fallback;
    }

    function parseActive(text) {
        var lines = text.split("\n").filter(function (l) { return l.trim() !== ""; });
        if (lines.length < 2) return fallbackColors;
        var head = lines[0].split("\t");
        for (var i = 1; i < lines.length; i++) {
            var cells = lines[i].split("\t");
            if (cells[0] !== root.activeName) continue;
            var out = {};
            for (var c = 0; c < head.length; c++)
                if (head[c] !== "name" && head[c] !== "own_config" && head[c] !== "position")
                    out[head[c]] = cssColor(cells[c], fallbackColors[head[c]] || "#808080");
            for (var k in fallbackColors)
                if (out[k] === undefined) out[k] = fallbackColors[k];
            return out;
        }
        return fallbackColors;
    }

    // ------------------------------------------------------------------ the window
    PanelWindow {
        // Sized to the pill, not to the screen: a full-width surface would swallow clicks
        // across the whole top of the desktop for the sake of a 320px slab.
        anchors { top: true }
        margins.top: 6
        implicitWidth: pill.implicitWidth
        implicitHeight: pill.implicitHeight
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hyprland-setup-island"
        // Never takes the keyboard, and never reserves space — it floats over whatever is
        // there rather than pushing the desktop down like a second bar.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusiveZone: 0

        IslandPill {
            id: pill
            anchors.centerIn: parent
            colors: root.colors
            mode: root.mode
            title: root.title
            subtitle: root.subtitle
            glyph: root.glyph
            progress: root.progress
            showProgress: root.showProgress
        }
    }
}
