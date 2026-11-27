# Dice

Players open the roll menu from the side bar, pick a die and roll it. The die spins in the menu and over the player's head so everyone can see the number. A roll can add a bonus from one of the player's stats and a modifier they type, like `-1 missing arm`.

- System: `src/Shared/Dice/init.luau`
- Dice list: `src/Shared/Dice/Kinds.luau`
- Bridge and types: `src/Shared/Dice/Bridges.luau`
- Server: `src/Server/Dice.luau`
- Built in screen: `src/Shared/GUI_Elements/Dice.luau`
- Die models: `ReplicatedStorage.DiceModels`, one model per die named after its `Id`

## Dice list

```luau
export type Kind = {
    Id: string,
    Name: string,
    Sides: number,
    Order: number,
}
```

The template has `D4`, `D6`, `D8`, `D10`, `D12`, `D20` and `D100`, each like `{ Id = "D4", Name = "d4", Sides = 4, Order = 1 }`. To add a die, add an entry and put a model with the same name in `ReplicatedStorage.DiceModels`.

## How a roll works

1. The client asks the server with `@Dice/Roll`, sending the die, the picked stat and the modifier number.
2. The server checks the die and the cooldown, rolls `1` to `Sides`, adds the stat bonus and the modifier, and tells every player with `@Dice/Rolled`.
3. Every client shows the die over the roller's head. The roller's menu plays the spin too.
4. `Dice.Rolled` fires on every client once the spin ends. The [action log](systems/action-log) listens to it.

The modifier is read from the start of the text, so `-1 missing arm` gives `-1` with the note `missing arm`. It is clamped to `99` either way.

## Settings

Fields on the `Dice` module:

| Field | Default | Description |
| --- | --- | --- |
| `FolderName` | `"DiceModels"` | Folder in ReplicatedStorage with the die models |
| `RollTime` | `0.9` | Seconds the die spins |
| `FlickerRate` | `0.07` | Seconds between the random numbers shown while it spins |
| `CameraSpot` | `Vector3.new(0, 1.4, 5.2)` | Camera position in the menu viewport |
| `FieldOfView` | `40` | Camera field of view in the menu viewport |
| `HeadSize` | `2.2` | Size of the die over the head |
| `HeadLift` | `1.9` | How high over the head it floats |
| `HeadRange` | `120` | How far away others can see it |
| `HoldTime` | `3.5` | Seconds it stays after landing |

On the server, `Cooldown = 2` is the seconds between one player's rolls and `MaxModifier = 99` caps the modifier.

## API

### `Dice.roll(Id: string)`

Rolls the die with that id. Does nothing while a roll is still spinning.

### `Dice.show(Value: boolean)`

Shows or hides the roll menu. `Dice.toggle()` flips it and `Dice.isShown()` reads it.

### `Dice.modifier(Text: string): (number, string)`

Reads a signed number from the start of the text and returns it with the rest as a note. Returns `0, ""` if there is no number.

### `Dice.describe(Kind: Kind, Result: number, Info: Info): string`

Turns a roll into text, like `14 +2 strength -1 missing arm = 15`. With no bonus or modifier it is just the number.

```luau
export type Info = {
    Stat: string?,
    Bonus: number,
    Modifier: number,
    Total: number,
    Note: string?,
}
```

### Signals

| Signal | Arguments | When |
| --- | --- | --- |
| `Dice.Rolled` | `(Player, Kind, Result, Info)` | Any player's roll finished spinning |
| `Dice.Changed` | none | The menu updated |

### Server events

Both sides use the `Dice_Net` carrier.

| Event | Kind | Description |
| --- | --- | --- |
| `@Dice/Roll` | `When (Id, StatId, Modifier)` | A roll request. Replies `{ Ok, Error, Result }` |
| `@Dice/Rolled` | broadcast `(Player, Id, Result, { Stat, Bonus, Modifier, Total })` | A roll everyone should see |

## Using it from your own code

```luau
const Dice = require(ReplicatedStorage.Shared.Dice)
const Bridges = require(ReplicatedStorage.Shared.Dice.Bridges)
```

| To | Call |
| --- | --- |
| Open or close the menu | `Dice.show(true)`, `Dice.show(false)` or `Dice.toggle()` |
| Roll a die | `Dice.roll("D20")` |
| Pick the stat to add | `Bridges.Dice:Call("Stat", "Strength")`, or `"none"` |
| Set the modifier | `Bridges.Dice:Call("Modifier", "-1 missing arm")` |
| Roll the last die again | `Bridges.Dice:Call("Again")` |
| React to every roll | `Dice.Rolled:Connect(function(Player, Kind, Result, Info) end)` |

The stat and modifier have no function of their own, so set them through the bridge. The bridge works from any client script once the dice have started.

The dice have no key. This rolls a d20 on `J`:

```luau
UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
    if not Processed and Input.KeyCode == Enum.KeyCode.J then
        Dice.roll("D20")
    end
end)
```

## Your own UI

Screen name: **`Dice`**

::: warning Keep a viewport named Dice_View
After your screen is mounted, the system looks for a `ViewportFrame` named `Dice_View` anywhere inside it and spins the 3D die in it. Without one, the menu works but shows no die.
:::

### Updates

| Update | Value | When |
| --- | --- | --- |
| `DiceShown` | `boolean` | The menu opens or closes |
| `DiceKinds` | `{ DieCard }` | The dice list or the last picked die changes |
| `DiceStats` | `{ Choice }` | The stat list or the player's stats change |
| `DiceResult` | `{ Text: string, Big: boolean }` | During the spin with random numbers, then with the final text |

```luau
export type DieCard = {
    Id: string,
    Name: string,
    Active: boolean,
}

export type Choice = {
    Id: string,
    Name: string,
    Active: boolean,
}
```

`DiceStats` starts with `{ Id = "none", Name = "no stat" }`, then one entry per stat, named like `strength (+2)`.

### Actions

Send these with `Bridges.Dice:Call(Action, Value)`.

| Action | Value | What it does |
| --- | --- | --- |
| `"Close"` | none | Closes the menu |
| `"Roll"` | die `Id` | Rolls that die |
| `"Again"` | none | Rolls the last picked die again |
| `"Stat"` | stat `Id` or `"none"` | Picks the stat to add |
| `"Modifier"` | `string` | The modifier text box, up to 60 characters. Send it as the player types |
