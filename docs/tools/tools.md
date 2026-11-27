# Tools

Tools are held items like the bat, pistols, shield, bread and throwing knives. Players put up to 5 of them on the hotbar from customize, change their parts, and equip them with `1` to `5`. Two linked tools are held one in each hand.

- Shared: `src/Shared/Tools/init.luau`
- Client: `src/Shared/Tools/Client.luau`
- Server: `src/Server/Tools.luau`
- Tool definitions: `src/Shared/Tools/Items/`
- Part definitions: `src/Shared/Tools/Attachments/`
- Settings: `src/Shared/Tools/Config.luau`
- Bridge and types: `src/Shared/Tools/Bridges.luau`
- Built in screen: `src/Shared/GUI_Elements/Tools/init.luau`

Every tool and part is a premade model in `ServerStorage.ToolAssets.Tools` and `ServerStorage.ToolAssets.Attachments`. Clients ask the server for the models they need. Hotbar slots start empty when a player joins and are filled from customize or a look save.

## Adding a tool

Make a module in `src/Shared/Tools/Items/` that returns a table of tool definitions keyed by id. Every module in that folder is loaded on its own.

```luau
const Guns = require(ReplicatedStorage.Shared.Tools.Guns)

const Items: { [string]: Tools.ToolDef } = {
    Pistol = {
        Name = "Pistol",
        Category = "Guns",
        Order = 1,
        Description = "a basic pistol",
        Mounts = {
            { Id = "Frame", Label = "body", Accepts = { "PistolFrame" }, Offset = CFrame.identity, Required = true },
        },
        Defaults = {
            Frame = "StandardFrame",
            ["Frame/Barrel"] = "StandardBarrel",
        },
        Stats = { Bullet = "Standard", FireRate = 0.22, Magazine = 12 },
        Equip = "Equip",
        Unequip = "PutAway",
        Dual = { Tags = { "Gun" }, With = { "Gun", "Shield" } },
        client = Guns.client(),
        server = Guns.server(),
    },
}

return Items
```

Then put a model named `Pistol` in `ServerStorage.ToolAssets.Tools`.

### `ToolDef`

```luau
export type ToolDef = {
    Name: string,
    Category: string,
    Pack: string?,
    Order: number?,
    Description: string?,
    Grip: CFrame?,
    Mounts: { Mount }?,
    Defaults: { [string]: string }?,
    Clips: { [string]: ClipValue }?,
    Sets: { [string]: SetSpec }?,
    Equip: string?,
    Unequip: string?,
    Actions: { Action }?,
    Stats: { [string]: any }?,
    AllowCrawl: boolean?,
    Hand: ("Right" | "Left")?,
    OneHand: boolean?,
    Dual: DualRule?,
    Click: boolean?,
    client: { [string]: any }?,
    server: { [string]: any }?,
}
```

| Field | Description |
| --- | --- |
| `Name`, `Category` | Required. `Category` groups tools in customize, see `Config.Categories` |
| `Pack` | The pack a player must own to use it. Leave it out for free tools |
| `Order` | Sort order inside its category |
| `Grip` | Rotation in the hand. Defaults to `Config.Grip` |
| `Mounts` | Spots where parts attach, see below |
| `Defaults` | The part picked for each mount path in a new build, like `["Frame/Barrel"] = "StandardBarrel"` |
| `Clips` | Animations by name, as pose data or an animation id |
| `Sets` | Groups of animations that replace the normal ones while on, like `Held` |
| `Equip`, `Unequip` | Clip names played when the tool is taken out and put away |
| `Actions` | Buttons on the action bar, each with an optional key |
| `Stats` | Any numbers or values your hooks read. Parts change them with `Mods` |
| `AllowCrawl` | Lets the player crawl while holding it |
| `Hand` | `"Left"` makes it go in the left hand, like the shield |
| `OneHand` | Keeps the hold animation on one arm so the other arm still swings |
| `Dual` | Which tools it can be linked with |
| `Click` | `false` means clicking never uses it while two tools are held |
| `client`, `server` | Hook tables, see below |

```luau
export type Action = {
    Id: string,
    Label: string,
    Key: Enum.KeyCode?,
    Toggle: boolean?,
}

export type SetSpec = {
    Full: { [string]: string }?,
    Legs: { [string]: string }?,
    Body: { [string]: string }?,
}

export type DualRule = {
    Tags: { string },
    With: { string },
}
```

An action with `Toggle = true` flips on and off each press and shows as on in the action bar.

