# Action log

A personal log for keeping track of a roleplay. Players add the people they are playing with, and every dice roll from them shows up in the log. There is a text box for writing your own notes. The log lives on your screen only, nothing is saved or sent.

- System: `src/Shared/ActionLog/init.luau`
- Bridge and types: `src/Shared/ActionLog/Bridges.luau`
- Built in screen: `src/Shared/GUI_Elements/ActionLog.luau`

## How it works

- Press **add player**, then click a player in the world to track them. Press Escape to cancel.
- Your own rolls are always logged. Rolls from tracked players are logged too.
- Notes you type are added with the `Note` kind.
- When a tracked player leaves, a line says so.

Each entry has a `Kind`. The built in screen tags `Roll`, `Note` and `System`.

## Settings

Fields on the `ActionLog` module:

| Field | Default | Description |
| --- | --- | --- |
| `MaxEntries` | `300` | The oldest entries are removed past this |
| `MaxNote` | `200` | Longest note in characters |
| `PickRange` | `1000` | How far the add player click reaches |

## API

### `ActionLog.add(Text: string, Kind: string?)`

Adds an entry. `Kind` defaults to `"System"`. Use this to log things from your own systems.

```luau
const ActionLog = require(ReplicatedStorage.Shared.ActionLog)

ActionLog.add("the door was unlocked", "System")
```

### `ActionLog.track(Player: Player)`

Adds a player to the log. Shows a toast if it is you or they are already tracked.

### `ActionLog.untrack(Id: number)`

Removes a player by `UserId`.

### `ActionLog.show(Value: boolean)`

Shows or hides the log. `ActionLog.toggle()` flips it and `ActionLog.isShown()` reads it.

`ActionLog.Changed` fires when the log updates. `ActionLog.start()` runs once on the client and is called by the side bar code for you.

## Using it from your own code

```luau
const ActionLog = require(ReplicatedStorage.Shared.ActionLog)
const Bridges = require(ReplicatedStorage.Shared.ActionLog.Bridges)
```

| To | Call |
| --- | --- |
| Open or close the log | `ActionLog.show(true)`, `ActionLog.show(false)` or `ActionLog.toggle()` |
| Add a line | `ActionLog.add("the door was unlocked")` |
| Add a line with a tag | `ActionLog.add("found a key", "Note")` |
| Track a player | `ActionLog.track(Player)` |
| Stop tracking | `ActionLog.untrack(Player.UserId)` |
| Pick the next clicked player | `Bridges.Log:Call("Pick")` |
| Clear the log | `Bridges.Log:Call("Clear")` |

Escape cancels picking a player. It is fixed in `src/Shared/ActionLog/init.luau`.

## Your own UI

Screen name: **`ActionLog`**

### Updates

| Update | Value | When |
| --- | --- | --- |
| `LogShown` | `boolean` | The log opens or closes |
| `LogPlayers` | `{ PlayerChip }` | A player is added or removed |
| `LogState` | `LogView` | Pick mode or the entry count changes |
| `LogEntries` | `{ EntryRow }` | An entry is added or the log is cleared |

```luau
export type PlayerChip = {
    Id: number,
    Name: string,
}

export type EntryRow = {
    Id: number,
    Time: string,
    Text: string,
    Kind: string,
}

export type LogView = {
    Picking: boolean,
    Count: number,
}
```

`PlayerChip.Id` is the `UserId`. `EntryRow.Time` is already formatted like `14:05`. `LogView.Picking` is true while the next click picks a player, so you can show a hint.

### Actions

Send these with `Bridges.Log:Call(Action, Value)`. The bridge field is named `Log`.

| Action | Value | What it does |
| --- | --- | --- |
| `"Close"` | none | Closes the log |
| `"Pick"` | none | Starts or stops pick mode |
| `"Remove"` | `UserId` | Stops tracking that player |
| `"Note"` | `string` | Adds a note. Send it when the player presses Enter |
| `"Clear"` | none | Clears every entry |
