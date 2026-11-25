--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")

const PropPlacer = require(script.Parent)
const World = require(script.Parent.World)
const Tools = require(script.Parent.Tools)
const Placement = require(script.Parent.Placement)
const EditMode = require(script.Parent.EditMode)
const Saves = require(script.Parent.Saves)
const Widgets = require(script.Parent.Widgets)
const Hitboxes = require(script.Parent.Hitboxes)
const Sounds = require(ReplicatedStorage.Shared.Sounds)
const signal = require(ReplicatedStorage.MainPackages.signal)

const Controller = {
    PanelKey = Enum.KeyCode.B,
    Shown = signal.new(),
}

const Bridges = PropPlacer.Bridges
local Started = false
local Locked = false

function Controller.canBuild(): boolean
    if RunService:IsStudio() then
        return true
    end
    const Stats = World.stats()
    return Stats ~= nil and Stats.CanBuild
end

const function denied(): boolean
    if Controller.canBuild() then
        return false
    end
    PropPlacer.toast(if World.stats() then "You do not have the build tool" else "Your data is still loading")
    return true
end

const function togglePanel()
    if Locked then
        return
    end
    if PropPlacer.isVisible() then
        PropPlacer.setVisible(false)
    elseif not denied() then
        PropPlacer.setVisible(true)
    end
end

function Controller.togglePanel()
    togglePanel()
end

function Controller.setLocked(Value: boolean)
    Locked = Value
    if Value then
        Placement.cancel()
        EditMode.exit()
        Saves.close()
        PropPlacer.setVisible(false)
    end
end

function Controller.locked(): boolean
    return Locked
end

const function saveSelected()
    const Keys = EditMode.selectedKeys()
    if #Keys == 0 then
        PropPlacer.toast("Select some of your props first")
        return
    end
    Saves.open(Keys)
end

const function onKey(Input: InputObject, Processed: boolean)
    if Processed or Locked or Input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end
    const Key = Input.KeyCode
    if Key == Enum.KeyCode.LeftAlt or Key == Enum.KeyCode.RightAlt then
        if EditMode.active() or not denied() then
            EditMode.toggle()
        end
        return
    end
    if Tools.active() then
        const Name = Tools.Keys[Key]
        if Name then
            Tools.action(Name)
        end
        return
    end
    if EditMode.active() then
        if Key == Enum.KeyCode.E then
            task.spawn(EditMode.editSelected)
        elseif Key == Enum.KeyCode.X then
            task.spawn(EditMode.deleteSelected)
        elseif Key == Controller.PanelKey then
            saveSelected()
        end
        return
    end
    if Key == Controller.PanelKey then
        togglePanel()
    end
end

const function onAction(Name: string)
    if Name == "Saves" then
        Saves.open()
    elseif Name == "Edit" then
        EditMode.enter()
    elseif Name == "Exit" then
        EditMode.exit()
    elseif Name == "EditSelected" then
        task.spawn(EditMode.editSelected)
    elseif Name == "DeleteSelected" then
        task.spawn(EditMode.deleteSelected)
    elseif Name == "SaveSelected" then
        saveSelected()
    elseif Name == "Opened" then
        Sounds.play("PanelOpen")
        Controller.Shown:Fire(true)
    elseif Name == "Closed" then
        Sounds.play("PanelClose")
        Placement.cancel()
        EditMode.exit()
        Saves.close()
        Controller.Shown:Fire(false)
    end
end

function Controller.start()
    if Started then
        return
    end
    Started = true

    World.start()
    EditMode.start()
    Saves.start()
    Widgets.start()
    Hitboxes.start()

    Bridges.Select:Bind(function(Entry: PropPlacer.Entry)
        const Id = Entry.Id
        if Id and not EditMode.active() then
            Sounds.play("PropSelect")
            task.spawn(Placement.place, Id)
        end
    end)
    Bridges.Tool:Bind(function(Name: string)
        Tools.action(Name)
    end)
    Bridges.Action:Bind(onAction)
    Bridges.Saves:Bind(function(Action: string, Slot: number?, Text: string?)
        if (Action == "Here" or Action == "Spot") and EditMode.active() then
            EditMode.exit()
        end
        task.spawn(Saves.action, Action, Slot, Text)
    end)

    Saves.Saved:Connect(function(_, Selected: boolean)
        if Selected then
            Saves.close()
        end
        if EditMode.active() then
            EditMode.exit()
        end
    end)

    World.Stats:Connect(function(Stats: World.Stats)
        PropPlacer.setCount(Stats.Count, Stats.Max)
        if not Controller.canBuild() and PropPlacer.isVisible() then
            PropPlacer.setVisible(false)
        end
    end)
    const Known = World.stats()
    if Known then
        PropPlacer.setCount(Known.Count, Known.Max)
    end

    UserInputService.InputBegan:Connect(onKey)
end

return Controller
