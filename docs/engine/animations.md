# Animations

OpenTide replaces the default Roblox animate script with its own controller. It splits the body into parts that each play their own animation, so legs can walk while the arms hold a tool. Animations can be published ids, or pose data written in Luau that is turned into a `KeyframeSequence` when the game runs.

- Controller: `src/Shared/AnimationController/init.luau`
- Pose data: `src/Shared/AnimationController/Clips.luau`
- Animation ids and names: `src/Shared/AnimationController/Library.luau`
- Default slots, sets and emotes: `src/Shared/AnimationController/Defaults.luau`
- The local player's controller: `src/Shared/AnimationController/LocalAnimations.luau`

## Body parts

```luau
export type Part = "Full" | "Legs" | "Body" | "Right" | "Left"
```

| Part | Covers | Priority |
| --- | --- | --- |
| `Full` | The whole body | Movement |
| `Legs` | Hips and legs | Action |
| `Body` | Torso, head and arms | Action |
| `Right` | Right arm | Action2 |
| `Left` | Left arm | Action2 |

`Full` plays nothing while `Legs` or `Body` has an animation for the current mode.

## Modes

Each part picks an animation for the mode the character is in. The mode is checked every frame.

| Mode | When |
| --- | --- |
| `Idle` | Standing still |
| `Walk` | Moving |
| `Jump` | Jumping |
| `Fall` | Falling or ragdolled |
| `Climb` | Climbing |
| `Swim`, `SwimIdle` | Swimming, moving or still |
| `Seated` | Sitting |
| `Dead` | Dead |

## Clips

A clip is an animation id, an `Animation`, a `KeyframeSequence`, or a name in the library.

```luau
export type Clip = string | number | Animation | KeyframeSequence

export type SlotSpec = {
    Clip: Clip,
    Speed: number?,
    ReferenceSpeed: number?,
    FadeTime: number?,
    Priority: Enum.AnimationPriority?,
}

export type Slot = Clip | SlotSpec | false
```

With `ReferenceSpeed` set, the animation plays faster or slower to match how fast the character moves, from 0.3 to 3 times.

### The library

`Library.Ids` maps names to animation ids. A name with no id is looked up in `ReplicatedStorage.Animations` instead, where you can put a `KeyframeSequence` or `Animation` with that name.

| Name | Used for |
| --- | --- |
| `Walk_Legs`, `Walk_Body` | Walking |
| `CrouchIdle_Legs`, `CrouchIdle_Body` | Crouching still |
| `CrouchWalk_Legs`, `CrouchWalk_Body` | Crouch walking |
| `Point`, `CrouchPoint` | The point emote |
| `Wave`, `Cheer`, `Laugh`, `Dance` | Emotes, using Roblox ids |

Set `Defaults.UseRobloxAnimations = true` to use the Roblox animations for every mode the template does not set.

## Pose data

Tool animations are written as poses instead of published ids. Each frame sets joint rotations, and the game builds a `KeyframeSequence` from it.

```luau
const Clips = require(ReplicatedStorage.Shared.AnimationController.Clips)
const A = Clips.angles

const Hold: Clips.Poses = {
    RightUpperArm = A(38, 32, -52),
    RightLowerArm = A(65, 0, 0),
    RightHand = A(16, 23, -37),
}

const Swing: Clips.Spec = {
    Name = "Swing",
    Priority = Enum.AnimationPriority.Action,
    Frames = {
        { Time = 0, Poses = Hold },
        { Time = 0.16, Poses = Windup, Style = Enum.PoseEasingStyle.Cubic, Direction = Enum.PoseEasingDirection.Out },
        { Time = 0.34, Poses = Contact, Style = Enum.PoseEasingStyle.Linear },
        { Time = 0.85, Poses = Hold },
    },
}
```

```luau
export type Poses = { [string]: CFrame }

export type Frame = {
    Time: number,
    Poses: Poses,
    Style: Enum.PoseEasingStyle?,
    Direction: Enum.PoseEasingDirection?,
}

export type Spec = {
    Name: string,
    Loop: boolean?,
    Priority: Enum.AnimationPriority?,
    Frames: { Frame },
}
```

A joint left out of a frame is held at rest in that frame. Easing defaults to `Cubic` `InOut`.

| Function | Description |
| --- | --- |
| `Clips.angles(X, Y?, Z?): CFrame` | A rotation in degrees |
| `Clips.offset(Position, X?, Y?, Z?): CFrame` | A move and a rotation |
| `Clips.sequence(Spec): KeyframeSequence` | Builds the animation |
| `Clips.side(Spec, Side): Spec` | Keeps only the right arm joints, mirrored to the left when `Side` is `"Left"` |
| `Clips.reflect(Spec): Spec` | Mirrors the whole body, left to right |
| `Clips.flip(Frame): CFrame` | Mirrors one rotation |
| `Clips.mirror(Poses): Poses` | Swaps left and right joint names |
| `Clips.merge(...): Poses` | Joins pose tables, later ones win |

