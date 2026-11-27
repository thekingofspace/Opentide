# Footsteps

Plays footstep sounds for every player based on the material they walk on. It runs on each client for all characters near the camera.

- System: `src/Shared/Footsteps/init.luau`
- Settings: `src/Shared/Footsteps/Config.luau`

## Sound groups

Each group is a set of sounds and the materials that use them. The template has `Grass`, `Stone`, `Wood`, `Sand` and `Snow`.

```luau
export type Group = {
    Ids: { number | string },
    Materials: { string },
    Volume: number?,
    Pitch: { number }?,
}
```

```luau
Wood = {
    Ids = { 1234567890, 1234567891 },
    Materials = { "Wood", "WoodPlanks" },
    Volume = 0.8,
},
```

- One id from `Ids` is picked at random for each step. Numbers and number strings become `rbxassetid://`.
- `Materials` are names from `Enum.Material`.
- A material that is in no group uses the `Default` group.
- No step plays in the air or in water.

## Settings

| Field | Default | Description |
| --- | --- | --- |
| `Enabled` | `true` | Turns footsteps off when `false` |
| `MuteDefault` | `true` | Mutes the Roblox running sound so they do not play over each other |
| `Range` | `70` | Furthest distance from the camera that steps play |
| `StepLength` | `3.4` | Studs walked per step |
| `MinSpeed` | `1.5` | Slowest movement that counts as walking |
| `Volume` | `0.45` | Base volume, multiplied by the group's `Volume` |
| `Pitch` | `{ 0.92, 1.08 }` | Random pitch range, unless the group sets its own |
| `RollOff` | `45` | How far a step can be heard |
| `Default` | `"Stone"` | Group for materials that are not listed |
| `Groups` | see above | The sound groups |

The material list is read once when footsteps start, so change the config before the game runs.

## API

### `Footsteps.start()`

Starts footsteps on the client. Does nothing if `Enabled` is `false`. The side bar code calls it for you.

`Footsteps.Config` is the settings module.

## Your own UI

Footsteps have no screen.
