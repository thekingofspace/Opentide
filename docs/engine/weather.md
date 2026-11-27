# Weather and time

The server runs the clock and picks the weather. Clients draw the sky, clouds, fog, rain and sound from workspace attributes, so every player sees the same weather. Subzones change the look and sound inside areas like caves, and ambient overrides let any code change the lighting for a while.

- Server: `src/Server/Environment.luau`
- Weather: `src/Shared/Utility/Weather/init.luau`, presets in `Weather/Types/`
- Day and night: `src/Shared/Utility/DayNight.luau`
- Subzones: `src/Shared/Utility/Subzones/init.luau`, zones in `Subzones/Zones/`
- Overrides: `src/Shared/Utility/AmbientOverride.luau`

Players can turn the effects off with the `DayNight` and `Weather` [settings](systems/settings). Staff change both from the [omni tool](staff/omni).

## Weather

The template has `Clear`, `Rain` and `Fog`. Every 5 minutes the server picks a new one, weighted by `Rarity`.

```luau
export type Definition = {
    Name: string,
    Rarity: number,
    Clouds: CloudLook?,
    Atmosphere: AirLook?,
    Grade: GradeLook?,
    Sound: string?,
    Volume: number?,
    FadeIn: number?,
    FadeOut: number?,
    onStart: ((Context: Context) -> ())?,
    onIdle: ((Context: Context, Delta: number) -> ())?,
    onStop: ((Context: Context) -> ())?,
}

export type CloudLook = { Cover: number, Density: number, Color: Color3? }
export type AirLook = { Density: number, Haze: number, Tint: Color3?, TintAmount: number? }
export type GradeLook = { Saturation: number?, Contrast: number?, Brightness: number? }

export type Context = {
    Name: string,
    Strength: number,
    Elapsed: number,
    Data: { [any]: any },
    Folder: Folder,
    vfx: () -> boolean,
    camera: () -> Camera?,
}
```

```luau
return {
    Fog = {
        Name = "Fog",
        Rarity = 0.15,
        Sound = "WeatherFog",
        FadeIn = 40,
        FadeOut = 60,
        Clouds = { Cover = 0.7, Density = 0.45, Color = Color3.fromRGB(215, 218, 222) },
        Atmosphere = { Density = 0.74, Haze = 6, Tint = Color3.fromRGB(200, 205, 210), TintAmount = 0.85 },
        Grade = { Saturation = -0.2, Contrast = -0.05 },
    },
}
```

- `Rarity` is the weight when picking. `Clear` has `0.65`, `Rain` `0.2` and `Fog` `0.15`.
- `Sound` is a name from the [sound list](engine/sounds).
- `onStart`, `onIdle` and `onStop` run on each client, for effects like rain drops. `Context.Strength` goes from `0` to `1` as the weather fades in. Check `Context.vfx()` before making effects, since players can turn them off.

| Field | Default | Description |
| --- | --- | --- |
| `Period` | `300` | Seconds between weather changes |
| `Transition` | `30` | Fade time when the weather sets none |
| `Fallback` | `"Clear"` | The weather used when one is forced off |

| Function | Description |
| --- | --- |
| `Weather.add(Id, Definition): boolean` | Adds a weather from code |
| `Weather.list()` | Every weather |
| `Weather.current(): string` | The weather on this screen |
| `Weather.force(Id, Name, Priority?, Fade?)` | Forces a weather on this screen, like inside a zone. `false` forces `Fallback` |
| `Weather.release(Id, Fade?)` | Stops forcing |
| `Weather.setEnabled(Value)` | Turns weather effects on or off |

`Weather.Changed` fires with the name of the weather now shown.

## Time

A full day lasts `DayLength = 1200` seconds and starts at hour `8`. The clock is shared through the `DayEpoch` attribute, and `DayFrozen` holds the hour while time is frozen.

| Function | Description |
| --- | --- |
| `DayNight.hour(): number` | The current hour |
| `DayNight.setEnabled(Value)` | Turns the day and night lighting on or off |

### Server

| Function | Description |
| --- | --- |
| `Environment.setWeather(Name, Fade?): boolean` | Sets the weather for everyone |
| `Environment.weather(): string` | The current weather |
| `Environment.freezeWeather(On)` | Stops or starts weather changes |
| `Environment.setHour(Hour)` | Sets the hour for everyone |
| `Environment.hour(): number` | The current hour |
| `Environment.freezeTime(On)` | Stops or starts the clock |

There are no network events. The server writes workspace attributes and every client reads them: `WeatherCurrent`, `WeatherPrevious`, `WeatherSince`, `WeatherFade`, `WeatherFrozen`, `DayEpoch` and `DayFrozen`.

## Subzones

A subzone is an area with its own look, weather and sound. Tag any part with `ZoneArea` and give it a `Zone` string attribute with the zone name. The parts are hidden when the game runs.

```luau
export type Definition = {
    Priority: number?,
    TweenTime: number?,
    Weather: (string | boolean)?,
    Ambient: AmbientOverride.Look?,
    Sound: string?,
    Volume: number?,
    onEnter: ((Context: Context) -> ())?,
    onExit: ((Context: Context) -> ())?,
    onIdle: ((Context: Context, Delta: number) -> ())?,
}
```

```luau
return {
    Cave = {
        Priority = 3,
        TweenTime = 2.5,
        Weather = false,
        Sound = "ZoneCave",
        Ambient = {
            Hour = 0,
            Lighting = { Brightness = 0, ExposureCompensation = -1.2 },
            Atmosphere = { Density = 0.6, Haze = 3 },
            Sound = { AmbientReverb = Enum.ReverbType.Cave },
        },
    },
}
```

- `Weather = false` clears the weather inside. A name forces that weather.
- When zones overlap, the one with the highest `Priority` that has a sound plays it.
- The template has `Midnight`, `Shelter`, `Storm` and `Cave`.

| Function | Description |
| --- | --- |
| `Subzones.add(Name, Definition): boolean` | Adds a zone from code |
| `Subzones.create(Name, At, Size, Shape?): Part` | Makes a zone part from code |
| `Subzones.inside(Name): boolean` | Whether you are in a zone |
| `Subzones.current(): { string }` | Every zone you are in |

`Subzones.Entered` and `Subzones.Exited` fire with the zone name.

## Ambient overrides

An override changes the lighting, atmosphere, clouds, color grade or sound until it is removed. Overrides blend over each other by priority.

```luau
export type Look = {
    Hour: number?,
    Lighting: { [string]: any }?,
    Atmosphere: { [string]: any }?,
    Clouds: { [string]: any }?,
    Grade: { [string]: any }?,
    Sound: { [string]: any }?,
}
```

```luau
const AmbientOverride = require(ReplicatedStorage.Shared.Utility.AmbientOverride)

AmbientOverride.push("Blackout", {
    Lighting = { Brightness = 0.5 },
    Grade = { Saturation = -0.6 },
}, { TweenTime = 1, Priority = 5 })

AmbientOverride.pop("Blackout")
```

`Lighting` sets the Lighting service, `Atmosphere` and `Clouds` set those objects, `Grade` sets a color correction effect and `Sound` sets SoundService. `Hour` sets the clock time.

| Function | Description |
| --- | --- |
| `AmbientOverride.push(Id, Look, Options?)` | Adds or replaces an override |
| `AmbientOverride.pop(Id, TweenTime?)` | Removes it |
| `AmbientOverride.active(Id): boolean` | Whether it is on |

## Your own UI

Weather and time have no screen of their own. They are controlled from the World tab of the [omni tool](staff/omni).
