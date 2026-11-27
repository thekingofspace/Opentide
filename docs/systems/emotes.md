# Emotes

A panel with a list of emotes to play. Pressing an emote again stops it. Emotes can not be played while holding a tool, and a tool taken out stops the emote.

- System: `src/Shared/Emotes/init.luau`
- Emote list: `Defaults.Emotes` in `src/Shared/AnimationController/Defaults.luau`
- Bridge and types: `src/Shared/Emotes/Bridges.luau`
- Built in screen: `src/Shared/GUI_Elements/Emotes.luau`

## Adding an emote

Add an entry to `Defaults.Emotes`. The key is the emote id. The template has `Point`, `Wave`, `Cheer`, `Laugh` and `Dance`.

```luau
export type EmoteRef = {
    Name: string,
    Label: string?,
    Order: number?,
    Part: Target?,
    Looped: boolean?,
    Crouch: string?,
}
```

| Field | Default | Description |
| --- | --- | --- |
| `Name` | required | The animation name in the animation library |
| `Label` | the id in lower case | The name shown in the panel |
| `Order` | `99` | Sort order |
| `Part` | `"Full"` | Which body part it plays on: `"Full"`, `"Legs"` or `"Body"` |
| `Looped` | off | Keeps playing until stopped |
| `Crouch` | none | A different animation to use while crouching |

## API

### `Emotes.play(Id: string): boolean`

Plays an emote, or stops it if it is already playing. Returns `false` and shows a toast if a tool is out or the player is moving.

### `Emotes.show(Value: boolean)`

Shows or hides the panel. `Emotes.toggle()` flips it and `Emotes.isShown()` reads it.

`Emotes.Changed` fires when the panel is shown or hidden. `Emotes.start()` runs once on the client and is called by the side bar code for you.

## Using it from your own code

```luau
const Emotes = require(ReplicatedStorage.Shared.Emotes)
const LocalAnimations = require(ReplicatedStorage.Shared.AnimationController.LocalAnimations)
```

| To | Call |
| --- | --- |
| Open or close the panel | `Emotes.show(true)`, `Emotes.show(false)` or `Emotes.toggle()` |
| Play an emote, or stop it if it is playing | `Emotes.play("Wave")` |
| Stop the emote | `LocalAnimations.stopEmote()` |
| Read what is playing | `LocalAnimations.emoting()` |

Emotes have no keys. This adds emote hotkeys:

```luau
const EmoteKeys = {
    [Enum.KeyCode.Z] = "Wave",
    [Enum.KeyCode.N] = "Point",
}

UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
    const Id = EmoteKeys[Input.KeyCode]
    if Id and not Processed then
        Emotes.play(Id)
    end
end)
```

Avoid `1` to `5`, which take out tools.

## Your own UI

Screen name: **`Emotes`**

### Updates

| Update | Value | When |
| --- | --- | --- |
| `EmotesShown` | `boolean` | The panel opens or closes |
| `EmoteList` | `{ EmoteCard }` | The panel opens, an emote starts or stops |

```luau
export type EmoteCard = {
    Id: string,
    Name: string,
    Active: boolean,
}
```

`Active` is true for the emote that is playing.

### Actions

Send these with `Bridges.Emotes:Call(Action, Value)`.

| Action | Value | What it does |
| --- | --- | --- |
| `"Close"` | none | Closes the panel |
| `"Play"` | emote `Id` | Plays that emote, or stops it if it is playing |
| `"Stop"` | none | Stops the emote that is playing |
