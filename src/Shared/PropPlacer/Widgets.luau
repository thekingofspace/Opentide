--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const Workspace = game:GetService("Workspace")

const vision = require(ReplicatedStorage.MainPackages.vision)
const PropData = require(ReplicatedStorage.Shared.PropData)
const CommonStyle = require(ReplicatedStorage.Shared.GUI_Elements.CommonStyle)
const UI = require(ReplicatedStorage.Shared.UI)
const WidgetTypes = require(ReplicatedStorage.Shared.UI.WidgetTypes)
const PropWidget = UI.view("PropWidget")
const PropObject = require(script.Parent.PropObject)
const World = require(script.Parent.World)
const Tools = require(script.Parent.Tools)
const EditMode = require(script.Parent.EditMode)
const Sounds = require(ReplicatedStorage.Shared.Sounds)
const Images = require(ReplicatedStorage.Shared.Images)

type Prop = PropObject.Prop

type Entry = {
    Prop: Prop,
    Anchor: Attachment?,
    Bar: vision.Vision?,
    Window: vision.Vision?,
    Info: vision.Vision?,
}

const Widgets = {
    ButtonSize = 0.8,
    MaxDistance = 60,
    Lift = 1.25,
    Cascade = 26,
    FollowInterval = 0.2,
}

const Scope = vision.Scope()
const _MainStyle = Scope:LoadStyle(table.clone(CommonStyle) :: any)

const Entries: { [string]: Entry } = {}
const Popups: { [string]: vision.Vision } = {}
const Names: { [number]: string } = {}
local Screen: ScreenGui? = nil
local Bars: Folder? = nil
local Hidden = true
local Revealed = false
local Top = 10
local Opened = 0
local Started = false
local Waited = 0

const function playerGui(): Instance
    return Players.LocalPlayer:WaitForChild("PlayerGui")
end

const function screen(): ScreenGui
    const Existing = Screen
    if Existing and Existing.Parent then
        return Existing
    end
    const Made = vision.create({
        ClassName = "ScreenGui",
        Name = "PropWidgets",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 5
    }) :: ScreenGui
    Made.Parent = playerGui()
    Screen = Made
    return Made
end

const function barFolder(): Folder
    const Existing = Bars
    if Existing and Existing.Parent then
        return Existing
    end
    const Made = Instance.new("Folder")
    Made.Name = "PropWidgetBars"
    Made.Parent = playerGui()
    Bars = Made
    return Made
end

const function asset(Image: string?): string?
    if not Image then
        return nil
    end
    return if string.match(Image, "^%d+$") then `rbxassetid://{Image}` else Image
end

const function entryOf(Prop: Prop): Entry
    const Found = Entries[Prop.Key]
    if Found then
        return Found
    end
    const Made: Entry = {
        Prop = Prop,
        Anchor = nil,
        Bar = nil,
        Window = nil,
        Info = nil,
    }
    Entries[Prop.Key] = Made
    return Made
end

const function raise(Root: GuiObject)
    Top += 1
    Root.ZIndex = Top
end

const function spawnPoint(): Vector2
    const Room = screen().AbsoluteSize
    Opened = (Opened + 1) % 6
    const Shift = Opened * Widgets.Cascade
    return Vector2.new(math.max(Room.X * 0.5 - 360 + Shift, 20), math.max(Room.Y * 0.18 + Shift, 20))
end

const function widgetOf(Prop: Prop): PropData.Widget?
    const Found = PropData.definition(Prop.Id)
    return if Found then Found.Widget else nil
end

const function initial(Prop: Prop, Field: PropData.Field): any
    const State = Field.State
    if State and Prop.States[State] ~= nil then
        return Prop.States[State]
    end
    if Field.Default ~= nil then
        return Field.Default
    end
    if Field.Kind == "Color" then
        return Color3.new(1, 1, 1)
    elseif Field.Kind == "Text" then
        return ""
    elseif Field.Kind == "Number" then
        return Field.Min or 0
    end
    return nil
end

const function closeWindow(Prop: Prop)
    const Entry = Entries[Prop.Key]
    const Window = if Entry then Entry.Window else nil
    if Entry and Window then
        Sounds.play("WidgetClose")
        Entry.Window = nil
        Window:Cleanup()
    end
end

const function closeInfo(Prop: Prop)
    const Entry = Entries[Prop.Key]
    const Info = if Entry then Entry.Info else nil
    if Entry and Info then
        Entry.Info = nil
        Info:Cleanup()
    end
end

function Widgets.save(Prop: Prop, Values: { [string]: any })
    if Prop.Destroyed or not Prop:isOwner() then
        return
    end
    Sounds.play("WidgetSave")
    Prop.WidgetSaved:Fire(Values)
    const Found = PropData.definition(Prop.Id)
    const Hook = if Found then Found.onWidgetSave else nil
    if Hook then
        task.spawn(Hook, Prop, Values)
        return
    end
    const Widget = widgetOf(Prop)
    for _, Field in (if Widget then Widget.Fields else nil) or {} do
        const State = Field.State
        if State and Values[Field.Id] ~= nil then
            Prop:setState(State, Values[Field.Id])
        end
    end
