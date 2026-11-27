# Settings

Player settings like meta vision range and weather. Changes are saved to the player's data when they press save.

- Setting list: `src/Shared/Utility/SettingsList.luau`
- Client: `src/Shared/Utility/Settings.luau`
- Panel wiring: `src/Shared/Utility/init.luau`
- Server: `src/Server/Settings.luau`
- Built in screen: `src/Shared/GUI_Elements/SettingsPanel.luau`

## The settings

```luau
export type Kind = "Toggle" | "Number"
export type Value = boolean | number

export type Setting = {
    Id: string,
    Name: string,
    Kind: Kind,
    Default: Value,
    Min: number?,
    Max: number?,
    Step: number?,
}
```

| Id | Name | Kind | Default | Range |
| --- | --- | --- | --- | --- |
| `MetaRange` | meta vision range | Number | `120` | `20` to `400`, step `20` |
| `VFX` | vfx | Toggle | `true` | |
| `DayNight` | realistic day / night | Toggle | `true` | |
| `Weather` | weather | Toggle | `true` | |
| `NoHeadTurn` | disable head turning | Toggle | `false` | |

## Adding a setting

1. Add it to `SettingsList.luau`. It shows in the panel and is saved right away.
2. Make something use it. Read it with `Settings.get(Id)`, or listen to `Settings.Changed`.

```luau
const Settings = require(ReplicatedStorage.Shared.Utility.Settings)

Settings.Changed:Connect(function(Id: string, Value)
    if Id == "Music" then
        MusicGroup.Volume = if Value then 1 else 0
    end
end)
```

A new setting does nothing until some code reads it.

## API

| Function | Description |
| --- | --- |
| `Settings.get(Id): Value?` | The current value |
| `Settings.enabled(Id): boolean` | Whether a toggle is on |
| `Settings.set(Id, Value): boolean` | Sets a value. Numbers are kept inside `Min` and `Max` |
| `Settings.toggle(Id): boolean` | Flips a toggle |
| `Settings.step(Id, Direction): boolean` | Moves a number up or down by its `Step` |
| `Settings.dirty(): boolean` | Whether there are unsaved changes |
| `Settings.save(): (boolean, string?)` | Saves to the server |
| `Settings.list(): { Setting }` | Every setting |

| Signal | Arguments | When |
| --- | --- | --- |
| `Settings.Changed` | `(Id, Value)` | A setting changes |
| `Settings.DirtyChanged` | `(boolean)` | Unsaved changes appear or are saved |

### Server

| Event | Kind | Description |
| --- | --- | --- |
| `@Settings/State` | to the player | The saved settings when they join |
| `@Settings/Save` | `When (Values)` | Saves the settings. Replies `{ Ok, Error }`. One save per second |

Unknown ids are dropped and numbers are kept in range before saving.

## Using it from your own code

```luau
const Utility = require(ReplicatedStorage.Shared.Utility)
const Settings = require(ReplicatedStorage.Shared.Utility.Settings)
```

| To | Call |
| --- | --- |
| Open or close the panel | `Utility.openSettings(true)` or `Utility.toggleSettings()` |
| Change a setting | `Settings.set("VFX", false)` |
| Flip a toggle | `Settings.toggle("Weather")` |
| Step a number | `Settings.step("MetaRange", 1)` |
| Save | `Settings.save()`. It yields, so run it in `task.spawn` from a button |

Changes made from code are not saved until `Settings.save()` runs.

## Your own UI

Screen name: **`Settings`**

### Updates

| Update | Value | When |
| --- | --- | --- |
| `Shown` | `boolean` | The panel opens or closes |
| `Values` | `{ [string]: boolean \| number }` | Any setting changes |
| `Dirty` | `boolean` | There are unsaved changes |

::: tip Build your rows from the list
The rows are not sent as an update. Build them from `Settings.list()` or `SettingsList` when your screen loads, then fill them from `Values`.
:::

### Actions

Send these with `Bridges.Settings:Call(Action, Id)`.

| Action | Value | What it does |
| --- | --- | --- |
| `"Toggle"` | setting `Id` | Flips a toggle |
| `"Up"` | setting `Id` | Raises a number by one step |
| `"Down"` | setting `Id` | Lowers a number by one step |
| `"Save"` | none | Saves and shows a toast |
| `"Close"` | none | Closes the panel |