## Parts

Parts are attachments that plug into a tool's mounts. A part can have mounts of its own, so a frame can hold a barrel that holds a muzzle. Mount paths join ids with `/`, like `"Frame/Barrel"`.

```luau
export type Mount = {
    Id: string,
    Accepts: { string },
    Offset: CFrame,
    Label: string?,
    Required: boolean?,
}

export type AttachmentDef = {
    Name: string,
    Kind: string,
    Pack: string?,
    Order: number?,
    Description: string?,
    Offset: CFrame?,
    Mounts: { Mount }?,
    Mods: { [string]: any }?,
}
```

A mount takes any part whose `Kind` is in its `Accepts` list. A `Required` mount is always filled. Put part definitions in `src/Shared/Tools/Attachments/` and the models in `ServerStorage.ToolAssets.Attachments`.

### Mods

`Mods` change the tool's `Stats`. A key that ends in `Scale` multiplies the stat with the same name. Any other key replaces the stat.

```luau
Scope = {
    Name = "Scope",
    Kind = "Sight",
    Mods = { SpreadScale = 0.5 },
},
HeavyFrame = {
    Name = "Heavy Frame",
    Kind = "PistolFrame",
    Mods = { FireSound = 3102797479, FireRateScale = 1.6 },
},
```

Mods apply from the tool outward, so a muzzle's mods apply after its barrel's.

## Client hooks

Put these in the tool's `client` table. Each one gets the tool's `Context`.

| Hook | Arguments | When it runs |
| --- | --- | --- |
| `onEquip` | `(Context)` | After the tool is taken out and its `Equip` clip starts |
| `onUnequip` | `(Context)` | When it is put away, swapped, or the player respawns |
| `onActivate` | `(Context)` | Left click. Return `false` if it could not act, so the other hand gets the click |
| `onRelease` | `(Context)` | Left click let go, on the hand that took the click |
| `onAction` | `(Context, Id, On)` | An action key or button. `On` is the toggle state |
| `onPairAction` | `(Pair, Id)` | An action while two tools are held. Without it each tool gets `onAction` |
| `onPairActivate` | `(Pair)` | Left click while two tools are held. Return true to say you handled it |

All sets in `Sets` are removed and clips stopped for you after `onUnequip`.

### `Context`

| Member | Description |
| --- | --- |
| `Id` | The tool id |
| `Slot` | The slot key, `"1"` to `"5"` |
| `Hand` | `"Right"` or `"Left"` |
| `Side` | `"Body"` for a normal two handed hold, or the hand for one handed tools and pairs |
| `Def` | The tool definition |
| `Data` | A free table for your own state. `Data.Live` is true while the tool is out |
| `States` | Toggle states of actions |
| `Labels` | Label overrides for actions |
| `Pair` | The pair while two tools are held |
| `play(Name, Options?)` | Plays a clip. Uses `Name_OneHand` while paired if it exists. `{ Whole = true }` keeps torso keys |
| `stop(Name)` | Stops a clip |
| `pushSet(Name)`, `popSet(Name)` | Turns a set from `Sets` on or off |
| `active(Id)`, `setActive(Id, On)` | Reads or sets an action's on state |
| `setLabel(Id, Text?)` | Changes an action's label on the bar |
| `send(Id, Value?)` | Sends an action to the server `onAction` hook |
| `fire(Shot)` | Sends a shot to the server, used by guns |
| `model()` | The held model |
| `build()` | The slot's build |
| `stats()` | The tool's stats with all part mods applied |
| `mount(Path)` | The attachment for a mount path in the held model |
| `other()` | The other tool in the pair |

Context functions are called with a dot, like `Context.play("Swing")`.

```luau
client = {
    onEquip = function(Context)
        Context.pushSet("Held")
    end,
    onActivate = function(Context)
        if Context.Data.Swinging then
            return false
        end
        Context.Data.Swinging = true
        Context.play("Swing")
        Context.send("Swing")
        task.delay(0.8, function()
            Context.Data.Swinging = false
        end)
    end,
},
```

### `Pair`

| Member | Description |
| --- | --- |
| `Main` | The tool in the slot that was pressed |
| `Off` | The linked tool |
| `Right`, `Left` | The tools by hand |
| `Data` | A free table shared by both |

## Server hooks

Put these in the tool's `server` table. They get the player, not a context.