end

function Widgets.open(Prop: Prop)
    if Prop.Destroyed or not Prop:isOwner() then
        return
    end
    const Widget = widgetOf(Prop)
    const Fields = if Widget then Widget.Fields else nil
    if not Widget or not Fields or #Fields == 0 then
        return
    end
    const Entry = entryOf(Prop)
    const Existing = Entry.Window
    if Existing then
        raise(Existing:Open() :: GuiObject)
        return
    end

    const Values: { [string]: any } = {}
    for _, Field in Fields do
        Values[Field.Id] = initial(Prop, Field)
    end
    const Info = PropData.get(Prop.Id)
    const Made = Scope:Capture(PropWidget.window({
        Name = `Widget_{Prop.Key}`,
        Title = Widget.Title or (if Info then Info.Name else "prop"),
        Fields = Fields,
        Values = Values,
        Position = spawnPoint(),
        Mount = screen(),
        save = function()
            Widgets.save(Prop, table.clone(Values))
        end,
        close = function()
            closeWindow(Prop)
        end,
        focus = raise,
    }))
    Made:Mount()
    Entry.Window = Made
    Sounds.play("WidgetOpen")
    raise(Made:Open() :: GuiObject)
end

const function nameOf(UserId: number): string?
    const Known = Names[UserId]
    if Known then
        return Known
    end
    const Here = Players:GetPlayerByUserId(UserId)
    if Here then
        Names[UserId] = Here.Name
        return Here.Name
    end
    return nil
end

const function fetchName(UserId: number): string
    const Known = nameOf(UserId)
    if Known then
        return Known
    end
    const Ok, Result = pcall(Players.GetNameFromUserIdAsync, Players, UserId)
    if Ok and type(Result) == "string" then
        Names[UserId] = Result
        return Result
    end
    return `user {UserId}`
end

const function ago(Stamp: number): string
    const Since = math.max(Workspace:GetServerTimeNow() - Stamp, 0)
    if Since < 60 then
        return "just now"
    elseif Since < 3600 then
        return `{math.floor(Since / 60)}m ago`
    elseif Since < 86400 then
        return `{math.floor(Since / 3600)}h ago`
    end
    return `{math.floor(Since / 86400)}d ago`
end

const function when(Stamp: number): string
    return `{string.lower(os.date("%b %d, %H:%M", math.floor(Stamp)))} ({ago(Stamp)})`
end

const function infoRows(Prop: Prop, Resolve: boolean): { WidgetTypes.InfoRow }
    const Owner = if Resolve then fetchName(Prop.Owner) else nameOf(Prop.Owner) or "..."
    const By = if Resolve then fetchName(Prop.By) else nameOf(Prop.By) or "..."
    return {
        { Label = "owner", Value = Owner },
        { Label = "placed", Value = when(Prop.Stamp) },
        { Label = "last update", Value = `{By}, {ago(Prop.Changed)}` },
    }
end

function Widgets.info(Prop: Prop)
    if Prop.Destroyed then
        return
    end
    const Entry = entryOf(Prop)
    local Popup = Entry.Info
    if Popup then
        raise(Popup:Open() :: GuiObject)
    else
        const Info = PropData.get(Prop.Id)
        const Made = Scope:Capture(PropWidget.info({
            Name = `Info_{Prop.Key}`,
            Title = if Info then Info.Name else "prop",
            Rows = infoRows(Prop, false),
            Position = spawnPoint(),
            Mount = screen(),
            close = function()
                closeInfo(Prop)
            end,
            focus = raise,
        }))
        Made:Mount()
        Entry.Info = Made
        Sounds.play("InfoOpen")
        raise(Made:Open() :: GuiObject)
        Popup = Made
    end
    const Shown = Popup :: vision.Vision
    task.spawn(function()
        const Rows = infoRows(Prop, true)
        if Entry.Info == Shown then
            Shown.Rows(Rows)
        end
    end)
end

const function press(Prop: Prop, Button: PropData.WidgetButton)
    if Prop.Destroyed then
        return
    end
    Sounds.play("WidgetButton")
    Prop.WidgetPressed:Fire(Button.Id)
    const Pressed = Button.pressed
    if Pressed then
        task.spawn(Pressed, Prop)
    end
end

