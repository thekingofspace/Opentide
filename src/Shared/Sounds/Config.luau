--!strict
export type Entry = {
    Id: string,
    Group: string?,
    Volume: number?,
    Pitch: number?,
    Variance: number?,
    Cooldown: number?,
    Range: number?,
}

const function ui(Id: string?): Entry
    return { Id = Id or "", Group = "UI", Volume = 0.5, Variance = 0.04, Cooldown = 0.04 }
end

const function world(Id: string?): Entry
    return { Id = Id or "", Group = "World", Volume = 0.7, Variance = 0.06, Cooldown = 0.05, Range = 80 }
end

const function ambience(Id: string?): Entry
    return { Id = Id or "", Group = "Ambience", Volume = 0.5 }
end

const Config = {
    Groups = {
        UI = 0.6,
        World = 0.8,
        Ambience = 0.5,
    } :: { [string]: number },

    Sounds = {
        Click = ui("rbxassetid://6042053626"),
        Notify = ui(),
        Error = ui(),
        Confirm = ui(),

        PanelOpen = ui(),
        PanelClose = ui(),
        MenuOpen = ui(),
        MenuClose = ui(),
        SidebarOpen = ui(),
        SidebarClose = ui(),
        ToggleOn = ui(),
        ToggleOff = ui(),
        RadioTune = ui(),
        RadioOff = ui(),
        DiceRoll = ui(),
        DiceResult = ui(),
        PageTurn = ui(),
        SettingsSaved = ui(),

        PropSelect = ui(),
        PlaceStart = ui(),
        PlaceConfirm = ui(),
        PlaceCancel = ui(),
        ToolChange = ui(),

        EditEnter = ui(),
        EditExit = ui(),
        Select = ui(),
        Unselect = ui(),
        BoxSelect = ui(),
        MoveConfirm = ui(),
        DeleteConfirm = ui(),

        SaveSlot = ui(),
        LoadSlot = ui(),
        ClearSlot = ui(),

        WidgetOpen = ui(),
        WidgetClose = ui(),
        WidgetSave = ui(),
        WidgetButton = ui(),
        InfoOpen = ui(),

        MetaVisionOn = ui(),
        MetaVisionOff = ui(),

        CustomizeEnter = ui(),
        CustomizeExit = ui(),
        CustomizeSelect = ui(),
        CustomizeAdd = ui(),
        CustomizeRemove = ui(),
        CustomizeApply = ui(),

        PropPlaced = world(),
        PropRemoved = world(),
        PropMoved = world(),

        WeatherRain = ambience("1516791621"),
        WeatherFog = ambience(),
        AmbienceDay = ambience(),
        AmbienceNight = ambience(),

        ZoneMidnight = ambience(),
        ZoneCave = ambience(),

        ToolEquip = ui(),
        ToolPutAway = ui(),
    } :: { [string]: Entry },
}

return Config
