--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Query = require(ReplicatedStorage.Shared.PropPlacer.Query)
const Config = require(script.Config)
const Codec = require(script.Codec)
const Types = require(script.Types)

export type Info = Query.Info
export type Definition = Types.Definition
export type Definitions = Types.Definitions
export type Value = Types.Value
export type States = Types.States
export type Arrival = Types.Arrival
export type StateSpec = Types.StateSpec
export type FieldKind = Types.FieldKind
export type FieldContext = Types.FieldContext
export type Field = Types.Field
export type ServerProp = Types.ServerProp
export type ServerBox = Types.ServerBox
export type ServerBoxSpec = Types.ServerBoxSpec
export type Prop = Types.Prop
export type WidgetButton = Types.WidgetButton
export type Widget = Types.Widget

const PropData = {}

const Stored: { [number]: Definition } = {}
const Infos: { [number]: Info } = {}
const Paths: { [number]: string } = {}
local Catalog: { Info }? = nil
local Loaded = false

function PropData.add(Id: number, Definition: Definition): boolean
    if type(Id) ~= "number" or Id < 1 or Id ~= math.floor(Id) then
        warn(`[PropData] prop ids must be whole numbers above 0, got {tostring(Id)}`)
        return false
    end
    if Infos[Id] then
        warn(`[PropData] id {Id} is used more than once, keeping "{Infos[Id].Name}"`)
        return false
    end
    if type(Definition) ~= "table" or type(Definition.Name) ~= "string" or Definition.Name == "" then
        warn(`[PropData] prop {Id} needs a Name string`)
        return false
    end
    if Definition.Pack ~= nil and type(Definition.Pack) ~= "string" then
        warn(`[PropData] prop {Id} has a Pack that is not a string, leave it out to make the prop free`)
        return false
    end
    if type(Definition.Model) ~= "string" then
        warn(`[PropData] prop {Id} needs a Model path string inside ServerStorage`)
        return false
    end
    if Definition.Limit ~= nil and type(Definition.Limit) ~= "number" then
        warn(`[PropData] prop {Id} has a Limit that is not a number`)
        return false
    end
    if Definition.Icon ~= nil and typeof(Definition.Icon) ~= "CFrame" then
        warn(`[PropData] prop {Id} has an Icon that is not a CFrame`)
        return false
    end
    for _, Field in { "States", "Widget", "ServerBox" } do
        const Value = (Definition :: any)[Field]
        if Value ~= nil and type(Value) ~= "table" then
            warn(`[PropData] prop {Id} has a {Field} that is not a table`)
            return false
        end
    end
    for _, Field in { "MinScale", "MaxScale" } do
        const Value = (Definition :: any)[Field]
        if Value ~= nil and (type(Value) ~= "number" or Value <= 0) then
            warn(`[PropData] prop {Id} has a {Field} that is not a number above 0`)
            return false
        end
    end
    if Definition.MinScale and Definition.MaxScale and Definition.MinScale > Definition.MaxScale then
        warn(`[PropData] prop {Id} has a MinScale bigger than its MaxScale`)
        return false
    end

    Infos[Id] = {
        Id = Id,
        Name = Definition.Name,
        Pack = Definition.Pack,
        Limit = Definition.Limit,
        Icon = Definition.Icon,
        MinScale = Definition.MinScale,
        MaxScale = Definition.MaxScale,
    }
    Paths[Id] = Definition.Model
    Stored[Id] = Definition
    Catalog = nil
    return true
end

const function load()
    if Loaded then
        return
    end
    Loaded = true

    const Folder = script:FindFirstChild("Definitions")
    if not Folder then
        return
    end

    const Modules: { ModuleScript } = {}
    for _, Item in Folder:GetDescendants() do
        if Item:IsA("ModuleScript") then
            table.insert(Modules, Item)
        end
    end
    table.sort(Modules, function(A: ModuleScript, B: ModuleScript): boolean
        return A:GetFullName() < B:GetFullName()
    end)

    for _, Module in Modules do
        const Ok, Result = pcall(require, Module)
        if not Ok then
            warn(`[PropData] {Module:GetFullName()} failed to load: {Result}`)
            continue
        end
        if type(Result) ~= "table" then
            warn(`[PropData] {Module:GetFullName()} must return a table of prop definitions`)
            continue
        end
        for Id, Definition in Result :: Definitions do
            PropData.add(Id, Definition)
        end
    end
