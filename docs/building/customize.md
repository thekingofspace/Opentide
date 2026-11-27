# Customize

The avatar and tool editor. Players change their body, add and move parts, wear clothes, set up their tools and profile, and save whole looks to slots. While it is open the player stands in a separate room with a free camera.

- Menu and screen wiring: `src/Shared/Customize/Menu.luau`
- Look editing: `src/Shared/Customize/init.luau`
- Catalog: `src/Shared/Customize/Catalog/`
- Settings: `src/Shared/Customize/Config.luau`
- Bridges and types: `src/Shared/Customize/Bridges.luau`
- Server: `src/Server/Customize/init.luau`
- Profile and stats: `src/Shared/Bio/Stats.luau`, `src/Server/Bio.luau`
- Built in screen: `src/Shared/GUI_Elements/Customize/`

## Pages

| Page | What it does |
| --- | --- |
| Info | Nickname, description and stats |
| Body | Skin color, body sizes, limb swaps, hiding parts, animation set |
| Parts | Adds premade parts and accessories, groups them, share codes |
| Saves | Saves and loads whole looks, with their tools |
| Tools | Picks tools for the hotbar, swaps their parts, sets holsters |
| Shop | Buys packs |

## Catalog

The catalog is what players can pick from. Each folder in `src/Shared/Customize/Catalog/` holds modules that return a table of definitions keyed by id. Every module is loaded on its own.

| Folder | Type | Template has |
| --- | --- | --- |
| `Parts` | `PartDef` | `Cube`, `Sphere`, `Cylinder`, `Wedge`, `CornerWedge`, `Plate` |
| `Swaps` | `SwapDef` | `RobotArm` |
| `Animations` | `AnimationDef` | `Default` |
| `Clothes` | `ClothingDef` | 6 shirts and 5 pants |

```luau
export type PartDef = {
    Name: string,
    Order: number?,
    Attach: string,
    Offset: CFrame?,
    build: () -> Built,
}

export type SwapDef = {
    Name: string,
    Limbs: { string },
    build: (Piece: BasePart, PieceName: string) -> Built?,
}

export type AnimationDef = {
    Name: string,
    Order: number?,
}

export type ClothingKind = "Shirt" | "Pants"

export type ClothingDef = {
    Name: string,
    Kind: ClothingKind,
    Asset: number,
    Order: number?,
}
```

### Premade parts

`Attach` is the body part it welds to, like `"UpperTorso"`. `build` returns a part or a model. A model with more than one part is added as a group.

```luau
const Build = require(ReplicatedStorage.Shared.Customize.Catalog.Build)

return {
    Visor = {
        Name = "Visor",
        Order = 7,
        Attach = "Head",
        Offset = CFrame.new(0, 0.2, -0.6),
        build = function()
            return Build.part("Visor", Vector3.new(1.2, 0.3, 0.2), Color3.fromRGB(40, 40, 50))
        end,
    },
}
```

`Catalog.Build` has helpers for building parts:

| Function | Description |
| --- | --- |
| `Build.part(Name, Size, Color, Material?, Shape?): Part` | A plain part |
| `Build.ball(Name, Diameter, Color, Material?): Part` | A ball |
| `Build.cylinder(Name, Length, Diameter, Color, Material?): Part` | A cylinder |
| `Build.piece(Part, Offset): Piece` | A part placed relative to the root |
| `Build.model(Name, Root, Pieces?): Model` | A model from a root and pieces |
| `Build.fromTemplate(Template): Built?` | A copy of a premade part or model |

### Limb swaps

A swap replaces whole limbs. `Limbs` can be `Head`, `Torso`, `LeftArm`, `RightArm`, `LeftLeg` and `RightLeg`. `build` is called once for each body piece in the limb, like `RightUpperArm`.

### Clothes

```luau
return {
    BlackJeans = { Name = "Black Jeans", Kind = "Pants", Asset = 382537569 },
}
```

