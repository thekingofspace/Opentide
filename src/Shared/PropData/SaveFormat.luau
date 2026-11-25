--!strict
const PropData = require(script.Parent)
const Codec = require(script.Parent.Codec)
const Config = require(script.Parent.Config)

export type Item = {
    Id: number,
    Pivot: CFrame,
    Scale: number,
    States: { [string]: any }?,
}

const SaveFormat = {}

function SaveFormat.slot(Slot: unknown): string?
    if type(Slot) ~= "number" or Slot ~= math.floor(Slot) or Slot < 1 or Slot > Config.SaveSlots then
        return nil
    end
    return tostring(Slot)
end

function SaveFormat.capture(Records: { Item }, Owner: Player?, Name: string): PropSave
    const Props: { SavedProp } = {}
    for _, Record in Records do
        if not PropData.persists(Record.Id) then
            continue
        end
        const States = PropData.saveStates(Record.Id, Record.States or {}, Owner)
        table.insert(Props, {
            Id = Record.Id,
            Pivot = Codec.packFrame(Record.Pivot),
            Scale = Record.Scale,
            States = if next(States) ~= nil then States else nil,
        })
    end
    return {
        Name = Name,
        Stamp = os.time(),
        Props = Props,
    }
end

function SaveFormat.items(Save: PropSave, Owner: Player?): { Item }
    const Items: { Item } = {}
    if type(Save) ~= "table" or type(Save.Props) ~= "table" then
        return Items
    end
    for _, Saved in Save.Props do
        if type(Saved) ~= "table" or type(Saved.Id) ~= "number" or type(Saved.Scale) ~= "number" then
            continue
        end
        const Pivot = Codec.unpackFrame(Saved.Pivot)
        if not Pivot then
            continue
        end
        const Min, Max = PropData.scaleRange(Saved.Id)
        table.insert(Items, {
            Id = Saved.Id,
            Pivot = Pivot,
            Scale = math.clamp(Saved.Scale, Min, Max),
            States = PropData.loadStates(Saved.Id, Saved.States, Owner),
        })
    end
    return Items
end

return SaveFormat
