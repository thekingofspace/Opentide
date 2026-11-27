# Radio

A client side radio. Players open it from the side bar, pick a channel, skip tracks and change the volume. Nothing is sent to the server, so every player hears their own radio.

- System: `src/Shared/Radio/init.luau`
- Channels: `src/Shared/Radio/Channels.luau`
- Bridge and types: `src/Shared/Radio/Bridges.luau`
- Built in screen: `src/Shared/GUI_Elements/Radio.luau`

## Channels

Channels are listed in `src/Shared/Radio/Channels.luau`. The template ships with `Chill`, `Rock` and `Scanner`. To add one, add a table like this with your own sound ids.

```luau
{
    Id = "Lofi",
    Name = "lofi",
    Description = "slow beats",
    Order = 4,
    Tracks = {
        { Name = "Riff", Id = 1234567890, Speed = 1.05 },
    },
    Chatter = {
        { Name = "Host", Id = 1234567891, Weight = 0.2 },
    },
    ChatterEvery = { 60, 150 },
}
```

```luau
export type Clip = {
    Name: string,
    Id: number | string,
    Speed: number?,
    Volume: number?,
    Weight: number?,
}

export type Channel = {
    Id: string,
    Name: string,
    Description: string?,
    Order: number?,
    Volume: number?,
    Shuffle: boolean?,
    TuneIn: boolean?,
    Tracks: { Clip },
    Breaks: { Clip }?,
    BreakChance: number?,
    Chatter: { Clip }?,
    ChatterEvery: { number }?,
    Duck: number?,
}
```

| Field | Default | Description |
| --- | --- | --- |
| `Clip.Id` | required | A number or number string becomes `rbxassetid://`. Any other string is used as is |
| `Clip.Speed` | `1` | Playback speed, for sounds that were sped up or slowed down |
| `Clip.Volume` | `1` | Multiplied by the channel volume |
| `Clip.Weight` | `1` | How often it is picked. Lower is rarer |
| `Order` | `99` | Sort order in the list |
| `Description` | the song count | The line under the channel name |
| `Shuffle` | on | Set to `false` to play tracks in order |
| `TuneIn` | on | The first track starts part way through, like a real radio |
| `Breaks`, `BreakChance` | `Radio.BreakChance` | Clips that can play between tracks |
| `Chatter`, `ChatterEvery` | `Radio.ChatterEvery` | Clips that play over the music, every so many seconds |
| `Duck` | `Radio.Duck` | Music volume while chatter plays |

## Settings

These are fields on the `Radio` module.

| Field | Default | Description |
| --- | --- | --- |
| `GroupName` | `"Radio"` | Name of the SoundGroup made in SoundService |
| `DefaultVolume` | `0.5` | Starting volume, read once when the module loads |
| `VolumeStep` | `0.1` | How much the louder and quieter buttons change |
| `LoadTimeout` | `10` | Seconds to wait for a sound to load |
| `BreakChance` | `0.3` | Chance of a break after a track |
| `ChatterEvery` | `{ 60, 150 }` | Seconds between chatter clips |
| `Duck` | `0.4` | Music volume while chatter plays |
| `TuneInRange` | `{ 0.1, 0.7 }` | How far into the first track it can start |

## API

### `Radio.tune(Id: string?)`

Plays a channel. With no id or an unknown id it keeps the current channel, or picks the first one.

### `Radio.stop()`

Turns the radio off.

### `Radio.step(Direction: number)`

Moves to the next channel with `1` or the last one with `-1`, wrapping around.

### `Radio.setVolume(Value: number)`

Sets the volume from `0` to `1`.

### `Radio.show(Value: boolean)`

Shows or hides the radio screen. `Radio.toggle()` flips it.

### Reading state

| Function | Returns |
| --- | --- |
| `Radio.channels(): { Channel }` | Every channel, sorted by `Order` then `Name` |
| `Radio.current(): Channel?` | The current channel |
| `Radio.isOn(): boolean` | Whether music is playing |
| `Radio.isShown(): boolean` | Whether the screen is open |
| `Radio.volume(): number` | The volume from `0` to `1` |

`Radio.Changed` fires every time the radio updates its screen. `Radio.start()` runs once on the client and is called by the side bar code for you.

## Using it from your own code

Require the module from any client script and call it from your own buttons or keys. It works with or without the built in screen.

```luau
const Radio = require(ReplicatedStorage.Shared.Radio)
```

| To | Call |
| --- | --- |
| Open or close the screen | `Radio.show(true)`, `Radio.show(false)` or `Radio.toggle()` |
| Turn it on | `Radio.tune()` plays the current channel, or the first one |
| Play a channel | `Radio.tune("Rock")` |
| Turn it off | `Radio.stop()` |
| Next or last channel | `Radio.step(1)` or `Radio.step(-1)` |
| Set the volume | `Radio.setVolume(0.8)` |
| One step louder | `Radio.setVolume(Radio.volume() + Radio.VolumeStep)` |
| Show what is playing | Listen to `Radio.Changed` and read `Radio.isOn()`, `Radio.current()` and `Radio.volume()` |

The radio has no key. To add one:

```luau
const UserInputService = game:GetService("UserInputService")

UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
    if not Processed and Input.KeyCode == Enum.KeyCode.N then
        Radio.toggle()
    end
end)
```

## Your own UI

Screen name: **`Radio`**

### Updates

| Update | Value | When |
| --- | --- | --- |
| `RadioShown` | `boolean` | The screen opens or closes |
| `RadioChannels` | `{ ChannelCard }` | The channel list or the playing channel changes |
| `RadioNow` | `NowView` | The channel, track, power or volume changes |
| `RadioProgress` | `number` from `0` to `1` | Every frame while the screen is open |

```luau
export type ChannelCard = {
    Id: string,
    Name: string,
    Detail: string,
    Active: boolean,
}

export type NowView = {
    On: boolean,
    Channel: string,
    Track: string,
    Volume: string,
    Level: number,
}
```

`NowView.Volume` is ready to show, like `"50%"`. `NowView.Level` is the same volume from `0` to `1`, for a slider.

### Actions

Send these with `Bridges.Radio:Call(Action, Value)`.

| Action | Value | What it does |
| --- | --- | --- |
| `"Close"` | none | Closes the screen |
| `"Power"` | none | Turns the radio on or off |
| `"Tune"` | channel `Id` | Plays that channel |
| `"Step"` | `1` or `-1` | Next or last channel |
| `"Volume"` | `number` from `0` to `1` | Sets the volume |
| `"Nudge"` | `1` or `-1` | Louder or quieter by one step |

### Example

```luau
const Bridges = require(ReplicatedStorage.Shared.Radio.Bridges)

return {
    mount = function(Parent: Instance): Instance
        Frame.Parent = Parent
        Next.Activated:Connect(function()
            Bridges.Radio:Call("Step", 1)
        end)
        return Frame
    end,
    RadioShown = function(Shown: boolean)
        Frame.Visible = Shown
    end,
    RadioNow = function(Info)
        Title.Text = Info.Channel
        Track.Text = Info.Track
    end,
    RadioProgress = function(Value: number)
        Bar.Size = UDim2.fromScale(Value, 1)
    end,
}
```