Players can also paste their own clothing ids when `AllowClothingIds` is on.

## Looks and saves

A look is everything the player changed. It is saved in the player's data as `Look`, and each save slot is a `LookSave`.

```luau
export type Look = {
    Version: number,
    Skin: { number }?,
    Swaps: { [string]: string },
    Body: { [string]: LookBody },
    Parts: { LookPart },
    Groups: { [string]: LookGroup },
    Height: number?,
    Width: number?,
    Depth: number?,
    Head: number?,
    ScaleParts: boolean?,
    Animation: string?,
    Shirt: number?,
    Pants: number?,
}

export type LookSave = {
    Name: string,
    Stamp: number,
    Look: Look,
    Tools: { [string]: ToolBuild }?,
}
```

- There are 15 save slots. A save also keeps the player's hotbar tools, so loading it fills the hotbar too.
- Positions are stored as 12 numbers, sizes as 3 numbers and colors as RGB from 0 to 1.
- Every look is cleaned on the server before it is used.

## Share codes

A group of parts can be shared as a 7 letter code that other players import. Codes are stored in the `CustomizeShares` DataStore. Only the player who made a code can remove it. Parts taken from the player's own Roblox avatar are turned into their accessory ids when shared.

## Info and stats

Players set a nickname, shown above their head, and a description, shown on their player card. Stats are numbers players set for themselves. They do nothing on their own, but the [dice](systems/dice) can add a stat bonus to a roll.

```luau
export type StatDef = {
    Id: string,
    Name: string,
    Description: string?,
    Order: number,
    Min: number,
    Max: number,
    Default: number,
    Center: number?,
    PerBonus: number,
    AllowNegative: boolean?,
}
```

The template has `Strength` from `0` to `20`, starting at `10`. With `Center = 10` and `PerBonus = 2`, every 2 points above 10 gives `+1`, and with `AllowNegative` every 2 below gives `-1`.

| Function | Description |
| --- | --- |
| `Stats.get(Id): StatDef?` | A stat |
| `Stats.sorted(): { StatDef }` | Every stat in order |
| `Stats.bonus(Def, Value): number` | The roll bonus for a value |
| `Stats.valueOf(Player, Def): number` | A player's value, from their `Stat_<Id>` attribute |
| `Stats.signed(Value): string` | A number with its sign, like `+2` |

The server sets these player attributes: `Nickname`, `Description` and `Stat_<Id>`. Nicknames and descriptions are filtered.

## Settings

| Field | Default | Description |
| --- | --- | --- |
| `MaxRigParts` | `70` | Most parts in a look |
| `MaxGroups` | `20` | Most groups in a look |
| `SaveSlots` | `15` | Save slots |
| `ApplySavedOnJoin` | `false` | Puts the saved look on when the player joins |
| `MaxOffset` | `4` | How far a part can move from where it attaches |
| `MaxPartSize` | `6` | Biggest part size |
| `MinScale`, `MaxScale` | `0.05`, `6` | Part scale limits |
| `MaxName` | `24` | Longest save name |
| `MaxPartName` | `28` | Longest part name |
| `HeightStep` | `0.05` | Body size step |
| `Proportions` | height, width, depth, head | Body size limits |
| `AllowClothingIds` | `true` | Lets players paste clothing ids |
| `ApplyCooldown` | `1` | Seconds between applying looks |
| `AssetFolder` | `"CustomizeAssets"` | Folder in ReplicatedStorage for loaded accessories |
| `RoomPosition` | `Vector3.new(0, 1600, 0)` | Where the customize room is |
| `CameraSpeed`, `CameraSensitivity`, `CameraDistance` | `22`, `0.35`, `9` | Free camera settings |

## API

### Menu

| Function | Description |
| --- | --- |
| `Menu.open()` | Puts tools away and opens customize |
| `Menu.close()` | Applies the look and closes it |
| `Menu.toggle()` | Flips it |
| `Menu.isOpen(): boolean` | Reads it |
| `Menu.refresh()` | Sends every screen update again |

