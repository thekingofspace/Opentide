# Sounds

Every sound the game plays has a name, like `MenuOpen` or `PropPlaced`. Set the id for a name in one place and every system that plays it uses it. Sounds only play on the client.

- System: `src/Shared/Sounds/init.luau`
- Sound list: `src/Shared/Sounds/Config.luau`

## The sound list

```luau
export type Entry = {
    Id: string,
    Group: string?,
    Volume: number?,
    Pitch: number?,
    Variance: number?,
    Cooldown: number?,
    Range: number?,
}
```

| Field | Description |
| --- | --- |
| `Id` | The sound id. `""` means the sound is off |
| `Group` | `"UI"`, `"World"` or `"Ambience"` |
| `Volume` | Volume, `0.5` if not set |
| `Pitch` | Playback speed |
| `Variance` | Random change to the pitch each time, so repeats sound less the same |
| `Cooldown` | Shortest time between two plays of this sound |
| `Range` | How far a sound in the world can be heard |

The config has three helpers that fill in the usual values:

```luau
MenuOpen = ui("rbxassetid://1234567890"),
PropPlaced = world("rbxassetid://1234567891"),
WeatherRain = ambience("1516791621"),
```

| Helper | Group | Volume | Variance | Cooldown | Range |
| --- | --- | --- | --- | --- | --- |
| `ui(Id)` | UI | `0.5` | `0.04` | `0.04` | |
| `world(Id)` | World | `0.7` | `0.06` | `0.05` | `80` |
| `ambience(Id)` | Ambience | `0.5` | | | |

Group volumes are `UI = 0.6`, `World = 0.8` and `Ambience = 0.5`.

::: info Most sounds start off
Only `Click` and `WeatherRain` have ids in the template. Every other entry has `""`, so it stays quiet until you add your own id.
:::

### Sound names

| Area | Names |
| --- | --- |
| General | `Click`, `Notify`, `Error`, `Confirm` |
| Menus | `PanelOpen`, `PanelClose`, `MenuOpen`, `MenuClose`, `SidebarOpen`, `SidebarClose`, `ToggleOn`, `ToggleOff`, `PageTurn`, `SettingsSaved` |
| Radio and dice | `RadioTune`, `RadioOff`, `DiceRoll`, `DiceResult` |
| Build mode | `PropSelect`, `PlaceStart`, `PlaceConfirm`, `PlaceCancel`, `ToolChange`, `EditEnter`, `EditExit`, `Select`, `Unselect`, `BoxSelect`, `MoveConfirm`, `DeleteConfirm`, `SaveSlot`, `LoadSlot`, `ClearSlot` |
| Prop widgets | `WidgetOpen`, `WidgetClose`, `WidgetSave`, `WidgetButton`, `InfoOpen` |
| Meta vision | `MetaVisionOn`, `MetaVisionOff` |
| Customize | `CustomizeEnter`, `CustomizeExit`, `CustomizeSelect`, `CustomizeAdd`, `CustomizeRemove`, `CustomizeApply` |
| Tools | `ToolEquip`, `ToolPutAway` |
| World | `PropPlaced`, `PropRemoved`, `PropMoved` |
| Ambience | `WeatherRain`, `WeatherFog`, `AmbienceDay`, `AmbienceNight`, `ZoneMidnight`, `ZoneCave` |

## API

### `Sounds.play(Name: string): Sound?`

Plays a sound for the local player only.

### `Sounds.playAt(Name: string, Where: Vector3 | Instance): Sound?`

Plays a sound in the world, at a position, a part or an attachment.

### `Sounds.loop(Name: string): Sound?`

Starts a looping sound at volume `0`. Fade it in yourself.

### Other functions

| Function | Description |
| --- | --- |
| `Sounds.get(Name): Entry?` | The entry, or nil if it has no id |
| `Sounds.id(Name): string?` | The full `rbxassetid://` id |
| `Sounds.volume(Name): number` | The entry's volume |
| `Sounds.setGroupVolume(Group, Volume)` | Changes a group's volume |
| `Sounds.watch(Root)` | Plays `Click` for every button under `Root` |
| `Sounds.preload()` | Loads every sound that has an id |

Sounds made with `play` are removed when they end, or after 10 seconds.

## Your own UI

Sounds have no screen. Every button inside your screens plays `Click` on its own, because the game watches the player's GUI.
