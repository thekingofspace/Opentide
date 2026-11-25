--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const ModelHandles = require(ReplicatedStorage.Shared.ModelHandles)
const PropData = require(ReplicatedStorage.Shared.PropData)
const Config = require(ReplicatedStorage.Shared.PropData.Config)
const PropPlacer = require(script.Parent)
const Container = require(script.Parent.Container)
const Sounds = require(ReplicatedStorage.Shared.Sounds)

export type Kind = Config.Kind
export type Control = "Mouse" | "Manual"

export type Hooks = {
    place: () -> (),
    cancel: () -> (),
}

const Tools = {
    Keys = {
        [Enum.KeyCode.F] = "Place",
        [Enum.KeyCode.X] = "Cancel",
        [Enum.KeyCode.Q] = "Increment",
        [Enum.KeyCode.L] = "Space",
        [Enum.KeyCode.M] = "Control",
        [Enum.KeyCode.C] = "Axis",
        [Enum.KeyCode.T] = "Translate",
        [Enum.KeyCode.R] = "Rotate",
        [Enum.KeyCode.Y] = "Scale",
    } :: { [Enum.KeyCode]: string },
}

const AxisOrder: { ModelHandles.Axis } = { "X", "Y", "Z" }
const Kinds: { Kind } = { "Translate", "Rotate", "Scale" }
const Units: { [Kind]: string } = {
    Translate = " st",
    Rotate = "°",
    Scale = "x",
}
const Steps: { [Kind]: number } = {
    Translate = 1,
    Rotate = 2,
    Scale = 1,
}

local Kind: Kind = "Translate"
local Control: Control = "Mouse"
local Space: ModelHandles.Space = "World"
local Axis: ModelHandles.Axis = "Y"
local Busy = false
local Gizmo: ModelHandles.Gizmo? = nil
local Active: Hooks? = nil

const function incrementOf(Which: Kind): number
    return Config.Increments[Which][Steps[Which]] or 0
end

const function label(Which: Kind): string
    const Value = incrementOf(Which)
    if Value <= 0 then
        return "free"
    end
    return `{Value}{Units[Which]}`
end

const function view(): PropPlacer.ToolView
    return {
        Visible = Active ~= nil,
        Kind = Kind,
        Increment = label(Kind),
        Space = if Space == "World" then "global" else "local",
        Control = if Kind == "Scale" then nil else string.lower(Control),
        Axis = if Kind == "Rotate" and Control == "Mouse" then Axis else nil,
        Busy = Busy,
    }
end

const function apply()
    const Handle = Gizmo
    if Handle then
        for _, Which in Kinds do
            Handle:setIncrement(Which, incrementOf(Which))
        end
        Handle:setSpace(Space)
        Handle:setRotateAxis(Axis)
        if Busy then
            Handle:setDragCode("None")
        elseif Kind == "Scale" or Control == "Manual" then
            Handle:setHandleKind(Kind)
            Handle:setDragCode("Handles")
        elseif Kind == "Rotate" then
            Handle:setDragCode("MouseRotate")
        else
            Handle:setDragCode("HitMouseTranslate")
        end
    end
    PropPlacer.setTools(view())
end

const function limitsOf(Target: Container.Container): (number?, number?)
    if #Target.Items == 0 then
        return nil, nil
    end
    local Low = 0
    local High = math.huge
    for _, Item in Target.Items do
        const Min, Max = PropData.scaleRange(Item.Id)
        const Ratio = Item.Base / Item.StartScale
        Low = math.max(Low, Min * Ratio)
        High = math.min(High, Max * Ratio)
    end
    if Low > High then
        return nil, nil
    end
    return Low, High
end

function Tools.begin(Target: Container.Container, Given: Hooks)
    Tools.stop()
    Active = Given
    Busy = false
    const Character = Players.LocalPlayer.Character
    const Low, High = limitsOf(Target)
    Gizmo = ModelHandles.new(Target.Model, {
        IgnoreList = if Character then { Character } else {},
        Blockers = PropPlacer.blockers(),
        MinScale = Low,
        MaxScale = High,
    })
    apply()
end

function Tools.stop()
    const Handle = Gizmo
    Gizmo = nil
    Active = nil
    Busy = false
    if Handle then
        Handle:destroy()
    end
    PropPlacer.setTools(view())
end

function Tools.followsMouse(): boolean
    return Kind ~= "Scale" and Control == "Mouse"
end

function Tools.active(): boolean
    return Active ~= nil
end

function Tools.setBusy(Value: boolean)
    Busy = Value
    apply()
end

function Tools.action(Name: string): boolean
    const Hooks = Active
    if not Hooks then
        return false
    end
    if Busy then
        return true
    end
    if Name == "Place" then
        task.spawn(Hooks.place)
        return true
    elseif Name == "Cancel" then
        Hooks.cancel()
        return true
    elseif Name == "Increment" then
        Steps[Kind] = Steps[Kind] % #Config.Increments[Kind] + 1
    elseif Name == "Space" then
        Space = if Space == "World" then "Local" else "World"
    elseif Name == "Control" then
        if Kind == "Scale" then
            return true
        end
        Control = if Control == "Mouse" then "Manual" else "Mouse"
    elseif Name == "Axis" then
        const At = table.find(AxisOrder, Axis) or 2
        Axis = AxisOrder[At % #AxisOrder + 1]
    elseif Name == "Translate" or Name == "Rotate" or Name == "Scale" then
        Kind = Name :: Kind
    else
        return false
    end
    Sounds.play("ToolChange")
    apply()
    return true
end

return Tools
