# Build mode

Players open the build panel with `B`, pick props from the catalog and place them in the world. They can move, rotate and scale them, select many at once in edit mode, and save groups of props to slots. Props can have states, like a light that is on or off, and hooks that run when they change.

- Prop definitions: `src/Shared/PropData/Definitions/`
- Prop types and helpers: `src/Shared/PropData/`
- Settings: `src/Shared/PropData/Config.luau`
- Client: `src/Shared/PropPlacer/`
- Bridges and types: `src/Shared/PropPlacer/Bridges.luau`
- Server: `src/Server/Props/`
- Built in screens: `BuildPanel.luau`, `SaveMenu.luau`, `PropWidget.luau` and `Toast.luau` in `src/Shared/GUI_Elements/`

## Controls

| Key | What it does |
| --- | --- |
| `B` | Opens the build panel. In edit mode it saves the selection |
| `Alt` | Turns edit mode on or off |
| `E`, `X` | In edit mode, edits or deletes the selection |
| `F` | Places or confirms |
| `X` | Cancels |
| `T`, `R`, `Y` | Move, rotate or scale handles |
| `Q` | Changes the snap step |
| `L` | Switches between world and local space |
| `M` | Switches between mouse and manual control |
| `C` | Changes the axis |

## Adding a prop

Make a module in `src/Shared/PropData/Definitions/` that returns props keyed by a number id. Every module in that folder is loaded on its own.

```luau
return {
    [40] = {
        Name = "Lamp",
        Model = "Props/Lamp",
        Limit = 10,
        States = {
            On = { Default = true },
        },
        onState = function(Prop, Name, Value)
            if Name == "On" and Prop.Model then
                Prop.Model.Bulb.PointLight.Enabled = Value
            end
        end,
    },
}
```

`Model` is a path inside `ServerStorage`, split by `/`. Ids are whole numbers from `1` and must not repeat.

### `Definition`

```luau
export type Definition = {
    Name: string,
    Pack: string?,
    Limit: number?,
    Model: string,
    Icon: CFrame?,
    MinScale: number?,
    MaxScale: number?,
    States: { [string]: StateSpec }?,
    Persist: boolean?,
    IdleRate: number?,
    Widget: Widget?,
    Info: boolean?,
    ServerBox: ServerBoxSpec?,
    onPlaced: ((Prop: Prop) -> ())?,
    onZoneEnter: ((Prop: Prop, Elapsed: number) -> ())?,
    onState: ((Prop: Prop, Name: string, Value: Value, Old: Value?) -> ())?,
    onMoved: ((Prop: Prop, Pivot: CFrame, Scale: number) -> ())?,
    onIdle: ((Prop: Prop, Delta: number) -> ())?,
    onRemoved: ((Prop: Prop) -> ())?,
    onPreview: ((Model: Model, States: States) -> ())?,
    onWidgetSave: ((Prop: Prop, Values: { [string]: any }) -> ())?,
    serialize: ((States: States, Owner: Player?) -> States)?,
    deserialize: ((Saved: States, Owner: Player?) -> States)?,
}
```

| Field | Description |
| --- | --- |
| `Name`, `Model` | Required |
| `Pack` | The pack a player must own. Leave it out for free props |
| `Limit` | Most of this prop one player can place |
| `Icon` | Camera framing for the catalog picture |
| `MinScale`, `MaxScale` | Scale limits. Default `0.25` to `4` |
| `States` | Values the prop keeps, see below |
| `Persist` | `false` keeps it out of saves |
| `IdleRate` | Shortest time between `onIdle` calls |
| `Widget` | Buttons and a settings window over the prop |
| `Info` | `false` hides the info button |
| `ServerBox` | A part the server moves, for things players stand on |

## States

A state is a value saved with the prop and synced to everyone near it.

```luau
export type StateSpec = {
    Default: Value,
    Save: boolean?,
    Public: boolean?,
    check: ((Value: Value, Player: Player?) -> boolean)?,
}

export type Value = boolean | number | string | Vector2 | Vector3 | Color3 | CFrame
```

- A new value must be the same type as `Default`. Text is at most 200 characters.
- `Save = false` keeps the state out of saves.
- `Public = true` lets anyone nearby change it. Otherwise only the owner can.
- `check` can turn down a value. It runs on the client and the server.

```luau
Prop:setState("On", false)
Prop:setPublicState("Knocks", Prop:getState("Knocks") + 1)
```

The server limits how fast states can change. A change it turns down is put back.

## Hooks