`Menu.Opened` and `Menu.Closed` fire when it opens and closes. `Menu.ConfirmTime` is how long a confirm press stays armed, `3` seconds.

### Customize

These work on the look being edited.

| Area | Functions |
| --- | --- |
| Session | `enter`, `exit`, `active`, `rig` |
| Selecting | `listParts`, `select`, `selected`, `selectAtMouse`, `setMode`, `getMode` |
| Moving | `translate`, `rotate`, `setScale`, `stretch`, `attach` |
| Parts | `addAsset`, `addBuiltin`, `remove`, `resetPart`, `duplicate`, `rename`, `setHidden` |
| Paint | `setColor`, `clearColor`, `setMaterial`, `setTexture`, `restoreTexture` |
| Body | `setSkin`, `swap`, `setProportion`, `setScaleParts`, `setAnimation`, `setClothing` |
| Groups | `group`, `addToGroup`, `leaveGroup`, `ungroup`, `renameGroup`, `duplicateGroup`, `removeGroup` |
| Looks | `getLook`, `loadLook`, `reset`, `apply` |
| Saves | `saves`, `save`, `renameSave`, `loadSave`, `clearSave` |
| Sharing | `shareGroup`, `unshareGroup`, `importCode` |

Functions that can fail return `(boolean, string?)` or `(string?, string?)`, where the second value is the reason. `Customize.Changed` fires when the look changes and `Customize.Exited` fires with `(Ok, Problem?)` when customize closes.

### Server

All customize events use the `Customize_Net` carrier.

| Event | Arguments | Description |
| --- | --- | --- |
| `@Customize/Enter` | `Poses` | Moves the player into the room |
| `@Customize/Leave` | none | Moves them back |
| `@Customize/Apply` | `Look` | Cleans and puts on a look |
| `@Customize/Save` | `Slot, Look, Name?` | Saves to a slot, with the hotbar tools |
| `@Customize/RenameSave` | `Slot, Name` | Renames a save |
| `@Customize/ClearSave` | `Slot` | Empties a save |
| `@Customize/Fetch` | `AssetId` | Loads an accessory |
| `@Customize/Clothing` | `Kind, Id` | Loads a shirt or pants |
| `@Customize/Texture` | `Id` | Turns an image or decal id into a texture |
| `@Customize/Share` | `Name, Parts` | Makes a share code |
| `@Customize/Import` | `Code` | Reads a share code |
| `@Customize/Unshare` | `Code` | Removes a share code |
| `@Customize/Reset` | none | Clears the applied look |
| `@Customize/State` | to the player | The look and saves when they join |
| `@Bio/Text` | `Field, Text` | Sets the nickname or description |
| `@Bio/Stat` | `Id, Value` | Sets a stat |

## Using it from your own code

```luau
const Menu = require(ReplicatedStorage.Shared.Customize.Menu)
const Bridges = require(ReplicatedStorage.Shared.Customize.Bridges)
```

| To | Call |
| --- | --- |
| Open or close customize | `Menu.open()`, `Menu.close()` or `Menu.toggle()` |
| Know when it opens or closes | `Menu.Opened` and `Menu.Closed` |
| Go to a page | `Bridges.Nav:Call("Page", "Tools")` |
| Any other button | Call its bridge with the action, see the tables below |

`Menu.open()` puts the player's tools away and moves them into the customize room, and `Menu.close()` applies the look. Most other actions only make sense while customize is open, so open it first and then drive it with the bridges.

### Keys

| Key | What it does | Where to change it |
| --- | --- | --- |
| `T`, `R`, `Y`, `Q` | Move, rotate, scale or no handles | `Menu.Keys` |
| `F` | Keep the picked color, or close the part editor | `Menu.DoneKey` |
| `Delete` | Delete the selected part | Fixed in `Menu.luau` |
| `W`, `A`, `S`, `D`, `Space`, `Left Control`, `Left Shift` | Free camera | Fixed in `FreeCam.luau` |

