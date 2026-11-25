--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const signal = require(ReplicatedStorage.MainPackages.signal)
const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const Config = require(ReplicatedStorage.Shared.PropData.Config)
const SaveFormat = require(ReplicatedStorage.Shared.PropData.SaveFormat)
const PropPlacer = require(script.Parent)
const Placement = require(script.Parent.Placement)
const Sounds = require(ReplicatedStorage.Shared.Sounds)

type Confirming = {
    Slot: number,
    Action: "Save" | "Clear",
    Token: number,
}

const Saves = {
    ConfirmTime = 3,
    Changed = signal.new(),
    Saved = signal.new(),
}

const Net = NetWatch.PropPlacer
const Slots: { [string]: PropSave } = {}
const Drafts: { [number]: string } = {}
local Asking: number? = nil
local Picked: { string }? = nil
local Confirm: Confirming? = nil
local ConfirmToken = 0
local Started = false

const function render()
    const View: { [number]: PropPlacer.SlotView } = {}
    for Slot = 1, Config.SaveSlots do
        const Save = Slots[tostring(Slot)]
        const Waiting = Confirm
        const Count = if Save then #Save.Props else 0
        View[Slot] = {
            Name = if Save then Save.Name else Drafts[Slot] or "",
            Detail = if Save then `{Count} {if Count == 1 then "prop" else "props"}` else "empty slot",
            Stamp = if Save then string.lower(os.date("%b %d, %H:%M", Save.Stamp)) else "",
            Filled = Save ~= nil,
            Confirm = Waiting ~= nil and Waiting.Slot == Slot and Waiting.Action == "Save",
            ConfirmClear = Waiting ~= nil and Waiting.Slot == Slot and Waiting.Action == "Clear",
        }
    end
    PropPlacer.setSlots(View)
end

const function replace(All: unknown)
    if type(All) ~= "table" then
        return
    end
    table.clear(Slots)
    for Key, Save in All :: { [any]: any } do
        if type(Key) == "string" and type(Save) == "table" and type(Save.Props) == "table" then
            Slots[Key] = Save
        end
    end
    render()
    Saves.Changed:Fire()
end

const function confirmed(Slot: number, Action: "Save" | "Clear"): boolean
    const Waiting = Confirm
    if Waiting and Waiting.Slot == Slot and Waiting.Action == Action then
        Confirm = nil
        render()
        return true
    end
    ConfirmToken += 1
    const Mine = ConfirmToken
    Sounds.play("Confirm")
    Confirm = { Slot = Slot, Action = Action, Token = Mine }
    render()
    task.delay(Saves.ConfirmTime, function()
        const Still = Confirm
        if Still and Still.Token == Mine then
            Confirm = nil
            render()
        end
    end)
    return false
end

function Saves.get(Slot: number): PropSave?
    return Slots[tostring(Slot)]
end

function Saves.all(): { [string]: PropSave }
    return Slots
end

function Saves.open(Keys: { string }?)
    Asking = nil
    Confirm = nil
    Picked = if Keys and #Keys > 0 then table.clone(Keys) else nil
    PropPlacer.setSaveHint(if Picked then `saving only your {#Picked} selected {if #Picked == 1 then "prop" else "props"}, pick a slot` else nil)
    PropPlacer.askSlot(false)
    render()
    Sounds.play("MenuOpen")
    PropPlacer.openSaves(true)
end

function Saves.close()
    if PropPlacer.isSavesOpen() then
        Sounds.play("MenuClose")
    end
    Asking = nil
    Confirm = nil
    Picked = nil
    PropPlacer.setSaveHint(nil)
    PropPlacer.askSlot(false)
    PropPlacer.openSaves(false)
end