Hooks run on each client.

| Hook | When it runs |
| --- | --- |
| `onPlaced(Prop)` | The prop was just placed |
| `onZoneEnter(Prop, Elapsed)` | The prop loaded because you came near. `Elapsed` is seconds since it was placed |
| `onState(Prop, Name, Value, Old)` | A state changed |
| `onMoved(Prop, Pivot, Scale)` | The prop was moved or scaled |
| `onIdle(Prop, Delta)` | Every frame, or every `IdleRate` seconds |
| `onRemoved(Prop)` | The prop was removed or unloaded |
| `onPreview(Model, States)` | The ghost while placing |
| `onWidgetSave(Prop, Values)` | The owner pressed save in the widget window |
| `serialize(States, Owner)` | Before saving, to change what is saved |
| `deserialize(Saved, Owner)` | After loading a save |

### `Prop`

| Member | Description |
| --- | --- |
| `Key` | Unique key for this placed prop |
| `Id` | The definition id |
| `Owner` | Owner `UserId` |
| `Model` | The model, once loaded |
| `States` | Current states |
| `Data` | A free table for your own values |
| `getState(Name)` | Reads a state |
| `setState(Name, Value): boolean` | Sets a state, owner only |
| `setPublicState(Name, Value): boolean` | Sets a public state |
| `isOwner(): boolean` | Whether you own it |
| `elapsed(): number` | Seconds since it was placed |
| `enableWidgets(Enabled?)` | Shows the widget bar |
| `enableInfo(Enabled?)` | Shows the info button |

Prop methods are called with a colon, like `Prop:setState("On", true)`. Signals on a prop: `Placed`, `ZoneEntered`, `StateChanged`, `Moved`, `Removed`, `WidgetSaved` and `WidgetPressed`.

## Widgets

A widget is a small bar of buttons over a prop, and a window for changing its settings. Turn it on with `Prop:enableWidgets()`, usually in `onPlaced` and `onZoneEnter`.

```luau
export type Widget = {
    Title: string?,
    Fields: { Field }?,
    Buttons: { WidgetButton }?,
}

export type WidgetButton = {
    Id: string,
    Image: string?,
    Color: Color3?,
    Public: boolean?,
    pressed: ((Prop: Prop) -> ())?,
}

export type Field = {
    Id: string,
    Kind: "Color" | "Text" | "Number" | "Custom",
    Label: string?,
    State: string?,
    Default: any,
    Min: number?,
    Max: number?,
    Step: number?,
    Placeholder: string?,
    MaxLength: number?,
    Height: number?,
    build: ((Context: FieldContext) -> { [any]: any })?,
}
```

- A field with `State` writes its value to that state when the owner presses save, unless the prop has `onWidgetSave`.
- Buttons with `Public = true` show for everyone. Others show for the owner only.
- The bars show only while meta vision is on.

## Saves

Players have 5 prop save slots. A save keeps every prop's id, position, scale and saved states. It can be loaded **here**, near the player, or at the **spot** where it was saved.

```luau
export type PropSave = {
    Name: string,
    Stamp: number,
    Props: { SavedProp },
}
```

## Settings

| Field | Default | Description |
| --- | --- | --- |
| `MaxProps` | `110` | Most props one player can place |
| `DefaultBuild` | `false` | Lets everyone build without the build tool |
| `FreePacks` | `{}` | Packs everyone owns |
| `StudioOwnsAll` | `true` | Every pack is owned in Studio |
| `MaxReach` | `160` | How far from the player props can be placed or moved |
| `MinScale`, `MaxScale` | `0.25`, `4` | Default scale limits |
| `MaxBatch` | `200` | Most props in one place or move |
| `SaveSlots` | `5` | Prop save slots |
| `MaxSaveName` | `24` | Longest save name |
| `EditRange` | `150` | How far edit mode can select |
| `ZoneSize` | `256` | Size of the areas props load in |
| `JoinRange`, `LeaveRange` | `64`, `96` | When a player loads and unloads an area |
| `StateRate`, `StateBurst` | `20`, `40` | How fast states can change |
| `Increments` | see below | Snap steps |

```luau
Increments = {
    Translate = { 0, 0.5, 1, 2, 4 },
    Rotate = { 0, 15, 45, 90 },
    Scale = { 0, 0.05, 0.1, 0.25 },
},
```

`0` is free movement.

## API