```luau
Menu.Keys[Enum.KeyCode.Q] = nil
Menu.Keys[Enum.KeyCode.Z] = "None"
Menu.DoneKey = Enum.KeyCode.Return
```

## Your own UI

Screen name: **`Customize`**

This is the biggest screen in the game. The easiest way to restyle it is to copy `src/Shared/GUI_Elements/Customize/` and change how it looks, since the built in one is split into a file per page.

### Updates

| Update | Value | Page |
| --- | --- | --- |
| `Shown` | `boolean` | Whole menu |
| `DockShown` | `boolean` | Bottom dock, hidden while the shop is open |
| `SideShown` | `boolean` | Side panel |
| `Page` | `"Info"`, `"Body"`, `"Parts"`, `"Saves"` or `"Tools"` | Current page |
| `Editing` | `boolean` | The part editor is open |
| `NavPage` | `string` | Highlighted nav button |
| `NavReset` | `boolean` | The reset button is waiting for a second press |
| `InfoView` | `InfoView` | Info |
| `BodyState` | `BodyView` | Body |
| `BodyFigure` | `{ [string]: boolean }` | Body, which body parts are picked |
| `BodyAnimations` | `{ Choice }` | Body |
| `BodySwaps` | `{ Choice }` | Body |
| `ClothesState` | `ClothesView` | Body |
| `ClothesShirtCards`, `ClothesPantsCards` | `{ ClothingCard }` | Body |
| `RigRows` | `RigView` | Parts |
| `RigInfo` | `{ Count: string }` | Parts |
| `RigShapes` | `{ ShapeCard }` | Parts, empty unless the add menu is open |
| `RigShared` | `string` | Parts, a share code to show, or `""` to hide it |
| `EditorState` | `EditorView` | Part editor |
| `PickerOpen` | `{ Title: string, Color: Color3 }` or `false` | Color picker |
| `SaveSlots` | `{ SlotView }` | Saves |
| `ToolCategoryList` | `{ ToolCard }` | Tools |
| `ToolCards` | `{ ToolCard }` | Tools |
| `ToolPage` | `ToolPageView` | Tools |
| `ToolParts` | `{ ToolPartRow }` | Tools |
| `ToolSlotBar` | `SlotBarView` or `false` | Tools |
| `ToolAsk` | `string` or `false` | Tools, a yes or no question |
| `ToolMountChoices` | `{ MountChoice }` | Tools |
| `ToolMountOpen` | `{ Title: string }` or `false` | Tools |
| `HolsterState` | `HolsterView` | Tools |
| `ShopShown` | `boolean` | Shop |
| `ShopCards` | `{ ShopCard }` | Shop |
| `ShopDetail` | `ShopDetail` or `false` | Shop |

The types are in `src/Shared/Customize/Bridges.luau`.

