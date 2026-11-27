# Ruler

Measures the distance between two points in studs. Turn it on, click two points and it shows the distance on the line and in a toast. A third click starts a new measurement.

- System: `src/Shared/Ruler.luau`

## Settings

Fields on the `Ruler` module:

| Field | Default | Description |
| --- | --- | --- |
| `Key` | `Enum.KeyCode.V` | Key that turns it on and off |
| `Color` | `Color3.fromRGB(255, 214, 90)` | Color of the line, points and label |
| `Thickness` | `0.08` | Line thickness in studs |
| `MarkerSize` | `0.4` | Size of the end points |
| `Range` | `1000` | How far a click can reach |

## API

### `Ruler.set(Value: boolean)`

Turns the ruler on or off. While it is on, clicks place points instead of using tools.

### `Ruler.toggle()`

Flips it. `Ruler.active()` reads it.

### `Ruler.Changed`

Fires with `true` or `false` when it turns on or off. The side bar uses it to light up its button.

`Ruler.start()` runs once on the client and is called by the side bar code for you.

## Using it from your own code

```luau
const Ruler = require(ReplicatedStorage.Shared.Ruler)
```

| To | Call |
| --- | --- |
| Turn it on or off | `Ruler.set(true)` or `Ruler.toggle()` |
| Change the key | `Ruler.Key = Enum.KeyCode.K` |
| Turn the key off | `Ruler.Key = Enum.KeyCode.Unknown` |
| Change the look | Set `Ruler.Color`, `Ruler.Thickness` or `Ruler.MarkerSize` before turning it on |

If you change the key, change the `V` label on the side bar button too, in `src/Shared/Utility/init.luau`.

## Your own UI

The ruler has no screen to swap. Its line, points and distance label are drawn in the world by `Ruler.luau`, so change them there. The distance toast goes through the [Toasts](systems/toasts) screen.

To add your own button for it, call `Ruler.toggle()` and listen to `Ruler.Changed` to show if it is on.
