# OpenTide

**READ ME**
This game was coded by me HOWEVER. This doc and some color palletes were AI generated I made the UI but I am color blind so I struggle a bit with colors and writing is hard >:(

This guide shows how each part works and how to add your own.

## Getting started

- Install the tools with [Rokit](https://github.com/rojo-rbx/rokit) by running `rokit install`.
- Sync the project into Studio with RoFlux using `default.project.json`.
- Tool models live in `ServerStorage.ToolAssets` and dice models in `ReplicatedStorage.DiceModels` in the place file. Make sure your place has them.
- Add your user id to `OmniUsers` and `Moderators` in `src/Server/Admin/Config.luau` to use the staff tools.

## Adding a prop

1. Build your model in Studio.
2. Put it in ServerStorage inside the Props folder. Make a folder for the pack.
   Example: `ServerStorage/Props/Kitchen/Fridge`
3. Open `src/Shared/PropData/Definitions`. Pick a file or make a new one.
4. Add a line with a new id number. Every prop needs its own number.

```lua
[40] = { Name = "Fridge", Pack = "Kitchen", Model = "Props/Kitchen/Fridge" },
```

Fields you can use:

- `Name` is the name shown in the build menu.
- `Pack` is the pack a player must own. Leave it out to make the prop free.
- `Model` is the path to the model inside ServerStorage.
- `Limit` is how many one player can place. Leave it out for no limit.
- `MinScale` and `MaxScale` set how small or big the prop can be scaled.
- `Icon` is a CFrame that aims the picture in the build menu.
- `Info = false` hides the info button. Every prop has it unless you turn it off.

Save the file. The prop now shows up in the build menu.

## Giving a prop states and hooks

A prop can remember values, like a color. Put them in `States`. Every state needs a `Default`.

- `Save = false` keeps a state out of saves.
- `Public = true` lets any player change it.

Hooks are functions that run on each player's screen.

- `onPlaced` runs when the prop is placed.
- `onZoneEnter` runs when a player walks into the area and the prop is already there. It gets how many seconds ago the prop was placed.
- `onState` runs when a state changes.
- `onIdle` runs every frame.
- `onRemoved` runs when the prop is deleted.

Change a state with `Prop:setState("Color", Color3.new(1, 0, 0))`. Only the owner can use `setState`. Any player can use `Prop:setPublicState` on a state that has `Public = true`.

Every prop gets an info button that shows who owns it, when it was placed and who changed it last. Players see it while meta vision is on.

Call `Prop:enableWidgets()` inside `onPlaced` and `onZoneEnter` to give the prop its widget buttons too.

A full example with states, hooks and widgets is in `src/Shared/PropData/Definitions/WidgetTest.luau`.

## Adding a new animation

There are two ways to add one.

The quick way for testing in Studio:

1. Make a KeyframeSequence. The Animation Editor can make one for you.
2. Put it in `ReplicatedStorage/Animations`.
3. Give it a simple name like `Wave`.

The real way for the live game:

1. Publish the animation to Roblox and copy its id.
2. Open `src/Shared/AnimationController/Library.luau`.
3. Add the name and the id to the `Ids` list.

```lua
Wave = "1234567890",
```

If an id is filled in, the game uses it. If the id is empty, the game uses the KeyframeSequence with the same name in `ReplicatedStorage/Animations`.

Tips:

- A legs animation should only move the lower body.
- A body animation should only move the upper body.
- Doing this lets you mix them. For example a walk on the legs and a wave on the body.

## Changing the default animations

Open `src/Shared/AnimationController/Defaults.luau`.

- `Slots` are the animations that play all the time.
- Each slot has a part and a mode.
- The parts are `Legs`, `Body` and `Full`.
- The modes are `Idle`, `Walk`, `Jump`, `Fall`, `Climb`, `Swim`, `SwimIdle` and `Seated`.
- `Sets` are groups of slots you can turn on and off, like `Crouch`.
- `Actions` are animations that play one time, like `Point`.

```lua
Slots = {
    Legs = {
        Walk = { Name = "Walk_Legs", ReferenceSpeed = 10 },
    },
},
```

`ReferenceSpeed` is the walk speed where the animation plays at normal speed. Walking faster plays it faster.

`UseRobloxAnimations` turns the normal Roblox animations on or off.

## Controlling animations from code

The easy way uses the names from `Defaults.luau`.

```lua
const LocalAnimations = require(game.ReplicatedStorage.Shared.AnimationController.LocalAnimations)

LocalAnimations.pushSet("Crouch")
LocalAnimations.popSet("Crouch")
LocalAnimations.play("Point")
LocalAnimations.stop("Point")
```

For more control, use the controller.

```lua
const Controller = LocalAnimations.get()

Controller:setSlot("Body", "Idle", "1234567890")
Controller:play("Wave", "1234567890", { Part = "Body" })
Controller:stop("Wave")
```

- `setSlot` changes one slot. Pass `nil` to clear it.
- `pushSet` puts a group of slots on top. The newest set wins.
- `popSet` takes a set away.
- `play` runs an action. `Part` can be `Legs`, `Body` or `Full`. Only that part stops its normal animation while the action plays.
- `stop` ends an action early.

## Emotes

Emotes live in the `Emotes` list in `src/Shared/AnimationController/Defaults.luau`.

```lua
Emotes = {
    Point = { Name = "Point", Part = "Body", Crouch = "CrouchPoint" },
    Wave = { Name = "Wave", Part = "Body" },
    Dance = { Name = "Dance", Part = "Full", Looped = true },
},
```

- `Name` is the animation name from the Library or `ReplicatedStorage/Animations`.
- `Part` is `Legs`, `Body` or `Full`.
- `Looped = true` keeps the emote going until the player moves.
- `Crouch` is an optional animation to use instead while crouching.

Play an emote from code.

```lua
LocalAnimations.emote("Wave")
LocalAnimations.stopEmote()
```

Only one emote plays at a time. Moving or jumping stops the emote. You can not start an emote while moving.

## Sounds

All sounds are set in `src/Shared/Sounds/Config.luau`. Every sound has a name and an `Id`.

```lua
PlaceConfirm = ui("1234567890"),
```

- Put a sound id inside the quotes to turn the sound on.
- An empty id means the sound does not play.
- `ui` sounds are for menus and buttons.
- `world` sounds play at a spot in the world so players nearby hear them.
- `ambience` sounds loop in the background, like rain.

Every button in the game already plays the `Click` sound.

All sounds load when the game starts. One copy of each sound is kept in `SoundService/GameSounds/Cache`, and every time a sound plays, that copy is cloned. This stops the first play of a sound from being late or silent.

Play a sound from code.

```lua
const Sounds = require(game.ReplicatedStorage.Shared.Sounds)

Sounds.play("Notify")
Sounds.playAt("PropPlaced", Vector3.new(0, 5, 0))
```

To add a new sound, add a new line to the `Sounds` list in the config and call it by its name.

## Images

All images are set in `src/Shared/Images/Config.luau`. Every image has a name.

```lua
WidgetEditor = "rbxassetid://16417282974",
SidebarBuild = "",
```

- Put an image id inside the quotes to use it.
- An empty value means no image. The sidebar buttons show only their text when their image is empty.

Use an image from code.

```lua
const Images = require(game.ReplicatedStorage.Shared.Images)

Label.Image = Images.get("WidgetInfo") or ""
```

## Weather and time of day

The server picks the weather and the time of day. Every player sees the same sky and the same weather.

Weather types live in `src/Shared/Utility/Weather/Types`. Each file returns a list of weather types.

```lua
Snow = {
    Name = "Snow",
    Rarity = 0.1,
    Sound = "WeatherSnow",
    FadeIn = 40,
    FadeOut = 90,
    Atmosphere = { Density = 0.5, Haze = 3 },
},
```

- `Rarity` is how often it is picked. A bigger number means more often.
- `FadeIn` is how many seconds it takes to start.
- `FadeOut` is how many seconds it takes to clear up.
- `Clouds`, `Atmosphere` and `Grade` change how the sky and the world look.
- `onStart`, `onIdle` and `onStop` are hooks for extra effects like rain drops.

A new weather is picked every 5 minutes. Change `Period` in `src/Shared/Utility/Weather/init.luau` to change that.

The server can change the weather or the time for everyone.

```lua
const Environment = require(game.ServerScriptService.Environment)

Environment.setWeather("Rain")
Environment.setHour(0)
```

## Subzones

A subzone is an area that changes things while you stand inside it. It can stop the weather, force a weather, change the time of day, play a sound or run your own code.

Making a subzone in Studio:

1. Add a part that covers the area. It can be a block, a ball, a cylinder, a wedge or a mesh.
2. Give the part the tag `ZoneArea`.
3. Add a text attribute named `Zone` and type the zone name, like `Midnight`.

You can use many parts with the same zone name. They all count as one zone. The parts are made invisible and you can walk through them.

Now say what the zone does. Open `src/Shared/Utility/Subzones/Zones`. Pick a file or make a new one.

```lua
Midnight = {
    Priority = 2,
    TweenTime = 3,
    Weather = false,
    Sound = "ZoneMidnight",
    Ambient = {
        Hour = 0,
    },
},
```

- `Weather = false` stops the weather inside. `Weather = "Rain"` makes it always rain inside.
- `Ambient` changes the lighting inside. See Ambient overrides below.
- `Sound` loops while you are inside. Use a name from the sound config or a sound id.
- `Volume` sets how loud the sound is.
- `TweenTime` is how many seconds the changes take to fade in and out.
- `Priority` decides which zone wins when zones overlap. The bigger number wins.

Hooks run on your screen.

- `onEnter` runs when you walk in.
- `onExit` runs when you walk out.
- `onIdle` runs every frame while you are inside.

```lua
Cave = {
    onEnter = function(Context)
        print("Entered", Context.Name)
    end,
    onIdle = function(Context, Delta)
        if Context.Elapsed > 10 then
            print("You have been in the cave for 10 seconds")
        end
    end,
},
```

`Context.Elapsed` is how long you have been inside. `Context.Data` is a table you can use to keep your own values.

You can also make a zone from code on the client.

```lua
const Subzones = require(game.ReplicatedStorage.Shared.Utility.Subzones)

Subzones.create("Midnight", CFrame.new(0, 10, 0), Vector3.new(40, 20, 40))

Subzones.Entered:Connect(function(Name)
    print("Entered", Name)
end)

print(Subzones.inside("Midnight"))
```

## Ambient overrides

An ambient override changes the lighting and fades it in. When it is removed, the lighting fades back. It works on top of the day and night cycle and the weather.

```lua
const AmbientOverride = require(game.ReplicatedStorage.Shared.Utility.AmbientOverride)

AmbientOverride.push("BossRoom", {
    Hour = 0,
    Lighting = { Brightness = 0.5 },
    Atmosphere = { Density = 0.6 },
    Clouds = { Cover = 1 },
    Grade = { Saturation = -0.5, TintColor = Color3.fromRGB(255, 200, 200) },
}, { TweenTime = 2, Priority = 1 })

AmbientOverride.pop("BossRoom", 2)
```

- `Hour` sets the time of day. With realistic day and night on, the whole sky follows the new time.
- `Lighting`, `Atmosphere` and `Clouds` take any property of those objects.
- `Grade` takes any property of a ColorCorrectionEffect.
- The first value is a name you pick. Use the same name to remove it.
- When two overrides change the same thing, the one with the bigger `Priority` wins.

## Customize

Press the customize button on the left side bar. Your character goes to a private room and a side panel opens.

- `body` changes your skin color, your height, width, depth and head size, your animations, and lets you hide or swap body parts and limbs. A swap can go on a whole limb or on one piece, like only the hand. The shirt and pants lists show up on the right side of the screen. Each has a search bar.
- `rig parts` lists every rig part. Use `edit` to change a part and `copy` to make a copy of it. Groups have a `copy` button too. Press `+ add part` to add shapes like cubes and spheres. Drag a part by its grip onto another part to put them in a group. Drag it onto empty space to take it out of the group.
- `saves` keeps up to 15 looks. Type a name in the box to name a look. Each save also keeps your 5 tool slots and where the tools sit on your rig. Loading a save puts those tools back on your hotbar. Saves made before this keep your current tools.
- `shop` opens the shop in the middle of the screen. Tap an item to see what is inside.
- `reset avatar` puts your normal Roblox avatar back.
- `exit` leaves and puts your look on. You do not need to save first.

Colors are picked with a color wheel. Press `pick color` to open it.

Hover over a rig part to see it light up. Click it to edit it.

While editing a part, press T to move, R to rotate, Y to scale and Q to stop. Press Delete to delete it. Press F when you are done.

Scroll the mouse wheel to zoom the camera in and out.

When you weld a part to a different body part, it moves with it and keeps the same spot next to it.

Two limits keep rigs from getting silly. Change them in `src/Shared/Customize/Config.luau`.

- `MaxOffset` is how far in studs a part can be from the body part it is welded to.
- `MaxPartSize` is the biggest a part can be scaled, in studs on each side.

### Share codes

Make a group in `rig parts`, then press `share` on it. You get a code. Anyone can paste that code in the `paste a share code` box to get a copy of the group, welded to the same body parts.

Parts from your own Roblox avatar can be shared too. The game finds the catalog item they came from.

A shared group shows its code. Press `unshare` to turn the code off so nobody can use it anymore. Only the player who made a code can turn it off. Press `share` again later to get a new code.

## Blocky avatar

Every player gets the blocky R15 body from the rig named `Rig` in Workspace. Players keep their own clothes, accessories, face and colors. Only the body parts and body sizes are changed.

To change the body, change the rig in Workspace. To turn this off, set `Enabled = false` in `src/Server/Avatar.luau`.

## Adding premade parts

Premade parts show up in the `+ add part` menu. They live in `src/Shared/Customize/Catalog/Parts`.

```lua
Cube = {
    Name = "Cube",
    Order = 1,
    Attach = "UpperTorso",
    Offset = CFrame.new(0, 0, -1.1),
    build = function()
        return Build.part("Cube", Vector3.one, Color3.new(1, 1, 1))
    end,
},
```

- `Attach` is the body part it starts welded to.
- `Offset` is where it sits next to that body part.
- `build` makes the part. It can return one part or a model.

If `build` returns a model with many parts, the part is added as a group. Every piece becomes its own rig part, so players can edit or delete pieces. Give every piece its own name.

## Adding clothes

Only classic shirts and pants work. The presets live in `src/Shared/Customize/Catalog/Clothes`.

```lua
CoolShirt = { Name = "Cool Shirt", Kind = "Shirt", Asset = 1234567890, Order = 7 },
```

- `Kind` is `Shirt` or `Pants`.
- `Asset` is the catalog id of the shirt or pants.

Players can also paste any shirt or pants id. To turn that off, set `AllowClothingIds = false` in `src/Shared/Customize/Config.luau`. Then players can only pick from the presets.

## Adding animation sets

Animation sets live in `src/Shared/Customize/Catalog/Animations`.

```lua
Ninja = { Name = "Ninja", Order = 1 },
```

The choice is saved with the look. Right now only `Default` exists.

## Adding shop items

Shop items live in `src/Shared/Shop/Items`. Each file returns a list of items.

```lua
MorePropsSmall = {
    Name = "25 more props",
    Description = "place 25 more props at once",
    Product = 1234567890,
    Props = 25,
    Order = 1,
},
KitchenPack = {
    Name = "Kitchen pack",
    Product = 1234567891,
    Pack = "Kitchen",
},
```

- `Product` is the developer product id. Use `0` until you make the product. Items with `0` can not be bought yet.
- `Props` is how many more props the player can place.
- `Pack` is the prop pack the player gets.
- `Gift = false` stops the item from being gifted.
- `Preview` is a list of prop ids. The first one is shown as a 3D picture on the shop card. All of them are listed as what the item includes.
- `Image` is an image id to show instead of a 3D picture.

To gift, a player presses `gift`, types a username and buys it. The gift is sent with the ProfileStore message system. The other player gets it the next time they play, or right away if they are already in a game.

## Naming saves

Prop saves and look saves both have a name box. Type a name and press Enter. If the slot is empty, the name is used when you save there.

## Tools

Players hold tools in their hand. A tool is made from parts that snap onto spots on the tool.

### Using tools

- The bar at the bottom of the screen has 5 slots. Press 1 to 5 or tap a slot to take a tool out. Press it again to put it away.
- Press the `tools` tab above the bar to open or close it.
- Left click uses the tool.
- The bar at the top shows extra things the tool can do, like Q to rest the baseball bat on your shoulder. Press the `actions` tab under it to open or close it.
- You start with 5 empty slots every time you join. Load a rig save in customize to get its tools.

### Building tools

Open customize and press `tools`. Any tool you are holding is put away when customize opens.

- Pick a category from the list, then a tool. The back button at the top goes back a step.
- Picking a tool hides the side bar and the camera looks at the tool. Hold right mouse to turn around it and scroll to zoom.
- Every spot on the tool has a yellow `+` square. Press it to pick a part for that spot.
- Spots that have a part you can take off also have a red X square. Press it to take the part off.
- Changing a part takes off any parts that were on it.
- The list on the left shows every part on the tool. Press X to take one off.
- Nothing is saved while you edit. Press `equip` and a bar with your 5 slots shows at the bottom. Press a slot to put the tool in it. This replaces what was in that slot.
- Press back to throw away your changes.
- When you are not editing, the slot bar shows your hotbar. Press a slot and say yes to load that tool so you can edit it. Press the X on a slot to empty it.
- The panel on the right shows the tool on your rig when it is put away. Pick the body part, then press `move` or `rotate` and drag the handles on your rig. Press `off` to hide the handles. Size changes the whole tool evenly.

To change where the tool camera looks, add a part named `ToolBench` to Workspace.

### Tool models

Every tool and every part is a premade model in `ServerStorage.ToolAssets`. Nothing is built from code while the game runs.

- Tools go in `ServerStorage.ToolAssets.Tools`. Parts go in `ServerStorage.ToolAssets.Attachments`.
- The model name must match the id in code, like `BaseballBat` or `WoodBarrel`.
- Set a `PrimaryPart`. It sits at the mount the part is placed on.
- Guns need an `Attachment` named `Muzzle` where bullets come out. If there are several, the one on the deepest part wins, so a suppressor beats the barrel.

The server builds tools in hands and on rigs. Players ask the server for the models they need for the hotbar and the customize preview, and only get the ones they ask for.

### Adding a tool

Tools live in `src/Shared/Tools/Items`. Parts for tools live in `src/Shared/Tools/Attachments`. These files only hold names, mounts and settings. The shape comes from the model in ServerStorage.

```lua
BaseballBat = {
    Name = "Baseball Bat",
    Category = "Melee",
    Pack = "Sports",
    Mounts = {
        { Id = "Handle", Label = "handle", Accepts = { "BatHandle" }, Offset = CFrame.identity, Required = true },
        { Id = "Head", Label = "barrel", Accepts = { "BatBarrel" }, Offset = CFrame.new(0, 1.2, 0) },
    },
    Defaults = { Handle = "WoodHandle", Head = "WoodBarrel" },
},
```

- `Category` puts the tool in a group. Add new groups to `Categories` in `src/Shared/Tools/Config.luau`.
- `Pack` locks the tool until the player owns that pack. Leave it out to make the tool free.
- `Accepts` lists the kinds of parts that can go on a mount.
- `Required = true` means the mount always has a part. Without it, players can take the part off with the red X.
- `Defaults` are the parts a new tool starts with. Use `Frame/Barrel` style paths for parts on parts.
- `Grip` changes how the tool sits in the hand.
- `AllowCrawl = true` lets players crawl while holding it.
- `Stats` are numbers and settings the tool code can read, like fire rate.

A part for tools looks like this.

```lua
TracerBarrel = {
    Name = "Tracer Barrel",
    Kind = "PistolBarrel",
    Mounts = {
        { Id = "Muzzle", Label = "muzzle", Accepts = { "MuzzleDevice" }, Offset = CFrame.new(0, 0, -0.35) },
    },
    Mods = { Bullet = "Tracer" },
},
```

- `Kind` must match the `Accepts` of a mount.
- A part can have its own `Mounts`, so parts can go on parts.
- The same part can go on many tools. Any mount that accepts its kind can use it.
- `Mods` change the tool's `Stats` while the part is on. A plain name replaces the value. A name ending in `Scale` multiplies it, so `SpreadScale = 0.5` halves `Spread`.

### Tool animations and code

Put animations in `Clips`. Each one can be pose data, or a published animation id.

- `Sets` are groups of animations that replace the normal ones while they are on, like `Held` and `Rest`.
- `Equip` and `Unequip` are played when the tool is taken out and put away.
- `Actions` are shown in the top bar, with a key.

Code for the tool goes in `client` and `server`.

- `onEquip`, `onUnequip`, `onActivate` and `onAction` run on the player's screen.
- `Context.play`, `Context.pushSet`, `Context.popSet` and `Context.send` control animations and talk to the server.
- `Context.stats()` gives the tool's stats with every part's `Mods` added.
- `server.onAction` runs on the server when `Context.send` is used.

### Guns

There are two test guns, a pistol and a laser pistol. Both can take the scope.

- Left click fires. R reloads. The top bar shows how many shots are left.
- Q points the gun down and E points it up. You can not fire while it points down or up.
- Hold right click to zoom. The scope zooms in further.
- While holding a gun your arms follow your mouse up and down. Your body does not turn.

How a shot works:

1. Your screen works out where the bullet starts (the `Muzzle`) and where it hits, and draws it right away.
2. The server gets the shot and runs `server.onFire`. This is where the fire sound plays, so everyone hears it.
3. The server sends the start, the hit and the bullet id to everyone nearby. Their screens draw the bullet.

Bullets are only visuals. They live in `src/Shared/Tools/Guns/Bullets.luau`.

```lua
Bullets.add("Tracer", {
    Name = "Tracer",
    Color = Color3.fromRGB(255, 90, 50),
    Width = 0.12,
    Speed = 550,
    onHit = function(Shot) end,
})
```

- `Speed = 0` makes an instant beam, like a laser.
- `onHit` runs on every screen when the bullet lands on something. Put hit sounds, marks and sparks here. `Shot.Part`, `Shot.Hit` and `Shot.Normal` tell you what was hit.
- `draw` can replace how the bullet looks.

Gun stats are `Bullet`, `FireSound`, `FireVolume`, `FireRate`, `Spread`, `AimSpread`, `Range`, `Zoom`, `Magazine` and `ReloadTime`. Parts can change any of them with `Mods`, so a body, barrel or muzzle can change the sound, the bullet and how it shoots.

## Side bar

From top to bottom: customize, build, prop collide, ruler, run (and crouch and crawl on phones), roll, action log, radio, meta vision and settings.

## Radio

Press `radio` on the side bar. Turn it on, pick a channel and set the volume. The radio only plays for you.

Channels live in `src/Shared/Radio/Channels.luau`.

```lua
{
    Id = "Rock",
    Name = "rock 101",
    Tracks = {
        { Name = "chaos", Id = 1843497734, Speed = 1 },
    },
    Breaks = {
        { Name = "station jingle", Id = 1839086768, Weight = 4 },
        { Name = "news", Id = 1835999258, Weight = 1 },
    },
    BreakChance = 0.3,
    Chatter = {
        { Name = "radio chatter", Id = 9112851363, Weight = 5 },
    },
    ChatterEvery = { 45, 120 },
    Duck = 0.35,
},
```

- `Speed` plays a sound faster or slower. Use it to fix a song that was uploaded sped up or slowed down.
- `Breaks` play between songs. `BreakChance` is how often a break happens.
- `Chatter` plays on top of the music every `ChatterEvery` seconds. `Duck` lowers the music while it plays.
- `Weight` sets how common something is. Bigger is more common, so a weight of 1 next to a weight of 5 is rare.
- `TuneIn = false` starts songs from the beginning instead of the middle.

## Ruler

Press `ruler` or V. Click two spots to see how far apart they are in studs. Click again to start a new line. Press V to turn it off.

## Dice

Press `roll` and pick a die from d4 to d100. The server picks the number, so nobody can fake it. Everyone sees your die roll over your head and land on the result.

- Pick a stat to add its bonus to the roll.
- Type a modifier like `-1 missing arm` or `+1 weather`. The number is added and the words are a note for your log.

Dice are in `src/Shared/Dice/Kinds.luau`. Each die is a premade model in `ReplicatedStorage.DiceModels` named after its id, like `D20`. Set a `PrimaryPart` in the middle of the die. To add a die, add it to `Kinds.luau` and put a model with the same id in that folder.

## Action log

Press `action log`. Your own rolls are always written down.

- Press `+ add player` and click someone to log their rolls too. Press X on their name to stop.
- Type a note and press Enter to add it to the log.
- The log is only on your screen and is gone when you leave.

## Info and stats

Customize has an `info` page.

- `nickname` shows over your head instead of your name. Leave it empty to use your normal name.
- `description` shows on your profile when someone looks at you.
- Press `save profile` to keep your nickname and description. Nothing is saved until you press it.
- `stats` lets you set stats like strength. They show on your profile and can be added to dice rolls.

Nicknames and descriptions are filtered before anyone else sees them.

Stats live in `src/Shared/Bio/Stats.luau`.

```lua
{
    Id = "Strength",
    Name = "strength",
    Min = 0,
    Max = 20,
    Default = 10,
    Center = 10,
    PerBonus = 2,
    AllowNegative = true,
},
```

- The roll bonus is one point for every `PerBonus` levels above `Center`. Strength 14 gives +2.
- With `AllowNegative`, levels under `Center` take points away. Strength 6 gives -2. Without it the bonus never goes under 0.

## Omni tool

The omni tool is a staff panel. Only players the server allows can see the `omni tool` button on the side bar.

Who is allowed lives in `src/Server/Admin/Config.luau`. It is on the server, so players can never see or change it.

```lua
return {
    OmniUsers = { 12345678 },
    Moderators = { 12345678 },
    CreatorAccess = true,
    StudioAccess = true,
    PrivateServerOwnerOmni = false,
    PrivateServerOwnerModerator = false,
}
```

- `OmniUsers` are user ids that can use the omni tool. Add yourself here.
- `Moderators` are user ids that can use the kick and ban commands. This is a separate list.
- `CreatorAccess` gives both to the game owner, or the group owner for group games.
- `StudioAccess` gives both to everyone while testing in Studio.
- `PrivateServerOwnerOmni` and `PrivateServerOwnerModerator` give them to the owner of a private server.

What the omni tool can do:

- `world` sets the weather and the time. `weather flow` and `time flow` stop them from changing on their own.
- `ambient` changes brightness, exposure, fog, haze, color, contrast and tint for everyone. There are presets. `clear ambient` puts it back.
- `messages` sends a popup to everyone, or pins a line of text to the top of everyone's screen until you unpin it.
- `players` lets you go to a player, bring a player to you, or bring everyone.

Popups and pinned text are filtered before anyone sees them. New players see pinned text and the ambient too.

To add ambient presets or tints, edit `src/Shared/Omni/Shared.luau`.

### Moderation commands

Moderators can type these in chat.

- `/kick name reason` kicks someone from this server.
- `/ban name reason` bans someone from every server forever.
- `/ban name 7d reason` bans for a while. Use `s`, `m`, `h`, `d` or `w`, or `perm` for forever.
- `/unban name` lifts a ban. You can use a user id instead of a name for players who are not in the server.

Bans use Roblox's ban system, so they work across every server. They may not work in Studio.

## Head turning

Everyone's head turns to look where their camera is looking. Your screen sends where you look to the server about ten times a second, and the server passes it on to every player who has head turning on.

Turn on `disable head turning` in settings to stop seeing it. You also stop getting the updates, which saves a little data.

## Moving

- Hold Shift or press the run button on the side bar to run.
- Press C to crouch and X to crawl. On phones there are buttons on the side bar for these.
- Running stands you up. Jumping while crouching or crawling stands you up.
- You can not crawl while holding a tool, unless the tool allows it.
- While the build menu is open, the run, crouch, crawl and tool keys are turned off so they do not get in the way of build keys.

Speeds are in `src/Shared/Movement/init.luau`. The run and crawl animations are in `src/Shared/Movement/Clips.luau`. To use your own, add animations named `Run_Legs`, `Run_Body`, `CrawlIdle` and `Crawl` to `ReplicatedStorage/Animations` or to the animation Library.

## The cave test

There is a test cave next to the spawn. Inside it, it is always night, there is no weather and sounds echo. It uses a subzone called `Cave` in `src/Shared/Utility/Subzones/Zones/Cave.luau`.

Ambient overrides can also change sound settings with `Sound`, like `Sound = { AmbientReverb = Enum.ReverbType.Cave }`.