end

function PropData.all(): { Info }
    load()
    const Existing = Catalog
    if Existing then
        return Existing
    end
    const Made: { Info } = {}
    for _, Info in Infos do
        table.insert(Made, Info)
    end
    table.sort(Made, function(A: Info, B: Info): boolean
        if A.Name == B.Name then
            return A.Id < B.Id
        end
        return A.Name < B.Name
    end)
    table.freeze(Made)
    Catalog = Made
    return Made
end

function PropData.get(Id: number): Info?
    load()
    return Infos[Id]
end

function PropData.scaleRange(Id: number): (number, number)
    const Info = PropData.get(Id)
    const Min = if Info and Info.MinScale then Info.MinScale else Config.MinScale
    const Max = if Info and Info.MaxScale then Info.MaxScale else Config.MaxScale
    return Min, Max
end

function PropData.path(Id: number): string?
    load()
    return Paths[Id]
end

function PropData.definition(Id: number): Definition?
    load()
    return Stored[Id]
end

function PropData.spec(Id: number, Name: string): StateSpec?
    const Found = PropData.definition(Id)
    const Specs = if Found then Found.States else nil
    return if Specs then Specs[Name] else nil
end

function PropData.defaults(Id: number): States
    const Made: States = {}
    const Found = PropData.definition(Id)
    const Specs = if Found then Found.States else nil
    if Specs then
        for Name, Spec in Specs do
            Made[Name] = Spec.Default
        end
    end
    return Made
end

function PropData.isPublic(Id: number, Name: string): boolean
    const Spec = PropData.spec(Id, Name)
    return Spec ~= nil and Spec.Public == true
end

function PropData.accepts(Id: number, Name: string, Value: any, Player: Player?): boolean
    if type(Name) ~= "string" then
        return false
    end
    const Spec = PropData.spec(Id, Name)
    if not Spec or not Codec.same(Value, Spec.Default) or not Codec.finite(Value) then
        return false
    end
    if type(Value) == "string" and #Value > 200 then
        return false
    end
    const Check = Spec.check
    if Check then
        const Ok, Result = pcall(Check, Value, Player)
        return Ok and Result == true
    end
    return true
end

function PropData.clean(Id: number, Given: any, Player: Player?): States
    const Made = PropData.defaults(Id)
    if type(Given) ~= "table" then
        return Made
    end
    for Name, Value in Given do
        if Made[Name] ~= nil and PropData.accepts(Id, Name, Value, Player) then
            Made[Name] = Value
        end
    end
    return Made
end

function PropData.preview(Id: number, Model: Model, Given: States?)
    const Found = PropData.definition(Id)
    const Hook = if Found then Found.onPreview else nil
    if not Hook then
        return
    end
    const Ok, Problem = pcall(Hook, Model, PropData.clean(Id, Given))
    if not Ok then
        warn(`[PropData] preview failed for prop {Id}: {Problem}`)
    end
end

function PropData.persists(Id: number): boolean
    const Found = PropData.definition(Id)
    return not Found or Found.Persist ~= false
end

function PropData.saveStates(Id: number, Current: States, Owner: Player?): { [string]: any }
    const Found = PropData.definition(Id)
    const Specs = if Found then Found.States else nil
    local Kept: States = {}
    if Specs then
        for Name, Spec in Specs do
            const Value = Current[Name]
            if Spec.Save ~= false and Value ~= nil then
                Kept[Name] = Value
            end
        end
    end
    const Serialize = if Found then Found.serialize else nil
    if Serialize then
        const Ok, Result = pcall(Serialize, Kept, Owner)
        if Ok and type(Result) == "table" then
            Kept = Result
        else
            warn(`[PropData] serialize failed for prop {Id}: {Result}`)
        end
    end
    return Codec.encodeMap(Kept)
end

function PropData.loadStates(Id: number, Saved: any, Owner: Player?): States
    local Decoded = Codec.decodeMap(Saved)
    const Found = PropData.definition(Id)
    const Deserialize = if Found then Found.deserialize else nil
    if Deserialize then
        const Ok, Result = pcall(Deserialize, Decoded, Owner)
        if Ok and type(Result) == "table" then
            Decoded = Result
        else
            warn(`[PropData] deserialize failed for prop {Id}: {Result}`)
        end
    end
    return PropData.clean(Id, Decoded, Owner)
end

return PropData
