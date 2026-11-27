# Omni tool

A staff panel for running the world. Staff can change the weather and the time, freeze either one, tint the lighting, send popups to everyone, pin text to the top of the screen and teleport players. Moderators also get chat commands to kick and ban.

- Client: `src/Shared/Omni/init.luau`
- Ambient ranges, tints and presets: `src/Shared/Omni/Shared.luau`
- Bridge and types: `src/Shared/Omni/Bridges.luau`
- Server: `src/Server/Admin/init.luau`
- Who is allowed: `src/Server/Admin/Config.luau`
- Built in screen: `src/Shared/GUI_Elements/Omni.luau`

## Who can use it

| Field | Default | Description |
| --- | --- | --- |
| `OmniUsers` | `{}` | User ids that can use the omni tool |
| `Moderators` | `{}` | User ids that can use the chat commands |
| `CreatorAccess` | `true` | The game owner gets both. For a group game this is the group owner |
| `StudioAccess` | `true` | Everyone gets both in Studio |
| `PrivateServerOwnerOmni` | `false` | The private server owner gets the omni tool |
| `PrivateServerOwnerModerator` | `false` | The private server owner gets the chat commands |
| `MaxPopup` | `300` | Longest popup message |
| `MaxPin` | `120` | Longest pinned text |

```luau
return {
    OmniUsers = { 12345678 },
    Moderators = { 12345678, 87654321 },
    CreatorAccess = true,
    StudioAccess = true,
    PrivateServerOwnerOmni = false,
    PrivateServerOwnerModerator = false,
    MaxPopup = 300,
    MaxPin = 120,
}
```

The omni button only shows in the side bar for staff. Every action is checked again on the server.

## Tabs

| Tab | What it does |
| --- | --- |
| World | Pick the weather, freeze it, set the hour, freeze time |
| Ambient | Change brightness, exposure, fog, haze, color and contrast, pick a tint, apply a preset |
| Messages | Send a popup to everyone, pin or unpin text |
| Players | Go to a player, bring a player, bring everyone |

Popups and pinned text are filtered before anyone sees them.

### Ambient ranges

| Key | Name | Min | Max | Default | Step |
| --- | --- | --- | --- | --- | --- |
| `Brightness` | brightness | `0` | `8` | `2` | `0.5` |
| `Exposure` | exposure | `-3` | `3` | `0` | `0.25` |
| `Density` | fog | `0` | `1` | `0.3` | `0.05` |
| `Haze` | haze | `0` | `10` | `0` | `0.5` |
| `Saturation` | color | `-1` | `1` | `0` | `0.1` |
| `Contrast` | contrast | `-1` | `1` | `0` | `0.1` |

Tints are none, warm, cool, red, green and purple. Presets are gloomy, golden hour, blood moon and dreamy. Add your own in `Shared.Tints` and `Shared.Presets`. The ambient is saved on the `OmniAmbient` workspace attribute and drawn as an override layer named `Omni` with priority `100`.

## Chat commands

| Command | Arguments | What it does |
| --- | --- | --- |
| `/kick` | `<player> [reason]` | Kicks a player in the server |
| `/ban` | `<player or user id> [time] [reason]` | Bans across the whole game. Time is like `30m`, `2h`, `7d`, `1w`, or `perm` |
| `/unban` | `<player or user id>` | Removes a ban |

Players are matched by name or display name, exact first, then by how it starts. Without a time, a ban is forever. The reply shows as a system message in chat.

## API

| Function | Description |
| --- | --- |
| `Omni.show(Value: boolean)` | Opens or closes the panel, for staff only |
| `Omni.toggle()` | Flips it |
| `Omni.isShown(): boolean` | Reads it |
| `Omni.access(): Access` | What this player is allowed to do |

```luau
export type Access = {
    Omni: boolean,
    Commands: boolean,
    Weathers: { string },
}
```

### Server

| Function | Description |
| --- | --- |
| `Admin.canOmni(Player): boolean` | Whether a player can use the omni tool |
| `Admin.canModerate(Player): boolean` | Whether a player can use the commands |

| Field | Default | Description |
| --- | --- | --- |
| `BringGap` | `4` | Studs between players when teleporting |
| `WeatherFade` | `3` | Seconds a weather change takes from the panel |

All events use the `Admin_Network` carrier.