const function buttonsOf(Prop: Prop): { WidgetTypes.BarButton }
    const Made: { WidgetTypes.BarButton } = {}
    const Owner = Prop:isOwner()
    const Widget = widgetOf(Prop)
    if Prop.WidgetsEnabled and Widget then
        const Fields = Widget.Fields
        if Owner and Fields and #Fields > 0 then
            table.insert(Made, {
                Id = "Editor",
                Image = Images.get("WidgetEditor"),
                press = function()
                    Widgets.open(Prop)
                end,
            })
        end
        for _, Button in Widget.Buttons or {} do
            if Owner or Button.Public then
                table.insert(Made, {
                    Id = Button.Id,
                    Image = asset(Button.Image),
                    Color = Button.Color,
                    press = function()
                        press(Prop, Button)
                    end,
                })
            end
        end
    end
    if Prop.InfoEnabled then
        table.insert(Made, {
            Id = "Info",
            Image = Images.get("WidgetInfo"),
            press = function()
                Widgets.info(Prop)
            end,
        })
    end
    return Made
end

const function dropBar(Entry: Entry)
    const Bar = Entry.Bar
    Entry.Bar = nil
    if Bar then
        Bar:Cleanup()
    end
    const Anchor = Entry.Anchor
    Entry.Anchor = nil
    if Anchor then
        Anchor:Destroy()
    end
end

const function topOf(Prop: Prop): Vector3
    return Prop.RestBox.Position + Vector3.new(0, Prop.RestSize.Y / 2 + Widgets.Lift, 0)
end

const function follow()
    for _, Entry in Entries do
        const Anchor = Entry.Anchor
        if Anchor then
            const Top = topOf(Entry.Prop)
            if (Anchor.WorldPosition - Top).Magnitude > 0.05 then
                Anchor.WorldPosition = Top
            end
        end
    end
end

const function rebuild(Prop: Prop)
    const Entry = entryOf(Prop)
    dropBar(Entry)
    const Model = Prop.Model
    if Prop.Destroyed or not Prop.Mounted or not Model then
        return
    end
    const Buttons = buttonsOf(Prop)
    if #Buttons == 0 then
        if not Entry.Window and not Entry.Info then
            Entries[Prop.Key] = nil
        end
        return
    end
    const Anchor = Instance.new("Attachment")
    Anchor.Name = "PropWidgetAnchor"
    Anchor.Parent = Workspace.Terrain
    Anchor.WorldPosition = topOf(Prop)
    Entry.Anchor = Anchor

    const Bar = Scope:Capture(PropWidget.bar({
        Name = Prop.Key,
        Adornee = Anchor,
        Mount = barFolder(),
        Buttons = Buttons,
        Size = Widgets.ButtonSize,
        MaxDistance = Widgets.MaxDistance,
        Shown = not Hidden,
    }))
    Bar:Mount()
    Entry.Bar = Bar
end

const function forget(Prop: Prop)
    const Entry = Entries[Prop.Key]
    if not Entry then
        return
    end
    Entries[Prop.Key] = nil
    dropBar(Entry)
    const Window = Entry.Window
    Entry.Window = nil
    if Window then
        Window:Cleanup()
    end
    const Info = Entry.Info
    Entry.Info = nil
    if Info then
        Info:Cleanup()
    end
end

function Widgets.popup(Key: string, Title: string, Rows: { WidgetTypes.InfoRow }): vision.Vision
    const Existing = Popups[Key]
    if Existing then
        Existing.Rows(Rows)
        raise(Existing:Open() :: GuiObject)
        return Existing
    end
    local Made: vision.Vision? = nil
    const Shown = Scope:Capture(PropWidget.info({
        Name = `Popup_{Key}`,
        Title = Title,
        Rows = Rows,
        Position = spawnPoint(),
        Mount = screen(),
        close = function()
            const Own = Made
            if Own and Popups[Key] == Own then
                Popups[Key] = nil
                Own:Cleanup()
            end
        end,
        focus = raise,
    }))
    Made = Shown
    Sounds.play("InfoOpen")
    Shown:Mount()
    Popups[Key] = Shown
    raise(Shown:Open() :: GuiObject)
    return Shown
end

function Widgets.setRevealed(Value: boolean)
    Revealed = Value
end

function Widgets.revealed(): boolean
    return Revealed
end

function Widgets.start()
    if Started then
        return
    end
    Started = true

    PropObject.WidgetsChanged:Connect(rebuild)
    PropObject.Mounted:Connect(function(Prop: Prop)
        if Prop.WidgetsEnabled or Prop.InfoEnabled then
            rebuild(Prop)
        end
    end)
    World.Removed:Connect(forget)

    RunService.Heartbeat:Connect(function(Delta: number)
        Waited += Delta
        if Waited >= Widgets.FollowInterval then
            Waited = 0
            follow()
        end
        const Building = EditMode.active() or Tools.active() or not Revealed
        if Building == Hidden then
            return
        end
        Hidden = Building
        for _, Entry in Entries do
            const Bar = Entry.Bar
            if Bar then
                Bar.Shown(not Hidden)
            end
        end
    end)
end

return Widgets