| Function | Description |
| --- | --- |
| `PropData.add(Id, Definition): boolean` | Adds a prop from code |
| `PropData.get(Id)` | A prop's catalog info |
| `PropData.definition(Id): Definition?` | A prop's definition |
| `PropData.defaults(Id): States` | A prop's default states |
| `PropPlacer.toast(Text, Kind?)` | Shows a toast, see [Toasts](systems/toasts) |
| `PropPlacer.setVisible(Visible)` | Shows or hides the build panel |
| `Controller.setGate(Check)` | Blocks the panel. Return a reason string to block, or nil to allow |
| `Controller.canBuild(): boolean` | Whether the player may build |

`Controller.Shown` fires with `true` or `false` when the build panel opens or closes.

### Server

All prop events use the `Prop_Placer_Net` carrier.

| Event | Kind | Description |
| --- | --- | --- |
| `@Props/Place` | `When` | Places props |
| `@Props/Move` | `When` | Moves your props |
| `@Props/Delete` | `When` | Deletes your props |
| `@Props/Save` | `When (Slot, Keys?, Name?)` | Saves all props, or only the picked ones |
| `@Props/Rename` | `When` | Renames a save |
| `@Props/ClearSave` | `When` | Empties a save |
| `@Props/LoadSpot` | `When` | Places a save where it was saved |
| `@Props/Request` | `When` | Sends prop models to a client |
| `@Props/State` | `On` | The owner changed a state |
| `@Props/PublicState` | `On` | Someone changed a public state |
| `@Props/Stats` | to the player | Prop count and build rights |
| `@Props/Saves` | to the player | Save slots when they join |
| `@Props/Correct` | to the player | Puts back a state change that was turned down |
| `@Props/ZoneEnter`, `@Props/Delta` | to the area | Props in an area and changes to them |

## Using it from your own code

```luau
const PropPlacer = require(ReplicatedStorage.Shared.PropPlacer)
const Controller = require(ReplicatedStorage.Shared.PropPlacer.Controller)
const Placement = require(ReplicatedStorage.Shared.PropPlacer.Placement)
const EditMode = require(ReplicatedStorage.Shared.PropPlacer.EditMode)
const Saves = require(ReplicatedStorage.Shared.PropPlacer.Saves)
const BuildTools = require(ReplicatedStorage.Shared.PropPlacer.Tools)
const Utility = require(ReplicatedStorage.Shared.Utility)
```

| To | Call |
| --- | --- |
| Open or close the panel, like `B` | `Controller.togglePanel()`. It checks the gate first |
| Show or hide the panel directly | `PropPlacer.setVisible(true)` |
| Start placing a prop | `Placement.place(Id)` |
| Cancel placing | `Placement.cancel()` |
| Enter or leave edit mode | `EditMode.enter()`, `EditMode.exit()` or `EditMode.toggle()` |
| Move or delete the selection | `task.spawn(EditMode.editSelected)` or `task.spawn(EditMode.deleteSelected)` |
| Open the prop saves | `Saves.open()` |
| Press a move tool | `BuildTools.action("Rotate")` |
| Stop players building | `Controller.setGate(function() return "Not here" end)`. Return nil to allow |
| Lock build mode | `Controller.setLocked(true)` closes everything and ignores the keys |
| Turn prop collisions on or off | `Utility.setCollisions(true)` |
| Know when the panel opens | `Controller.Shown:Connect(function(Open) end)` |

### Keys

| Key | Where to change it |
| --- | --- |
| `B` | `Controller.PanelKey` |
| Move tool keys | `BuildTools.Keys`, a table of key to tool name |
| `Alt`, and `E` and `X` in edit mode | Fixed in `src/Shared/PropPlacer/Controller.luau` |

```luau
Controller.PanelKey = Enum.KeyCode.N
BuildTools.Keys[Enum.KeyCode.F] = nil
BuildTools.Keys[Enum.KeyCode.Return] = "Place"
```

## Your own UI

Build mode uses four screens: **`BuildPanel`**, **`SaveMenu`**, **`PropWidget`** and **`Toast`**. See [Toasts](systems/toasts) for that one.

### `BuildPanel`

| Update | Value | When |
| --- | --- | --- |
| `Toggle` | `boolean` | The panel opens or closes |
| `Mode` | `"Browse"` or `"Edit"` | Edit mode starts or ends |
| `LoadPage` | `{ Entry }` | A catalog page loads |
| `Page` | `number` | The page number changes |
| `Tools` | `ToolView` | The move tools change |
| `CountCurrent`, `CountMax` | `number` | Props placed and the limit |
| `Selected` | `number` | How many props are selected |

