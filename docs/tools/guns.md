# Guns

Guns are tools that use the gun hooks. The template has a pistol and a laser pistol. Their parts can change the sound, the spread and the bullet they fire.

- Gun hooks: `src/Shared/Tools/Guns/init.luau`
- Bullets: `src/Shared/Tools/Guns/Bullets.luau`
- Example guns: `src/Shared/Tools/Items/Pistols.luau`
- Example parts: `src/Shared/Tools/Attachments/PistolParts.luau`

| Input | What it does |
| --- | --- |
| Click | Fire. Shots go toward your mouse with a little spread |
| `R` | Reload |
| `Q` | Point the gun down |
| `E` | Point the gun up |

You can not fire while the gun points down or up. With two guns, left click fires them in turn and `Q` and `E` step through right, left, both and neither.

## How a shot works

1. Your screen works out where the bullet starts, at the `Muzzle` attachment, and where it hits. It draws the bullet right away.
2. The server checks the shot and runs the tool's `server.onFire`. This is where the fire sound plays, so everyone hears it.
3. The server sends the start, the hit and the bullet id to everyone nearby, and their screens draw it.

Bullets are only visuals. The server does not deal damage.

## Making a gun

A gun is a tool with `Guns.client()` and `Guns.server()` as its hooks.

```luau
Pistol = {
    Name = "Pistol",
    Category = "Guns",
    Mounts = {
        { Id = "Frame", Label = "body", Accepts = { "PistolFrame" }, Offset = CFrame.identity, Required = true },
    },
    Defaults = {
        Frame = "StandardFrame",
        ["Frame/Barrel"] = "StandardBarrel",
    },
    Stats = {
        Bullet = "Standard",
        FireSound = 127604219525464,
        FireVolume = 0.8,
        FireRate = 0.22,
        Spread = 2,
        Range = 500,
        Magazine = 12,
        ReloadTime = 1.3,
    },
    Clips = clips(),
    Sets = sets(),
    Equip = "Equip",
    Unequip = "PutAway",
    Actions = actions(),
    Dual = { Tags = { "Gun" }, With = { "Gun", "Shield" } },
    client = Guns.client(),
    server = Guns.server(),
},
```

The gun hooks expect these from the tool:

- Actions with the ids `"Reload"`, `"Lower"` and `"Raise"`.
- Animation sets named `Held`, `Down` and `Up`, and a clip named `Reload`.
- An attachment named `Muzzle` in the model or one of its parts. The deepest one wins, so a suppressor's muzzle beats the barrel's.

## Stats

| Stat | Default | Description |
| --- | --- | --- |
| `Bullet` | `"Standard"` | The bullet id. A gun must set this |
| `Range` | `500` | How far shots reach |
| `Spread` | `0` | Random spread in degrees |
| `FireRate` | `0.2` | Seconds between shots |
| `Magazine` | none | Shots per magazine. Leave it out for no ammo |
| `ReloadTime` | `1.2` | Seconds to reload |
| `FireSound` | none | The fire sound id |
| `FireVolume` | `0.8` | Fire sound volume |
| `FireSpeed` | `1` | Fire sound speed, with a little random change |
| `RelayRange` | `400` | How close players must be to see the shot |

Parts change these with `Mods`. The scope has `SpreadScale = 0.5`, which halves the spread.

## Bullets

```luau
export type Shot = {
    Shooter: Player?,
    Origin: Vector3,
    Hit: Vector3,
    Normal: Vector3?,
    Part: BasePart?,
    Bullet: string,
}

export type BulletDef = {
    Name: string,
    Color: Color3,
    Width: number,
    Speed: number,
    Length: number?,
    Life: number?,
    draw: ((Shot: Shot, Def: BulletDef) -> ())?,
    onHit: ((Shot: Shot) -> ())?,
}
```

The template has `Standard`, `Tracer`, `LaserRed` and `LaserBlue`.

```luau
Bullets.add("Tracer", {
    Name = "Tracer",
    Color = Color3.fromRGB(255, 90, 50),
    Width = 0.12,
    Speed = 300,
    Length = 4,
    onHit = function(Shot) end,
})
```

- `Speed = 0` draws an instant beam that fades over `Life` seconds, like a laser.
- A moving bullet is a streak `Length` studs long.
- `onHit` runs on every screen when the bullet lands on something. Put hit sounds, marks and sparks here. `Shot.Part`, `Shot.Hit` and `Shot.Normal` say what was hit.
- `draw` replaces how the bullet looks.

| Function | Description |
| --- | --- |
| `Bullets.add(Id, Def)` | Adds a bullet |
| `Bullets.get(Id?): BulletDef` | A bullet, or `Standard` if it does not exist |
| `Bullets.fire(Shot)` | Draws a shot on this screen |
| `Bullets.mine(Shot): boolean` | Whether you fired it |

## Gun API

| Function | Description |
| --- | --- |
| `Guns.client()` | The client hooks for a gun |
| `Guns.server()` | The server hooks. `onFire` plays the fire sound |
| `Guns.trigger(Context): boolean` | Fires if it can. Reloads when empty. Returns whether it fired |
| `Guns.shoot(Context): Shot?` | Fires one shot toward the mouse |
| `Guns.reload(Context)` | Reloads |
| `Guns.setPose(Context, Id, On)` | Turns the `Lower` or `Raise` pose on or off |
| `Guns.lowered(Context): boolean` | Whether the gun points down or up |
| `Guns.muzzle(Model?): Attachment?` | The muzzle the shot comes from |
| `Guns.serverSound(Model?, Id, Volume?, Speed?)` | Plays a sound at the muzzle for everyone |

## Using it from your own code

```luau
const ToolsClient = require(ReplicatedStorage.Shared.Tools.Client)
const Guns = require(ReplicatedStorage.Shared.Tools.Guns)
const Bridges = require(ReplicatedStorage.Shared.Tools.Bridges)
```

| To | Call |
| --- | --- |
| Reload, like pressing `R` | `Bridges.Hud:Call("Action", "Reload")`. With two guns both reload |
| Point down or up | `Bridges.Hud:Call("Action", "Lower")` or `"Raise"` |
| Fire the held gun | `Guns.trigger(ToolsClient.current())` |
| Reload only the held gun | `Guns.reload(ToolsClient.current())` |
| Read the ammo | `ToolsClient.current().Data.Ammo` |

The gun keys are set on the actions in `src/Shared/Tools/Items/Pistols.luau`. Change `Key` there to rebind them.

```luau
{ Id = "Reload", Label = "reload", Key = Enum.KeyCode.R },
{ Id = "Lower", Label = "point down", Key = Enum.KeyCode.Q, Toggle = true },
{ Id = "Raise", Label = "point up", Key = Enum.KeyCode.E, Toggle = true },
```

## Your own UI

Guns have no screen of their own. They use the action bar of the [Tools](tools/tools) screen. The reload action shows the ammo, like `reload (12/12)`, and the lower and raise actions show as on while active.