| Hook | Arguments | When it runs |
| --- | --- | --- |
| `onEquip` | `(Player, Model, Hand)` | The model is welded to the hand |
| `onUnequip` | `(Player)` | The model was removed |
| `onAction` | `(Player, Model, Id, Value)` | The client called `Context.send` |
| `onFire` | `(Player, Model, { Origin, Hit, Normal }, Stats)` | A shot passed the server checks |

## Linking and dual wielding

Two tools can be linked if each one's `Dual.With` shares a tag with the other's `Dual.Tags`.

```luau
Dual = { Tags = { "Gun" }, With = { "Gun", "Shield" } },
```

- Left click takes turns between the hands. A hand that returns `false` from `onActivate` passes the click on.
- Right click does nothing while two tools are held.
- Animations are made for the right hand. The left hand plays a mirrored copy.
- Name a clip with `_OneHand` on the end to use it while paired, like `Hold_OneHand`.

## API

### Shared

| Function | Description |
| --- | --- |
| `Tools.get(Id): ToolDef?` | A tool definition |
| `Tools.attachment(Id): AttachmentDef?` | A part definition |
| `Tools.list()`, `Tools.attachments()` | Every tool or part by id |
| `Tools.categories(): { Category }` | Tools grouped by category |
| `Tools.add(Id, Def): boolean` | Adds a tool from code |
| `Tools.addAttachment(Id, Def): boolean` | Adds a part from code |
| `Tools.stats(Build?): { [string]: any }` | Stats with every part's mods applied |
| `Tools.canPair(First, Second): boolean` | Whether two tools can be linked |
| `Tools.choices(Mount): { string }` | Part ids that fit a mount |
| `Tools.mountAt(ToolId, Parts, Path): Mount?` | The mount at a path |
| `Tools.clean(ToolId, Raw, Owns, UseDefaults?): ToolBuild?` | Fixes up a build so it is valid |
| `Tools.fresh(ToolId, Owns): ToolBuild?` | A new build with default parts |
| `Tools.assemble(Build): Model?` | Builds the model with all its parts, or nil until the models are loaded |
| `Tools.grip(Def, Hand): CFrame` | The hold offset for a hand |

```luau
export type ToolBuild = {
    Tool: string,
    Parts: { [string]: string },
    Holster: ToolHolster?,
}
```

### Client

| Function | Description |
| --- | --- |
| `Client.equip(Slot: number)` | Takes out a slot, or puts it away if it is out |
| `Client.unequip()` | Puts the tool away with its animation |
| `Client.unequipNow()` | Puts it away right away |
| `Client.current(): Context?` | The main held tool |
| `Client.offhand(): Context?` | The other held tool |
| `Client.slots()` | Every slot's build |
| `Client.link(Slot: number)` | Starts or finishes linking two slots |
| `Client.unlinkAll()` | Removes every link |
| `Client.blockInput(Reason: string, Value: boolean)` | Stops tool keys and clicks, like while the ruler is on |
| `Client.setBlocked(Value: boolean)` | Hides the tool screen and blocks input |
| `Client.setSlot(Slot, Build): (boolean, string?)` | Saves a build to a slot |
| `Client.clearSlot(Slot): (boolean, string?)` | Empties a slot |
| `Client.allows(Flag: string): boolean` | Whether every held tool sets a flag like `AllowCrawl` |

`Client.Equipped` fires with the tool id when a tool is taken out and `nil` when it is put away. `Client.Changed` fires when the slots change.

### Server

| Function | Description |
| --- | --- |
| `Tools.held(Player, Hand): (Held?, ToolBuild?)` | What a player holds in a hand |
| `Tools.equipped(Player): (string?, Model?)` | The main tool id and model |
| `Tools.build(Player, Slot): ToolBuild?` | A slot's build |
| `Tools.hide(Player, Slot, On)` | Hides a slot's model, used by throwables |
| `Tools.snapshot(Player)` | Every slot's build |

`Tools.Changed` fires with `(Player, { Slot })` when slots change.

### Network

All tool events use the `Tools_Net` carrier.

| Event | Kind | Description |
| --- | --- | --- |
| `@Tools/Equip` | `When (Slot)` | Takes out a slot. No slot puts the tool away |
| `@Tools/Set` | `When (Slot, Build)` | Saves a build to a slot |
| `@Tools/Clear` | `When (Slot)` | Empties a slot |
| `@Tools/Link` | `When (First, Second)` | Links two slots |
| `@Tools/Unlink` | `When (Slot)` | Unlinks a slot |
| `@Tools/UnlinkAll` | `When ()` | Unlinks everything |
| `@Tools/LoadSave` | `When (Slot)` | Loads the tools from a look save |
| `@Tools/Assets` | `When (Keys)` | Sends the tool and part models a client needs |
| `@Tools/Action` | `On (Id, Value, Hand)` | Runs the server `onAction` hook |
| `@Tools/Fire` | `On (Origin, Hit, Normal, Hand)` | A gun shot |
| `@Tools/State` | to the owner | `{ Slots, Equipped, Links, Hands }` |

