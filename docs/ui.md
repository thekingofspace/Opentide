# Your own UI

Every screen in OpenTide can be swapped for your own. The game systems never build their screens themselves. They load them through `src/Shared/UI`, send them updates, and listen for button presses. Your UI only has to show the updates and send the presses back.

Each system page in these docs has a **Your own UI** section that lists the exact updates that screen gets and the actions it sends back.

## How it works

```
System  ──updates──▶  UI.view("Radio")  ──▶  your module.RadioNow(...)
System  ◀──actions──  Bridges.Radio:Call("Tune", "Rock")  ◀──  your button
```

1. A system asks for its screen with `UI.view("Radio")`.
2. When something changes it calls an update on that view, like `View.RadioNow(Info)`. The call is passed to the function with the same name on your module.
3. When a player presses something, your module calls the system's bridge with an action name and a value. The system does the rest.

## Swapping a screen

Open `src/Shared/UI/Config.luau`. Each line points a screen name at the module that draws it.

```luau
const GUI = script.Parent.Parent.GUI_Elements

return {
    Customize = GUI.Customize,
    Tools = GUI.Tools,
    Radio = GUI.Radio,
    Dice = GUI.Dice,
    ActionLog = GUI.ActionLog,
    Omni = GUI.Omni,
    Emotes = GUI.Emotes,
    Sidebar = GUI.Sidebar,
    Settings = GUI.SettingsPanel,
    BuildPanel = GUI.BuildPanel,
    Toast = GUI.Toast,
    SaveMenu = GUI.SaveMenu,
    PropWidget = GUI.PropWidget,
} :: { [string]: Instance }
```

Point a name at your own module to use it instead. You can also do it from code, as long as it runs before the system that shows the screen starts.

```luau
const UI = require(ReplicatedStorage.Shared.UI)

UI.use("Radio", ReplicatedStorage.MyUI.Radio)
```

::: warning Call UI.use early
A screen is loaded the first time a system uses it. If `UI.use` runs after that, it prints a warning and the old screen is already in use.
:::

## What your module needs

Your module can be a plain table or a vision capture like the built in ones.

| Kind | Builds the screen | Removes it |
| --- | --- | --- |
| Plain table | `mount(Parent)` builds your UI inside `Parent` and returns it | `unmount()`, optional |
| Vision capture | `Open(Self)` returns the root, which is then parented for you | `Cleanup(Self)`, optional |

Add a function for each update you care about, named after the update. It gets the same values the system passed. Updates you leave out are skipped, so you can start small.

```luau
const Frame = Instance.new("Frame")
const Title = Instance.new("TextLabel")

return {
    mount = function(Parent: Instance): Instance
        Title.Parent = Frame
        Frame.Parent = Parent
        return Frame
    end,
    RadioShown = function(Shown: boolean)
        Frame.Visible = Shown
    end,
    RadioNow = function(Info)
        Title.Text = Info.Channel
    end,
}
```

## Sending presses back

Each system has a `Bridges` module. Call the screen's bridge with an action name and a value.

```luau
const Bridges = require(ReplicatedStorage.Shared.Radio.Bridges)

Button.Activated:Connect(function()
    Bridges.Radio:Call("Tune", "Rock")
end)
```

The system binds the bridge when it starts. A call before then does nothing.

The shape of each update is written as an `export type` in the same `Bridges` module, so you get autocomplete for it.

## API

### `UI.use(Name: string, Given: Source)`

Sets the module for a screen. `Given` is a `ModuleScript` or a table. Call it before the system starts.

### `UI.view(Name: string): View`

Returns the view a system sends updates to. Calling `View.Something(...)` calls `Something(...)` on the screen's module, if it has one.

### `UI.mount(Name: string, Parent: Instance): Instance?`

Builds the screen inside `Parent`. Uses `Open` for vision captures and `mount` for plain tables. Systems call this for you.

### `UI.unmount(Name: string)`

Removes the screen with `Cleanup` or `unmount`.

### `UI.load(Name: string): any`

Loads and returns the module for a screen. It is loaded once and then reused.

### Types

```luau
export type View = { [string]: (...any) -> any }
export type Source = Instance | { [string]: any }
```

## Calling systems from your own buttons

You do not have to replace a whole screen to change how players use a system. Any client script can require a system and call it, like `Radio.toggle()` from your own menu button. Every system page has a **Using it from your own code** section with what you can call, and [Keybinds](keybinds) lists every key and how to change it.

## Tips

- The easiest way to start is to copy the built in module for a screen from `src/Shared/GUI_Elements`, change how it looks, and point the config at your copy. The update names and actions stay the same, so the system keeps working.
- Labels drawn in the world, like the ruler distance, dice over heads, nametags and tool mount buttons, are still built by their systems.