| Event | Kind | Description |
| --- | --- | --- |
| `@Admin/Access` | `When ()` | Returns `Access` for the player |
| `@Omni/Do` | `When (Action, Value, Extra)` | Runs a panel action. Replies `{ Ok, Error, Message }` |
| `@Admin/Command` | `When (Text)` | Runs a chat command |
| `@Omni/Popup` | broadcast `(Title, Text, From)` | Shows a popup to everyone |

## Using it from your own code

```luau
const Omni = require(ReplicatedStorage.Shared.Omni)
const Bridges = require(ReplicatedStorage.Shared.Omni.Bridges)
```

| To | Call |
| --- | --- |
| Open or close the panel | `Omni.show(true)` or `Omni.toggle()`. Does nothing for players who are not staff |
| Check if the player is staff | `Omni.access().Omni` |
| Any panel action | Call the bridge, like `Bridges.Omni:Call("Weather", "Rain")` or `Bridges.Omni:Call("Hour", 18)` |

Every panel action is checked on the server, so a custom staff button is safe to show to anyone.

From server scripts, skip the panel and call the environment directly. These do not check who asked, so only call them from your own trusted code.

```luau
const Environment = require(ServerScriptService.Environment)

Environment.setWeather("Rain", 3)
Environment.setHour(20)
Environment.freezeTime(true)
```

The omni tool has no key. The chat commands are `/kick`, `/ban` and `/unban`.

## Your own UI

Screen name: **`Omni`**. The screen holds the panel, the popup that everyone sees, and the pinned text.

### Updates

| Update | Value | When |
| --- | --- | --- |
| `OmniShown` | `boolean` | The panel opens or closes |
| `OmniTab` | `"World"`, `"Ambient"`, `"Messages"` or `"Players"` | The tab changes |
| `OmniWorld` | `WorldView` | Weather or time changes, and every second while open |
| `OmniWeathers` | `{ Choice }` | The weather list |
| `OmniAmbient` | `{ [string]: string }` | The ambient values, ready to show |
| `OmniTints` | `{ Choice }` | The tint list |
| `OmniPresets` | `{ Choice }` | The preset list |
| `OmniPlayers` | `{ PlayerRow }` | Players join or leave |
| `OmniPopup` | `PopupView` or `false` | A popup arrives, for every player. `false` closes it |
| `OmniPin` | `string` or `false` | Text is pinned or unpinned, for every player |

```luau
export type WorldView = {
    Weather: string,
    WeatherFrozen: boolean,
    Hour: string,
    TimeFrozen: boolean,
}

export type PlayerRow = {
    Id: number,
    Name: string,
    Detail: string,
}

export type PopupView = {
    Title: string,
    Text: string,
    From: string,
}

export type Choice = {
    Id: string,
    Name: string,
    Active: boolean,
}
```

::: warning Every player needs the popup and pin
`OmniPopup` and `OmniPin` are sent to every player, not just staff. Your screen has to show them even when the panel is closed.
:::

### Actions

Send these with `Bridges.Omni:Call(Action, Value)`.

| Action | Value | What it does |
| --- | --- | --- |
| `"Close"` | none | Closes the panel |
| `"Tab"` | tab id | Switches tab |
| `"Weather"` | weather name | Sets the weather |
| `"FreezeWeather"` | none | Freezes or unfreezes the weather |
| `"Hour"` | `number` | Sets the hour, `0` to `24` |
| `"HourText"` | text | Reads an hour from typed text |
| `"FreezeTime"` | none | Freezes or unfreezes time |
| `"AmbientStep"` | `{ Key: string, Step: number }` | Moves an ambient value. `Step = 0` resets it |
| `"Tint"` | tint id | Picks a tint |
| `"Preset"` | preset id | Loads a preset's values |
| `"ApplyAmbient"` | none | Sends the ambient to everyone |
| `"ClearAmbient"` | none | Removes the ambient |
| `"PopupTitle"` | text | Stores the popup title |
| `"PopupText"` | text | Stores the popup message |
| `"SendPopup"` | none | Sends the popup |
| `"PinText"` | text | Stores the pin text |
| `"Pin"` | none | Pins it |
| `"Unpin"` | none | Unpins it |
| `"GoTo"` | `UserId` | Teleports you to a player |
| `"Bring"` | `UserId` | Brings a player to you |
| `"BringAll"` | none | Brings everyone to you |
| `"ClosePopup"` | none | Closes the popup on this screen |

Ambient changes are a draft until `"ApplyAmbient"` is sent.
