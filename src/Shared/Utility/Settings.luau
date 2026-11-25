--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const signal = require(ReplicatedStorage.MainPackages.signal)
const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const SettingsList = require(script.Parent.SettingsList)

export type Value = SettingsList.Value

const Settings = {
    Changed = signal.new(),
    DirtyChanged = signal.new(),
}

const Net = NetWatch.DataNet
const Values: { [string]: Value } = {}
const Specs: { [string]: SettingsList.Setting } = {}
local Dirty = false
local Started = false

for _, Spec in SettingsList do
    Specs[Spec.Id] = Spec
    Values[Spec.Id] = Spec.Default
end

const function clean(Spec: SettingsList.Setting, Value: unknown): Value?
    if Spec.Kind == "Toggle" then
        return if type(Value) == "boolean" then Value else nil
    end
    if type(Value) ~= "number" or Value ~= Value then
        return nil
    end
    return math.clamp(Value, Spec.Min or -math.huge, Spec.Max or math.huge)
end

const function setDirty(Value: boolean)
    if Dirty ~= Value then
        Dirty = Value
        Settings.DirtyChanged:Fire(Value)
    end
end

function Settings.list(): { SettingsList.Setting }
    return SettingsList
end

function Settings.get(Id: string): Value?
    return Values[Id]
end

function Settings.enabled(Id: string): boolean
    return Values[Id] == true
end

function Settings.set(Id: string, Value: Value): boolean
    const Spec = Specs[Id]
    const Clean = if Spec then clean(Spec, Value) else nil
    if Clean == nil then
        return false
    end
    if Values[Id] == Clean then
        return true
    end
    Values[Id] = Clean
    setDirty(true)
    Settings.Changed:Fire(Id, Clean)
    return true
end

function Settings.toggle(Id: string): boolean
    return Settings.set(Id, not Settings.enabled(Id))
end

function Settings.step(Id: string, Direction: number): boolean
    const Spec = Specs[Id]
    const Current = Values[Id]
    if not Spec or Spec.Kind ~= "Number" or type(Current) ~= "number" then
        return false
    end
    return Settings.set(Id, Current + (Spec.Step or 1) * Direction)
end

function Settings.dirty(): boolean
    return Dirty
end

function Settings.save(): (boolean, string?)
    const Reply = Net:Call("@Settings/Save", table.clone(Values))
    if type(Reply) ~= "table" then
        return false, "The server did not answer"
    end
    if not Reply.Ok then
        return false, if type(Reply.Error) == "string" then Reply.Error else "Your settings could not be saved"
    end
    setDirty(false)
    return true, nil
end

function Settings.start()
    if Started then
        return
    end
    Started = true
    Net:On("@Settings/State", function(Saved: unknown)
        if type(Saved) ~= "table" then
            return
        end
        for Id, Value in Saved :: { [any]: any } do
            const Spec = if type(Id) == "string" then Specs[Id] else nil
            const Clean = if Spec then clean(Spec, Value) else nil
            if Clean ~= nil and Values[Id] ~= Clean then
                Values[Id] = Clean
                Settings.Changed:Fire(Id, Clean)
            end
        end
        setDirty(false)
    end)
end

return Settings