```luau
export type Entry = {
    Id: number?,
    Name: string,
    Pack: string?,
    Limit: (number | string)?,
    Model: PVInstance?,
    CFrame: CFrame?,
}

export type ToolView = {
    Visible: boolean,
    Kind: string,
    Increment: string,
    Space: string,
    Control: string?,
    Axis: string?,
    Busy: boolean,
}
```

::: warning Toggle is read back
The system also calls `Toggle()` and `Page()` with nothing to read the current value. A plain table screen must return the current value when called with `nil`.
:::

The build panel uses a different bridge for each kind of press.

| Call | Value | What it does |
| --- | --- | --- |
| `Bridges.Page:Call(Requested, Current)` | page numbers | Asks for a page. Returns the page shown |
| `Bridges.Search:Call(Text)` | search text | Searches the catalog. Returns the page shown |
| `Bridges.Select:Call(Entry)` | a catalog entry | Starts placing it |
| `Bridges.Tool:Call(Name)` | tool name | A move tool button |
| `Bridges.Action:Call(Action)` | action name | A panel button |

Tool names: `"Place"`, `"Cancel"`, `"Increment"`, `"Space"`, `"Control"`, `"Axis"`, `"Translate"`, `"Rotate"` and `"Scale"`.

| Action | What it does |
| --- | --- |
| `"Saves"` | Opens the save menu |
| `"Edit"`, `"Exit"` | Enters or leaves edit mode |
| `"EditSelected"` | Moves the selected props |
| `"DeleteSelected"` | Deletes them |
| `"SaveSelected"` | Saves only them |
| `"Opened"`, `"Closed"` | Send these when your panel opens or closes |

### `SaveMenu`

| Update | Value | When |
| --- | --- | --- |
| `Shown` | `boolean` | The menu opens or closes |
| `Slots` | `{ [number]: SaveSlot }` | Saves change |
| `Hint` | `string` | The help text changes |
| `Ask` | slot `number` or `false` | Asking where to load a slot, or closing that question |

```luau
export type SaveSlot = {
    Name: string,
    Detail: string,
    Stamp: string,
    Filled: boolean,
    Confirm: boolean,
    ConfirmClear: boolean,
}
```

`Confirm` and `ConfirmClear` are true while a second press is needed to overwrite or clear.

Send these with `Bridges.Saves:Call(Action, Slot, Text)`.

| Action | Slot | What it does |
| --- | --- | --- |
| `"Save"` | slot | Saves, with a confirm if full |
| `"Load"` | slot | Asks where to load it |
| `"Here"` | none | Loads the asked slot near you |
| `"Spot"` | none | Loads it where it was saved |
| `"Back"` | none | Closes the question |
| `"Clear"` | slot | Empties it, after a confirm |
| `"Name"` | slot | Names it. Send the text as the third value |
| `"Close"` | none | Closes the menu |

### `PropWidget`

`PropWidget` works differently from the other screens. It is never mounted. Instead the system calls three builder functions and mounts what they return itself. Each one gets a spec with callbacks, so there is no bridge.

| Function | Spec | Builds |
| --- | --- | --- |
| `bar(Spec)` | `BarSpec` | The button bar over a prop |
| `window(Spec)` | `WindowSpec` | The settings window |
| `info(Spec)` | `InfoSpec` | The info card |

```luau
export type BarSpec = {
    Name: string,
    Adornee: Instance,
    Mount: Instance,
    Buttons: { BarButton },
    Size: number,
    MaxDistance: number,
    Shown: boolean,
}

export type BarButton = { Id: string, Image: string?, Color: Color3?, press: () -> () }

export type WindowSpec = {
    Name: string,
    Title: string,
    Fields: { PropData.Field },
    Values: { [string]: any },
    Position: Vector2,
    Mount: Instance,
    save: () -> (),
    close: () -> (),
    focus: (Root: GuiObject) -> (),
}

export type InfoSpec = {
    Name: string,
    Title: string,
    Rows: { InfoRow },
    Position: Vector2,
    Mount: Instance,
    close: () -> (),
    focus: (Root: GuiObject) -> (),
}

export type InfoRow = { Label: string, Value: string }
```

- Call `press()` when a bar button is pressed, `save()` and `close()` from the window, and `focus(Root)` when a window is clicked so it comes to the front.
- The window writes field values into `Spec.Values` by field `Id`.
- The builders return a vision declaration. The built in module in `src/Shared/GUI_Elements/PropWidget.luau` is the best place to start.
