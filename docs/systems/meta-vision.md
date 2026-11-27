# Meta vision

Shows out of character information in the world. While it is on, players see tags over other players' heads and the widget bars on props. Press `G` or the side bar button to turn it on and off.

- System: `src/Shared/Utility/MetaVision.luau`
- Key and side bar wiring: `src/Shared/Utility/init.luau`

How far tags show is the `MetaRange` [setting](systems/settings), from `20` to `400` studs. The server keeps track of who has it on.

## Settings

| Field | Default | Description |
| --- | --- | --- |
| `Utility.MetaVisionKey` | `Enum.KeyCode.G` | The key that turns it on and off |
| `MetaVision.Interval` | `0.3` | Seconds between tag updates |
| `MetaVision.Lift` | `2.6` | How high tags float over heads |

## Using it from your own code

```luau
const Utility = require(ReplicatedStorage.Shared.Utility)
const MetaVision = require(ReplicatedStorage.Shared.Utility.MetaVision)
```

| To | Call |
| --- | --- |
| Turn it on or off | `Utility.setMetaVision(true)`. Plays the sound and lights the side bar button |
| Turn it on or off quietly | `MetaVision.setActive(true)` |
| Read it | `MetaVision.active()` |
| Change the key | `Utility.MetaVisionKey = Enum.KeyCode.H` |

```luau
MetaButton.Activated:Connect(function()
    Utility.setMetaVision(not MetaVision.active())
end)
```

## Your own UI

The tags over heads are drawn by `MetaVision.luau`, not a swappable screen, so change them there. The prop widget bars it reveals are the `PropWidget` screen, see [Build mode](building/build-mode).