```luau
export type Choice = { Id: string, Name: string, Active: boolean }

export type BodyView = {
    Skin: Color3?,
    Sizes: { [string]: string },
    ScaleParts: boolean,
    Pick: string?,
    PickLabel: string,
    PickHidden: boolean,
}

export type ClothingCard = { Id: string, Name: string, Asset: number?, Active: boolean }
export type ClothesView = { Shown: boolean, Ids: boolean, Shirt: string, Pants: string }

export type PartRow = { Id: string, Name: string, Tag: string }
export type GroupRow = { Id: string, Name: string, Code: string?, Members: { PartRow } }
export type RigView = { Groups: { GroupRow }, Loose: { PartRow } }
export type ShapeCard = { Id: string, Name: string, Model: Instance? }

export type EditorView = {
    Kind: "Part" | "Group",
    Id: string,
    Name: string,
    Label: string,
    Texture: string,
    Mode: string,
    Attach: string?,
    Color: Color3?,
}

export type SlotView = {
    Name: string,
    Detail: string,
    Stamp: string,
    Filled: boolean,
    Confirm: boolean,
    ConfirmClear: boolean,
}

export type StatRow = { Id: string, Name: string, Detail: string, Value: string, Bonus: string }
export type InfoView = { Tab: string, Nickname: string, Description: string, Stats: { StatRow } }

export type ToolCard = { Id: string, Name: string, Detail: string, Locked: boolean, Active: boolean }
export type ToolPartRow = { Path: string, Label: string, Name: string, Required: boolean, Depth: number }
export type ToolPageView = { Mode: string, Title: string, Name: string, Detail: string, Equipping: boolean }
export type SlotCard = { Slot: number, Name: string, Filled: boolean, Picked: boolean, Clear: boolean, Model: Model? }
export type SlotBarView = { Title: string, Slots: { SlotCard } }
export type MountChoice = { Id: string, Name: string, Detail: string, Locked: boolean, Active: boolean }
export type HolsterView = { Shown: boolean, On: boolean, Attach: string, Size: string, Mode: string, Looking: string }

export type ShopCard = { Id: string, Name: string, Reward: string, Price: string, Model: Instance?, Image: string?, Active: boolean }
export type ShopDetail = {
    Id: string,
    Name: string,
    Detail: string,
    Reward: string,
    Price: string,
    Model: Instance?,
    Image: string?,
    Giftable: boolean,
    Gifting: boolean,
    Ready: boolean,
    Includes: { string },
}
```

### Actions

Customize has a bridge for each page: `Bridges.Nav`, `Body`, `Clothes`, `Rig`, `Editor`, `Picker`, `Saves`, `Info`, `Tools` and `Shop`. Call them with `Bridges.Body:Call(Action, Value, Extra)`.

Some actions ask for a second press to confirm, like deleting a group. The first press arms it and a second press within 3 seconds does it.

#### `Nav`

| Action | Value | What it does |
| --- | --- | --- |
| `"Page"` | page id | Switches page. `"Shop"` opens the shop |
| `"Reset"` | none | Resets the look, after a confirm |
| `"Exit"` | none | Applies the look and closes |

#### `Body`

| Action | Value | What it does |
| --- | --- | --- |
| `"SkinPick"` | none | Opens the color picker for skin |
| `"SkinReset"` | none | Clears the skin color |
| `"Size"` | `{ Key: string, Step: number }` | Changes a body size. `Step = 0` resets it |
| `"ScaleParts"` | none | Turns part scaling with the body on or off |
| `"Animation"` | set id | Picks an animation set |
| `"Pick"` | body part name | Picks a body part |
| `"Limb"` | limb id | Picks a whole limb |
| `"Hide"` | none | Hides or shows the picked parts |
| `"PartReset"` | none | Resets the picked parts |
| `"Swap"` | swap id or `"none"` | Swaps the picked limb |

#### `Clothes`

`Value` is `"Shirt"` or `"Pants"` and `Extra` is text.

| Action | Extra | What it does |
| --- | --- | --- |
| `"Pick"` | card id | Wears a catalog item. `"default"` takes it off |
| `"Search"` | text | Filters the cards |
| `"Typed"` | text | Stores a typed clothing id |
| `"Wear"` | text | Wears a pasted clothing id |
| `"WearShirt"`, `"WearPants"` | none | Wears the typed id |

#### `Rig`

| Action | Value | What it does |
| --- | --- | --- |
| `"AddMenu"` | none | Opens or closes the premade part list |
| `"Builtin"` | part id | Adds a premade part |
| `"InsertTyped"` | text | Stores a typed accessory id |
| `"Insert"` | text | Adds an accessory by id |
| `"Edit"` | part id | Opens the part editor |
| `"Duplicate"` | part id | Copies a part |
| `"Delete"` | part id | Removes a part |
| `"Drop"` | part id, then `"list"`, `"group:<id>"` or `"part:<id>"` | Drag and drop into or out of groups |
| `"GroupMove"` | group id | Opens the group in the editor |
| `"GroupName"` | group id, then text | Renames a group |
| `"GroupDuplicate"` | group id | Copies a group |
| `"Ungroup"` | group id | Splits a group |
| `"GroupDelete"` | group id | Removes a group, after a confirm |
| `"Share"` | group id | Makes a share code |
| `"Unshare"` | group id | Removes its share code, after a confirm |
| `"SharedHide"` | none | Hides the shown code |
| `"ImportTyped"` | text | Stores a typed code |
| `"Import"` | text | Imports a share code |

