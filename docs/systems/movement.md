# Movement

Running, crouching and crawling. Each stance has its own speed and animations. On touch screens without a keyboard, the side bar gets crouch and crawl buttons.

- System: `src/Shared/Movement/init.luau`
- Crawl and run animations: `src/Shared/Movement/Clips.luau`

| Key | What it does |
| --- | --- |
| `Left Shift` | Run while held |
| `C` | Crouch, press again to stand |
| `X` | Crawl, press again to stand |
| `Space` | Stand up from crouch or crawl |

The run button on the side bar turns running on until it is pressed again. Crawling is not allowed while holding a tool, unless the tool sets `AllowCrawl`. Movement keys are blocked while the build panel is open.

## Settings

| Field | Default | Description |
| --- | --- | --- |
| `WalkSpeed` | `16` | Normal speed |
| `RunSpeed` | `26` | Running speed |
| `CrouchSpeed` | `8` | Crouching speed |
| `CrawlSpeed` | `5` | Crawling speed |
| `RunKey` | `Enum.KeyCode.LeftShift` | Hold to run |
| `CrouchKey` | `Enum.KeyCode.C` | Crouch |
| `CrawlKey` | `Enum.KeyCode.X` | Crawl |
| `RunPriority`, `CrouchPriority`, `CrawlPriority` | `5`, `5`, `6` | Animation set priorities |
| `JumpPause` | `0.25` | Seconds before you can jump after standing up |

```luau
export type Stance = "Stand" | "Crouch" | "Crawl"
```

## Using it from your own code

```luau
const Movement = require(ReplicatedStorage.Shared.Movement)
```

| To | Call |
| --- | --- |
| Crouch, crawl or stand | `Movement.setStance("Crouch")`. Returns `false` if crawling is not allowed |
| Flip crouching | `Movement.toggleCrouch()` |
| Flip crawling | `Movement.toggleCrawl()`, returns `false` if not allowed |
| Turn running on or off | `Movement.setRun(true)` |
| Flip running | `Movement.toggleRun()` |
| Stop the movement keys | `Movement.setBlocked(true)` |
| Read the stance | `Movement.stance()` |
| Read running | `Movement.running()` is true while running, `Movement.runToggled()` is true while the run button is on |
| Change speeds or keys | Set the fields above, like `Movement.RunSpeed = 30` |

`Movement.Changed` fires every time the stance, running or speed changes.

```luau
const Movement = require(ReplicatedStorage.Shared.Movement)

Movement.RunKey = Enum.KeyCode.LeftControl
Movement.CrawlKey = Enum.KeyCode.Unknown

CrouchButton.Activated:Connect(function()
    Movement.toggleCrouch()
end)

Movement.Changed:Connect(function()
    CrouchButton.Text = if Movement.stance() == "Crouch" then "stand" else "crouch"
end)
```

## Your own UI

Movement has no screen. The run, crouch and crawl buttons are side bar buttons. See [Side bar](systems/sidebar) to change them.