function Saves.save(Slot: number)
    const Key = tostring(Slot)
    if Slots[Key] and not confirmed(Slot, "Save") then
        return
    end
    const Reply = Net:Call("@Props/Save", Slot, Picked, Drafts[Slot])
    if type(Reply) ~= "table" then
        PropPlacer.toast("The server did not answer, try again")
        return
    end
    if not Reply.Ok then
        PropPlacer.toast(if type(Reply.Error) == "string" then Reply.Error else "That could not be saved")
        return
    end
    if type(Reply.Save) == "table" then
        Slots[Key] = Reply.Save
    end
    Drafts[Slot] = nil
    render()
    Saves.Changed:Fire()
    Sounds.play("SaveSlot")
    PropPlacer.toast(`Saved to {if type(Reply.Save) == "table" then Reply.Save.Name else `slot {Slot}`}`, "Info")
    Saves.Saved:Fire(Slot, Picked ~= nil)
end

function Saves.clear(Slot: number)
    const Key = tostring(Slot)
    if not Slots[Key] or not confirmed(Slot, "Clear") then
        return
    end
    const Reply = Net:Call("@Props/ClearSave", Slot)
    if type(Reply) ~= "table" or not Reply.Ok then
        PropPlacer.toast(if type(Reply) == "table" and type(Reply.Error) == "string" then Reply.Error else "That slot could not be cleared")
        return
    end
    Slots[Key] = nil
    Sounds.play("ClearSlot")
    render()
    Saves.Changed:Fire()
end

function Saves.rename(Slot: number, Text: string?)
    const Key = tostring(Slot)
    const Clean = string.match(Text or "", "^%s*(.-)%s*$") or ""
    if not Slots[Key] then
        Drafts[Slot] = if Clean ~= "" then Clean else nil
        render()
        return
    end
    if Clean == "" or Clean == Slots[Key].Name then
        render()
        return
    end
    const Reply = Net:Call("@Props/Rename", Slot, Clean)
    if type(Reply) ~= "table" or not Reply.Ok then
        PropPlacer.toast(if type(Reply) == "table" and type(Reply.Error) == "string" then Reply.Error else "That name could not be saved")
    elseif type(Reply.Save) == "table" then
        Slots[Key] = Reply.Save
        Sounds.play("SaveSlot")
    end
    render()
    Saves.Changed:Fire()
end

function Saves.loadSpot(Slot: number)
    const Reply = Net:Call("@Props/LoadSpot", Slot)
    if type(Reply) ~= "table" then
        PropPlacer.toast("The server did not answer, try again")
    elseif not Reply.Ok then
        PropPlacer.toast(if type(Reply.Error) == "string" then Reply.Error else "That save could not load")
    else
        Sounds.play("LoadSlot")
        PropPlacer.toast(`Loaded slot {Slot} at its save spot`, "Info")
    end
end

function Saves.loadHere(Slot: number)
    const Save = Slots[tostring(Slot)]
    if not Save then
        PropPlacer.toast("That save slot is empty")
        return
    end
    const Items = SaveFormat.items(Save, nil)
    if #Items == 0 then
        PropPlacer.toast("That save has nothing to load")
        return
    end
    Sounds.play("LoadSlot")
    Placement.load(Items)
end

function Saves.action(Action: string, Slot: number?, Text: string?)
    if Action == "Close" then
        Saves.close()
    elseif Action == "Name" and Slot then
        Saves.rename(Slot, Text)
    elseif Action == "Save" and Slot then
        Saves.save(Slot)
    elseif Action == "Clear" and Slot then
        Saves.clear(Slot)
    elseif Action == "Load" and Slot and Slots[tostring(Slot)] then
        Asking = Slot
        PropPlacer.askSlot(Slot)
    elseif Action == "Back" then
        Asking = nil
        PropPlacer.askSlot(false)
    elseif Action == "Here" or Action == "Spot" then
        const Chosen = Asking
        if not Chosen then
            return
        end
        Saves.close()
        if Action == "Here" then
            Saves.loadHere(Chosen)
        else
            Saves.loadSpot(Chosen)
        end
    end
end

function Saves.start()
    if Started then
        return
    end
    Started = true
    render()
    Net:On("@Props/Saves", replace)
end

return Saves
