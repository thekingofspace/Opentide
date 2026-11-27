# Head turning

Players' heads turn to face where their camera looks. Each client sends where it is looking to the server, which passes it to every player who has head turning on.

- Client: `src/Shared/HeadLook.luau`
- Server: `src/Server/HeadLook.luau`

Players can turn it off with the **disable head turning** [setting](systems/settings). With it off they stop seeing heads turn, but their own head still turns for others.

## Settings

| Field | Default | Description |
| --- | --- | --- |
| `SendRate` | `0.1` | Seconds between sends |
| `MinChange` | `2` | Degrees the look must change before it is sent again |
| `MaxYaw` | `75` | Furthest the head turns left or right |
| `MaxPitch` | `50` | Furthest the head turns up or down |
| `Smooth` | `10` | How quickly heads follow. Higher is snappier |

## Using it from your own code

```luau
const HeadLook = require(ReplicatedStorage.Shared.HeadLook)

HeadLook.setEnabled(false)
```

| To | Call |
| --- | --- |
| Stop or start seeing heads turn | `HeadLook.setEnabled(Value)` |
| Change limits or smoothing | Set the fields above |

### Server

Both sides use the `Look_Net` carrier.

| Event | Kind | Description |
| --- | --- | --- |
| `@Look/Set` | `On (Yaw, Pitch)` | A player's look |
| `@Look/Listen` | `On (On)` | Whether a player wants to see head turns |
| `@Look/Update` | to listeners `(Player, Yaw, Pitch)` | Another player's look |

## Your own UI

Head turning has no screen.
