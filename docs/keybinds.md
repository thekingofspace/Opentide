# Keybinds

Every key in OpenTide, where it is set, and how to change it.

Most keys are fields on a module. The game reads the field each time a key is pressed, so you can change it from any client script, at any time.

```luau
const Movement = require(ReplicatedStorage.Shared.Movement)
const Ruler = require(ReplicatedStorage.Shared.Ruler)

Movement.CrouchKey = Enum.KeyCode.LeftControl
Ruler.Key = Enum.KeyCode.K
```

To turn a key off, set it to `Enum.KeyCode.Unknown`.

## Every key

| Key | What it does | Where to change it |
| --- | --- | --- |
| `1` to `5` | Take out a hotbar slot | `ToolsClient.Keys` |
| Tool keys, like `R`, `Q`, `E`, `T`, `F` | Tool actions | `Key` on each action in the tool's definition |
| `Left Shift` | Run while held | `Movement.RunKey` |
| `C` | Crouch | `Movement.CrouchKey` |
| `X` | Crawl | `Movement.CrawlKey` |
| `V` | Ruler | `Ruler.Key` |
| `G` | Meta vision | `Utility.MetaVisionKey` |
| `B` | Build panel. In edit mode, saves the selection | `Controller.PanelKey` |
| `Alt` | Build edit mode | Fixed in `PropPlacer/Controller.luau` |
| `E`, `X` | Edit or delete the selection in edit mode | Fixed in `PropPlacer/Controller.luau` |
| `F`, `X`, `Q`, `L`, `M`, `C`, `T`, `R`, `Y` | Build move tools | `BuildTools.Keys` |
| `T`, `R`, `Y`, `Q` | Customize move, rotate, scale and no handles | `Menu.Keys` |
| `F` | Customize: keep the picked color, or close the part editor | `Menu.DoneKey` |
| `Delete` | Customize: delete the selected part | Fixed in `Customize/Menu.luau` |
| `W`, `A`, `S`, `D`, `Space`, `Left Control`, `Left Shift` | Customize free camera | Fixed in `Customize/FreeCam.luau` |
| `Escape` | Cancel picking a player in the action log | Fixed in `ActionLog/init.luau` |

Where each module lives:

| Name | Require |
| --- | --- |
| `ToolsClient` | `require(ReplicatedStorage.Shared.Tools.Client)` |
| `Movement` | `require(ReplicatedStorage.Shared.Movement)` |
| `Ruler` | `require(ReplicatedStorage.Shared.Ruler)` |
| `Utility` | `require(ReplicatedStorage.Shared.Utility)` |
| `Controller` | `require(ReplicatedStorage.Shared.PropPlacer.Controller)` |
| `BuildTools` | `require(ReplicatedStorage.Shared.PropPlacer.Tools)` |
| `Menu` | `require(ReplicatedStorage.Shared.Customize.Menu)` |

## Key tables

Some keys are in a table that maps a key to a name. Change one entry, or remove it and add a new one.

```luau
const ToolsClient = require(ReplicatedStorage.Shared.Tools.Client)
const BuildTools = require(ReplicatedStorage.Shared.PropPlacer.Tools)

ToolsClient.Keys[Enum.KeyCode.One] = nil
ToolsClient.Keys[Enum.KeyCode.Z] = 1

BuildTools.Keys[Enum.KeyCode.F] = nil
BuildTools.Keys[Enum.KeyCode.Return] = "Place"
```

## Tool action keys

Tool keys are part of each tool's definition. Change `Key` on the action.

```luau
Actions = {
    { Id = "Reload", Label = "reload", Key = Enum.KeyCode.R },
    { Id = "Lower", Label = "point down", Key = Enum.KeyCode.Q, Toggle = true },
},
```

An action without a `Key` still shows on the action bar and can be pressed there.

## Side bar labels

The key shown on a side bar button, like `V` on the ruler, is only a label. It does not bind anything. If you change a key, change the label too. The built in buttons and their labels are made in `src/Shared/Utility/init.luau`.

## Adding your own keys

Listen for input and call the system's functions. Each system page has a **Using it from your own code** section with what you can call.

```luau
const UserInputService = game:GetService("UserInputService")
const Radio = require(ReplicatedStorage.Shared.Radio)

UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
    if not Processed and Input.KeyCode == Enum.KeyCode.N then
        Radio.toggle()
    end
end)
```

Skip input when `Processed` is true, so typing in chat or a text box does not trigger it.
