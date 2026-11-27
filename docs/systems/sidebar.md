# Side bar

The column of buttons on the left of the screen. Every player system opens from here. It shows 8 buttons in each column and starts a new column when there are more.

- System: `src/Shared/Utility/Sidebar.luau`
- Built in buttons: `src/Shared/Utility/init.luau`
- Bridges: `src/Shared/Utility/Bridges.luau`
- Built in screen: `src/Shared/GUI_Elements/Sidebar.luau`

## Adding a button

```luau
const Sidebar = require(ReplicatedStorage.Shared.Utility.Sidebar)

const Button = Sidebar.addButton({
    Id = "Map",
    Text = "map",
    Order = 12,
    Toggle = true,
    pressed = function(Button)
        Button:setActive(not Button:isActive())
    end,
})
```

```luau
export type Spec = {
    Id: string,
    Text: string,
    Color: Color3?,
    Ink: Color3?,
    Icon: string?,
    Key: string?,
    Order: number?,
    Toggle: boolean?,
    Active: boolean?,
    pressed: ((Button: Button) -> ())?,
}
```

| Field | Description |
| --- | --- |
| `Id` | Unique id. Adding the same id again replaces the old button |
| `Text` | The label |
| `Color`, `Ink` | Background and text color. Toggle buttons use the on and off colors instead |
| `Icon` | An image id |
| `Key` | A key name shown on the button, like `"B"`. It is only a label, bind the key yourself |
| `Order` | Sort order. Lower is higher up |
| `Toggle` | Shows as on or off |
| `Active` | Starts on |
| `pressed` | Runs when the button is pressed |

### `Button`

Button functions are called with a colon, like `Button:setActive(true)`.

| Method | Description |
| --- | --- |
| `setActive(Active)` | Turns a toggle on or off |
| `isActive(): boolean` | Reads it |
| `setVisible(Visible)` | Shows or hides the button |
| `setText(Text)` | Changes the label |
| `setColor(Color, Ink?)` | Changes the colors |
| `remove()` | Removes the button |

### Built in buttons

| Id | Order | Notes |
| --- | --- | --- |
| `Customize` | 0 | |
| `Build` | 1 | key `B` |
| `Collisions` | 2 | toggle |
| `Ruler` | 3 | toggle, key `V` |
| `Run` | 4 | toggle, key `Shift` |
| `Crouch` | 5 | toggle, touch screens only |
| `Crawl` | 6 | toggle, touch screens only |
| `Emotes` | 6.5 | |
| `Dice` | 7 | |
| `ActionLog` | 8 | |
| `Radio` | 9 | |
| `MetaVision` | 10 | toggle, key `G` |
| `Omni` | 19 | staff only |
| `Settings` | 20 | |

## API

| Function | Description |
| --- | --- |
| `Sidebar.addButton(Spec): Button` | Adds a button |
| `Sidebar.get(Id): Button?` | A button by id |
| `Sidebar.setOpen(Value: boolean)` | Opens or closes the side bar |
| `Sidebar.isOpen(): boolean` | Reads it |
| `Sidebar.toggle()` | Flips it |

| Field | Default | Description |
| --- | --- | --- |
| `DefaultColor` | `Color3.fromRGB(120, 124, 134)` | Button color when none is set |
| `DefaultInk` | white | Text color when none is set |
| `OnColor` | `Color3.fromRGB(78, 160, 96)` | Toggle color when on |
| `OffColor` | `Color3.fromRGB(214, 84, 72)` | Toggle color when off |

## Using it from your own code

```luau
const Sidebar = require(ReplicatedStorage.Shared.Utility.Sidebar)
```

| To | Call |
| --- | --- |
| Hide a built in button | `Sidebar.get("Radio"):setVisible(false)` |
| Rename a button | `Sidebar.get("Build"):setText("make")` |
| Recolor a button | `Sidebar.get("Dice"):setColor(Color3.fromRGB(90, 70, 200))` |
| Open or close the side bar | `Sidebar.setOpen(false)` or `Sidebar.toggle()` |

### What the built in buttons call

To build a completely different menu, call the same functions from your own buttons.

| Button | Calls |
| --- | --- |
| `Customize` | `CustomizeMenu.open()` |
| `Build` | `Controller.togglePanel()` |
| `Collisions` | `Utility.setCollisions(not Collisions.enabled())` |
| `Ruler` | `Ruler.toggle()` |
| `Run` | `Movement.toggleRun()` |
| `Crouch` | `Movement.toggleCrouch()` |
| `Crawl` | `Movement.toggleCrawl()` |
| `Emotes` | `Emotes.toggle()` |
| `Dice` | `Dice.toggle()` |
| `ActionLog` | `ActionLog.toggle()` |
| `Radio` | `Radio.toggle()` |
| `MetaVision` | `Utility.setMetaVision(not MetaVision.active())` |
| `Omni` | `Omni.toggle()` |
| `Settings` | `Utility.toggleSettings()` |

| Name | Require |
| --- | --- |
| `CustomizeMenu` | `ReplicatedStorage.Shared.Customize.Menu` |
| `Controller` | `ReplicatedStorage.Shared.PropPlacer.Controller` |
| `Utility` | `ReplicatedStorage.Shared.Utility` |
| `Collisions` | `ReplicatedStorage.Shared.Utility.Collisions` |
| `MetaVision` | `ReplicatedStorage.Shared.Utility.MetaVision` |
| `Ruler` | `ReplicatedStorage.Shared.Ruler` |
| `Movement` | `ReplicatedStorage.Shared.Movement` |
| `Emotes`, `Dice`, `ActionLog`, `Radio`, `Omni` | `ReplicatedStorage.Shared.<Name>` |

The keys shown on buttons are only labels. See [Keybinds](keybinds) to change the real keys.

## Your own UI

Screen name: **`Sidebar`**

### Updates

| Update | Value | When |
| --- | --- | --- |
| `Expanded` | `boolean` | The side bar opens or closes |
| `Buttons` | `{ ButtonView }` | A button is added, removed or changed |

```luau
export type ButtonView = {
    Id: string,
    Text: string,
    Color: Color3,
    Ink: Color3,
    Icon: string?,
    Key: string?,
    Active: boolean,
    Toggle: boolean,
    Order: number,
}
```

Buttons arrive already sorted. `Color` already has the toggle color applied. `Order` is the position in the list, starting at 1.

### Actions

The side bar has two bridges instead of action names.

| Call | What it does |
| --- | --- |
| `Bridges.SidebarPress:Call(Id)` | Presses the button with that id |
| `Bridges.SidebarToggle:Call()` | Opens or closes the side bar |