#### `Editor`

| Action | Value | What it does |
| --- | --- | --- |
| `"Mode"` | `"Translate"`, `"Rotate"`, `"Scale"` or `"None"` | Picks the move handles |
| `"Name"` | text | Renames the part or group |
| `"Reweld"` | body part name | Attaches the part to another body part |
| `"Texture"` | image id, or `""` to clear | Sets a texture |
| `"Restore"` | none | Puts the original texture back |
| `"ColorPick"` | none | Opens the color picker |
| `"ColorReset"` | none | Clears the color |
| `"Material"` | material name | Sets the material |
| `"Reset"` | none | Resets the part |
| `"Duplicate"` | none | Copies it |
| `"Ungroup"` | none | Splits the group |
| `"Delete"` | none | Removes it |
| `"Done"` | none | Closes the editor |

#### `Picker`

| Action | Value | What it does |
| --- | --- | --- |
| `"Live"` | `Color3` | Shows a color while it is being picked |
| `"Use"` | none | Keeps the color |
| `"Cancel"` | none | Goes back to the old color |

#### `Saves`

`Value` is the slot number.

| Action | Extra | What it does |
| --- | --- | --- |
| `"Save"` | none | Saves the look, with a confirm if the slot is full |
| `"Load"` | none | Loads the look and its tools |
| `"Clear"` | none | Empties the slot, after a confirm |
| `"Name"` | text | Names or renames the slot |

#### `Info`

| Action | Value | What it does |
| --- | --- | --- |
| `"Tab"` | `"Profile"` or `"Stats"` | Switches tab |
| `"NicknameText"` | text | Stores the typed nickname |
| `"DescriptionText"` | text | Stores the typed description |
| `"Save"` | none | Saves the changed profile text |
| `"Stat"` | `{ Id: string, Step: number }` | Raises or lowers a stat |

#### `Tools`

| Action | Value | What it does |
| --- | --- | --- |
| `"Category"` | category id | Opens a tool category |
| `"Back"` | none | Goes back to the categories |
| `"Pick"` | tool id | Starts editing a new build of that tool |
| `"Equip"` | none | Starts or stops picking a hotbar slot for the build |
| `"SlotPress"` | slot number | Puts the build in that slot, or asks to load the slot |
| `"SlotClear"` | slot number | Asks to clear the slot |
| `"AskYes"`, `"AskNo"` | none | Answers the question |
| `"Choose"` | part id or `"none"` | Puts a part on the open mount |
| `"Remove"` | mount path | Removes the part on a mount |
| `"MountClose"` | none | Closes the mount list |
| `"View"` | none | Switches the camera to the tool |
| `"HolsterToggle"` | none | Turns the holster on or off |
| `"HolsterAttach"` | body part name | Moves the holster to a body part |
| `"HolsterMode"` | `"Translate"`, `"Rotate"` or `"None"` | Picks the holster handles |
| `"HolsterSize"` | `{ Step: number }` | Changes the holster size. `Step = 0` resets it |

#### `Shop`

| Action | Value | What it does |
| --- | --- | --- |
| `"Pick"` | item id | Opens an item |
| `"Buy"` | item id | Buys it |
| `"GiftOpen"`, `"GiftClose"` | item id | Opens or closes gifting |
| `"GiftTyped"` | text | Stores the typed player name |
| `"GiftSend"` | item id, then player name | Gifts it |
| `"Close"` | none | Closes the shop |