## Sets

A set is a group of slots that replaces the normal animations while it is on, like crouching or holding a tool.

```luau
export type SlotTable = {
    Full: { [string]: Slot }?,
    Legs: { [string]: Slot }?,
    Body: { [string]: Slot }?,
    Right: { [string]: Slot }?,
    Left: { [string]: Slot }?,
}
```

Sets for the local player are listed by library name in `Defaults.Sets`:

```luau
Sets = {
    Crouch = {
        Legs = {
            Idle = { Name = "CrouchIdle_Legs" },
            Walk = { Name = "CrouchWalk_Legs", ReferenceSpeed = 6 },
        },
        Body = {
            Idle = { Name = "CrouchIdle_Body" },
            Walk = { Name = "CrouchWalk_Body", ReferenceSpeed = 6 },
        },
    },
},
```

```luau
LocalAnimations.pushSet("Crouch")
LocalAnimations.popSet("Crouch")
```

On a controller you made yourself, pass clips, not names. `Library.get(Name)` turns a name into a clip.

- The set with the highest priority wins. With equal priority the newest one wins.
- A slot set to `false` plays nothing for that part and mode, even if a lower set or the default has an animation.
- A slot left out falls through to the next set, then the default.

## Actions

An action is a one time animation, like a swing or an emote. While it plays, the parts it covers are muted and come back when it ends. `"Full"` covers every part. Any other part covers only itself.

```luau
export type ActionOptions = {
    Part: Target?,
    Priority: Enum.AnimationPriority?,
    Speed: number?,
    Weight: number?,
    FadeTime: number?,
    Looped: boolean?,
}
```

```luau
const Library = require(ReplicatedStorage.Shared.AnimationController.Library)

Controller:play("Wave", Library.get("Wave") :: any, { Part = "Full" })
```

The first argument is the name you stop it by. The second is the clip.

## API

### Controller

```luau
const AnimationController = require(ReplicatedStorage.Shared.AnimationController)

const Controller = AnimationController.new(Player, { Defaults = false })
```

```luau
export type Options = {
    KeepAnimate: boolean?,
    Exclusive: boolean?,
    Defaults: ({ [string]: Slot } | false)?,
}
```

| Function | Description |
| --- | --- |
| `AnimationController.new(Target, Options?): Controller` | Makes a controller for a player or a model |
| `AnimationController.forLocalPlayer(Options?): Controller` | Makes one for you |
| `AnimationController.animation(Clip): Animation?` | Turns a clip into an `Animation` |
| `Controller:setSlot(Part, Mode, Value?)` | Sets the default animation for a part and mode |
| `Controller:getSlot(Part, Mode): SlotSpec?` | The animation that would play |
| `Controller:pushSet(Name, Slots, Priority?)` | Turns a set on |
| `Controller:popSet(Name)` | Turns a set off |
| `Controller:hasSet(Name): boolean` | Whether a set is on |
| `Controller:play(Name, Clip, Options?): AnimationTrack?` | Plays an action |
| `Controller:stop(Name, FadeTime?)` | Stops an action |
| `Controller:isPlaying(Name): boolean` | Whether an action is playing |
| `Controller:stopAll(FadeTime?)` | Stops every action |
| `Controller:getMode(): string` | The current mode |
| `Controller:destroy()` | Removes the controller |

`Controller.ModeChanged` fires with the new mode. A controller stops any animation it did not start and removes the character's `Animate` script, unless `KeepAnimate` is on.

### Local player

`LocalAnimations` holds your own controller and uses the names in `Defaults`.

| Function | Description |
| --- | --- |
| `LocalAnimations.get(): Controller?` | Your controller |
| `LocalAnimations.pushSet(Name): boolean` | Turns on a set from `Defaults.Sets` |
| `LocalAnimations.popSet(Name)` | Turns it off |
| `LocalAnimations.hasSet(Name): boolean` | Whether it is on |
| `LocalAnimations.emote(Name): AnimationTrack?` | Plays an emote. Stops when you move |
| `LocalAnimations.stopEmote()` | Stops the emote |
| `LocalAnimations.emoting(): string?` | The emote playing |

### Settings

| Field | Default | Description |
| --- | --- | --- |
| `FadeTime` | `0.2` | Default fade between animations |
| `MoveThreshold` | `0.05` | How much movement counts as walking |
| `GuardInterval` | `0.25` | Seconds between checks for animations it did not start |

## Your own UI

Animations have no screen.
