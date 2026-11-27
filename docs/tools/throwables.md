# Throwables

Tools you can swing and throw. The throwing knife uses a **toss** and the cleaver uses an **arc**. Both are melee weapons too.

| Input | What it does |
| --- | --- |
| Click | Swing. The knife slashes and the cleaver chops. |
| `T` | Throw toward your mouse. You can not swing while it is gone. |
| `R` | Get it back from any distance. |

Your screen works out the whole flight and the exact spot it lands at. The server checks it, hides the tool in your hand and sends the flight to everyone else. Every screen plays the same flight and leaves the tool at the same spot. The flight and the landed tool are only visuals.

- Client: `src/Shared/Tools/Throwables/init.luau`
- Flight math and visuals: `src/Shared/Tools/Throwables/Flight.luau`
- Server: `src/Server/Throws.luau`
- Example tools: `src/Shared/Tools/Items/Throwing.luau`

## Making a throwable tool

A tool becomes throwable when it sets `Stats.Throw` and uses `Throwables.client()` as its `client` table.

```luau
const Throwables = require(ReplicatedStorage.Shared.Tools.Throwables)

Knife = {
    Name = "Throwing Knife",
    Category = "Throwing",
    OneHand = true,
    Clips = KnifeClips,
    Sets = {
        Held = { Body = { Idle = "Hold", Walk = "HoldWalk" } },
    },
    Equip = "Equip",
    Unequip = "PutAway",
    Stats = {
        Throw = "Toss",
        ThrowSpeed = 110,
        ThrowRange = 90,
        ReleaseTime = 0.19,
        SwingTime = 0.55,
    },
    Dual = { Tags = { "Throwing", "Melee" }, With = { "Throwing", "Shield" } },
    Actions = {
        { Id = "Throw", Label = "throw", Key = Enum.KeyCode.T },
        { Id = "Retrieve", Label = "retrieve", Key = Enum.KeyCode.R },
    },
    client = Throwables.client(),
},
```

The model goes in `ServerStorage.ToolAssets.Tools` like any other tool. Put an attachment named `ThrowTip` in it where it should bite in. Its front faces the way it goes in. The knife's points out of the tip and the cleaver's points out of the edge.

### Animations

| Clip | Used for |
| --- | --- |
| `Hold`, `HoldWalk` | The `Held` set while the tool is in your hand |
| `Equip`, `PutAway` | Taking it out and putting it away, and catching it on retrieve |
| `Throw` | The throw. The tool leaves your hand at `ReleaseTime` |
| `Swing` | The melee swing |
| `Throw_OneHand`, `Swing_OneHand` | Used instead while you hold two tools, so only that arm moves |

`OneHand = true` keeps the hold on one arm so the other arm still swings when you walk.

## Stats

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `Throw` | `"Toss" \| "Arc"` | required | Which flight kind to use |
| `ThrowSpeed` | `number` | the kind's `Speed` | Travel speed in studs per second |
| `ThrowRange` | `number` | `100` | Farthest point you can aim at, in studs |
| `ReleaseTime` | `number` | `0.2` | When in the `Throw` animation it leaves your hand |
| `SwingTime` | `number` | `0.55` | How long a swing blocks the next one |
| `ThrowCooldown` | `number` | `0.35` | Time between throws |
| `Embed` | `number` | `0.25` | How deep it sinks in, in studs |
| `StickSquare` | `number` | `0.3` | 0 keeps the flight angle, 1 sticks straight into the surface |

Parts can change any of these with `Mods`, like other tool stats.

## Flight kinds

Kinds live in `Throwables.Flight.Kinds`. Add a key to make a new one.

| Kind | Gravity | Spin | Speed | MinTime | MaxTime |
| --- | --- | --- | --- | --- | --- |
| `Toss` | 20 | 0 | 110 | 0.03 | 2 |
| `Arc` | 80 | 14 | 50 | 0.45 | 1.5 |

- `Gravity` pulls it down in studs per second squared.
- `Spin` turns it end over end in radians per second. `0` keeps it pointing where it flies.
- `MinTime` and `MaxTime` clamp how long the flight to your aim takes, which sets how high an arc goes.

If it hits a person it drops to the floor at their feet. If it hits nothing for 4 seconds it comes back on its own.

## Client API

### `Throwables.client(): { [string]: any }`

Returns the client hooks for a tool definition. Click swings, the `Throw` action throws and the `Retrieve` action gets it back.

### `Throwables.throw(Context: Context)`

Plays `Throw` and lets go at `ReleaseTime`. Does nothing while the tool is thrown, swinging or cooling down.

### `Throwables.swing(Context: Context): boolean`

Plays `Swing`. Returns `false` when it could not swing, so the other hand takes the click while you hold two tools.

### `Throwables.retrieve(Slot: string)`

