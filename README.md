# hyprland_setup

A GUI for Hyprland setup, implemented in [quickshell](https://quickshell.outfoxxed.me/).

Right now it covers one thing: choosing which waybar setup is live.

![The picker](docs/picker.png)

## What a "setup" is

A setup is a name, discovered from `~/.config/waybar` rather than listed anywhere:

| file | meaning |
| --- | --- |
| `style-<name>.css` | what makes the name exist — a recolour of the base bar |
| `config-<name>.jsonc` | optional; the setup also rearranges modules or moves the bar |
| `style.css` + `config.jsonc` | the setup called `default` |

Dropping a new `style-<name>.css` beside `style.css` is the whole of adding a setup. The
picker will list it on its next run, with a preview built from the colours that stylesheet
actually defines.

Each row previews the bar it would produce — the resolved palette, and the edge the config
puts it on, so `vertical` reads as a vertical bar before you read its name. The previews are
mockups rather than screenshots on purpose: a real screenshot would mean starting waybar
under that setup first, which is the decision you have not made yet.

Colours resolve the way GTK itself resolves `@define-color` — the setup's own stylesheet
first, then the `style.css` it `@import`s, then the shared `~/.config/theme/colors.css` — so
a swatch cannot claim a colour the bar does not render.

## Use

```bash
./bin/waybar-setup-gui
```

Running it again closes it, so it behaves as a toggle when bound to a key. In Hyprland:

```
bindd = $mainMod SHIFT, T, Waybar setup, exec, ~/Documents/GitHub/hyprland_setup/bin/waybar-setup-gui
```

`↑` `↓` move, `Enter` applies, `Esc` cancels, and typing filters. Clicking a row applies it;
clicking outside cancels.

Applying writes the chosen name to `$XDG_STATE_HOME/waybar/theme` and restarts the bar, so
the choice survives a relogin.

## Without the GUI

Everything the GUI knows comes from one script, which is usable on its own — and is the
thing to reach for when it is the GUI that is misbehaving:

```bash
./scripts/waybar-setup list       # every setup, with its resolved colours, as TSV
./scripts/waybar-setup current    # the setup that is live right now
./scripts/waybar-setup apply nord # switch, and restart the bar
```

`current` reads the running waybar's command line rather than the state file. The state file
records what the *next* login will start, and the two drift the moment waybar is started by
hand — trusting it would mark the wrong row as live.

## Layout

| path | |
| --- | --- |
| `shell.qml` | entry point; owns every process call and all CSS parsing |
| `Picker.qml` | the overlay window, filtering and keyboard handling |
| `SetupCard.qml` | one row |
| `BarPreview.qml` | the miniature bar |
| `scripts/waybar-setup` | discovery, colour resolution, applying |
| `bin/waybar-setup-gui` | toggling launcher |

QML only ever sees resolved values; paths, processes and CSS stop at `shell.qml`.

## Requires

quickshell 0.3, Qt 6.5+ (for `Qt.alpha`), a wlroots compositor, and a waybar config laid out
as above. It hands the actual relaunch to `~/.config/hypr/scripts/waybar-launch.sh` when that
exists, so the launch has a single owner, and falls back to invoking waybar directly when it
does not.