## Settings

| Field | Default | Description |
| --- | --- | --- |
| `Slots` | `5` | Hotbar slots |
| `MaxDepth` | `4` | How deep parts can nest |
| `MaxHolsterOffset` | `3` | How far a holstered tool can sit from the body |
| `MinSize`, `MaxSize` | `0.5`, `1.5` | Holster size limits |
| `GripPosition` | `Vector3.new(0, -0.15, 0)` | Hold spot when the hand has no grip attachment |
| `Grip` | `CFrame.Angles(math.rad(-90), 0, 0)` | Default hold rotation |
| `EquipCooldown` | `0.25` | Seconds between equips |
| `Categories` | melee, throwing, guns, food | Display name and order for each category |

## Using it from your own code

```luau
const ToolsClient = require(ReplicatedStorage.Shared.Tools.Client)
const Bridges = require(ReplicatedStorage.Shared.Tools.Bridges)
```

| To | Call |
| --- | --- |
| Take out a slot | `ToolsClient.equip(2)` |
| Put the tool away | `ToolsClient.unequip()` |
| Run a tool action | `Bridges.Hud:Call("Action", "Reload")`. This is the same as pressing its key, and works for two held tools too |
| Link two slots | `ToolsClient.link(1)`, then `ToolsClient.link(2)` |
| Remove every link | `ToolsClient.unlinkAll()` |
| Stop tool keys and clicks while your menu is open | `ToolsClient.blockInput("MyMenu", true)`, then `false` to allow again |
| Hide the hotbar and block input | `ToolsClient.setBlocked(true)` |
| Get the held tool | `ToolsClient.current()` returns its `Context` |
| Know when a tool is taken out | `ToolsClient.Equipped:Connect(function(ToolId) end)`. `ToolId` is nil when put away |

`blockInput` takes a reason, so several menus can block at once. Input comes back when every reason is cleared.

### Keys

| Key | Where to change it |
| --- | --- |
| `1` to `5` | `ToolsClient.Keys`, a table of key to slot number |
| Tool action keys | `Key` on each action in the tool's definition |

```luau
ToolsClient.Keys[Enum.KeyCode.One] = nil
ToolsClient.Keys[Enum.KeyCode.Z] = 1
```

## Your own UI

Screen name: **`Tools`**. It is the hotbar and the action bar.

### Updates

| Update | Value | When |
| --- | --- | --- |
| `HotbarShown` | `boolean` | The hotbar is hidden, like during build mode |
| `HotbarOpen` | `boolean` | The hotbar tray is opened or closed |
| `HotbarSlots` | `{ SlotView }` | Slots, links or the held tool change |
| `ActionBar` | `BarView` or `false` | The held tools change. `false` hides the bar |
| `ActionBarOpen` | `boolean` | The action tray is opened or closed |

```luau
export type SlotView = {
    Slot: number,
    Name: string,
    Tool: string?,
    Model: Instance?,
    Active: boolean,
    Linked: number?,
    Linking: boolean?,
    Linkable: boolean?,
}

export type ActionView = {
    Id: string,
    Label: string,
    Key: string?,
    On: boolean,
}

export type BarView = {
    Actions: { ActionView },
}
```

- `SlotView.Model` is a preview model of the build, ready for a `ViewportFrame`.
- `Active` is true for slots in your hands.
- `Linked` is the slot it is linked to. `Linking` is true on the slot waiting for a second pick. `Linkable` says whether to show a link button.
- `ActionView.Key` is the key name, like `"R"`. `On` is the toggle state.

### Actions

Send these with `Bridges.Hud:Call(Action, Value)`.

| Action | Value | What it does |
| --- | --- | --- |
| `"Slot"` | slot `number` | Takes out that slot or puts it away |
| `"Link"` | slot `number` | Starts or finishes linking |
| `"Action"` | action `Id` | Runs a tool action, same as its key |
| `"Toggle"` | none | Opens or closes the hotbar tray |
| `"ActionToggle"` | none | Opens or closes the action tray |