Asks the server to bring the thrown tool back. Shows a toast if it fails.

### `Throwables.out(Slot: string): boolean`

Returns `true` while the tool in that slot is thrown.

### `Throwables.start()`

Starts the flight drawing and listens for throws from other players. The tools client calls it for you.

## Flight API

`Throwables.Flight` is shared by the client and the server.

```luau
export type Kind = {
    Gravity: number,
    Spin: number,
    Speed: number,
    MinTime: number,
    MaxTime: number,
}

export type Throw = {
    Thrower: Player?,
    Slot: string,
    Build: ToolBuild,
    Kind: string,
    Origin: Vector3,
    Velocity: Vector3,
    Time: number,
    Drop: number?,
    Rest: CFrame?,
}

export type Bounds = {
    Center: Vector3,
    Size: Vector3,
}
```

| Function | Description |
| --- | --- |
| `Flight.plan(Kind, Origin, Target, Speed): Vector3` | The starting velocity that reaches `Target` |
| `Flight.solve(KindName, Origin, Velocity, Tip, Bounds, Skip, Embed, Square): (number, number?, CFrame?)` | Steps the flight and returns the flight time, the drop time if it hit a person, and where it comes to rest |
| `Flight.pose(Throw, Bounds, Elapsed): (CFrame, boolean)` | Where the model is at a time, and whether it has landed |
| `Flight.point(Throw, Kind, Time): Vector3` | The flight position at a time |
| `Flight.speed(Throw, Kind, Time): Vector3` | The flight velocity at a time |
| `Flight.turn(Throw, Kind, Time): CFrame` | The model's rotation at a time |
| `Flight.stick(Hit, Normal, Direction, Velocity, Tip, Embed, Square): CFrame` | The resting frame for a blade stuck in a surface |
| `Flight.lie(Ground, Normal, Direction, Bounds): CFrame` | The resting frame for a tool lying flat |
| `Flight.bounds(Model): Bounds` | The model's center and size from its pivot |
| `Flight.tip(Model, Bounds): CFrame` | The `ThrowTip` attachment from the pivot, or the top of the model |
| `Flight.launch(Throw, Started)` | Starts drawing a throw |
| `Flight.remove(Thrower, Slot)` | Removes a drawn throw |
| `Flight.clear(Thrower)` | Removes every throw from a player |
| `Flight.conceal(Model, On)` | Hides or shows a model on this screen only |
| `Flight.start()` | Starts the draw loop |

## Server

`src/Server/Throws.luau` checks each throw, hides the tool in the thrower's hand and tells everyone else. It uses the `Tools_Net` carrier.

| Event | Kind | Description |
| --- | --- | --- |
| `@Throw/Toss` | `When (Hand, Data)` | A player throws. Replies `{ Ok, Error }` |
| `@Throw/Retrieve` | `When (Slot)` | A player gets a tool back. Replies `{ Ok, Error }` |
| `@Throw/List` | `When ()` | Every landed throw, for players who join late |
| `@Throw/Thrown` | broadcast | A throw, sent to everyone except the thrower |
| `@Throw/Gone` | broadcast `(Player, Slot)` | A thrown tool came back |

Thrown tools come back when the player respawns, changes that slot or leaves.

| Setting | Default | Description |
| --- | --- | --- |
| `MaxGap` | `10` | How far from the player a throw may start |
| `MaxSpeed` | `400` | Fastest allowed throw |
| `MaxDrop` | `4` | Longest allowed drop time |
| `RangeSlack` | `80` | Extra studs allowed past `ThrowRange` |
| `Cooldown` | `0.3` | Time between throws per player |

## Using it from your own code

```luau
const ToolsClient = require(ReplicatedStorage.Shared.Tools.Client)
const Throwables = require(ReplicatedStorage.Shared.Tools.Throwables)
const Bridges = require(ReplicatedStorage.Shared.Tools.Bridges)
```

| To | Call |
| --- | --- |
| Throw, like pressing `T` | `Bridges.Hud:Call("Action", "Throw")` |
| Get it back, like pressing `R` | `Bridges.Hud:Call("Action", "Retrieve")` |
| Throw only the held tool | `Throwables.throw(ToolsClient.current())` |
| Swing the held tool | `Throwables.swing(ToolsClient.current())` |
| Get back a tool in any slot | `Throwables.retrieve("3")` |
| Check if a slot's tool is thrown | `Throwables.out("3")` |

Slots are strings here, `"1"` to `"5"`. The throw keys are set on the actions in `src/Shared/Tools/Items/Throwing.luau`.

## Your own UI

Throwables have no screen of their own. They use the action bar of the **Tools** screen. The throw action shows `throw`, and `thrown` while the tool is gone. See [Tools](tools/tools) for how to build your own hotbar and action bar.
