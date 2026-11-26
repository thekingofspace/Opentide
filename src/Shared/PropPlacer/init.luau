--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const vision = require(ReplicatedStorage.MainPackages.vision)
const Bridges = require(script.Bridges)
const UI = require(ReplicatedStorage.Shared.UI)
const WidgetTypes = require(ReplicatedStorage.Shared.UI.WidgetTypes)
const Panel = UI.view("BuildPanel")
const Toast = UI.view("Toast")
const SaveMenu = UI.view("SaveMenu")
const Sounds = require(ReplicatedStorage.Shared.Sounds)

export type Entry = Bridges.Entry
export type ToolView = Bridges.ToolView
export type SlotView = WidgetTypes.SaveSlot
export type ToastKind = "Error" | "Info"
export type PageHandler = (Requested: number, Current: number) -> number?
export type SearchHandler = (Query: string) -> number?

const PropPlacer = {
    Bridges = Bridges,
}

local Gui: ScreenGui? = nil
local Root: Instance? = nil
local SaveRoot: Instance? = nil

function PropPlacer.load(Parent: Instance?, Visible: boolean?): Instance
    const Existing = Root
    if Existing and Existing.Parent then
        return Existing
    end

    Panel.Toggle(Visible == true)

    local Target = Parent
    if not Target then
        const Screen = vision.create({
            ClassName = "ScreenGui",
            Name = "PropPlacer",
            ResetOnSpawn = false,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        }) :: ScreenGui
        Screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
        Gui = Screen
        Target = Screen
    end

    const Host = Target :: Instance
    const Layer = if Host:IsA("LayerCollector") then Host else Host:FindFirstAncestorWhichIsA("LayerCollector")
    if Layer and Layer.ZIndexBehavior ~= Enum.ZIndexBehavior.Sibling then
        warn("[PropPlacer] mount the panel in a ScreenGui with ZIndexBehavior Sibling or card contents render behind their backgrounds")
    end

    const Made = UI.mount("BuildPanel", Host) or Host
    Root = Made

    const Overlay = Layer or Host
    UI.mount("Toast", Overlay)
    SaveRoot = UI.mount("SaveMenu", Overlay)
    return Made
end

function PropPlacer.unload()
    UI.unmount("BuildPanel")
    UI.unmount("Toast")
    UI.unmount("SaveMenu")
    Root = nil
    SaveRoot = nil
    const Screen = Gui
    Gui = nil
    if Screen then
        Screen:Destroy()
    end
end

function PropPlacer.isLoaded(): boolean
    return Root ~= nil
end

function PropPlacer.setVisible(Visible: boolean)
    Panel.Toggle(Visible)
end

function PropPlacer.isVisible(): boolean
    return Panel.Toggle() == true
end

function PropPlacer.toggle(): boolean
    const Next = not PropPlacer.isVisible()
    Panel.Toggle(Next)
    return Next
end

function PropPlacer.loadEntries(Entries: { Entry })
    Panel.LoadPage(table.clone(Entries))
end

function PropPlacer.clearEntries()
    Panel.LoadPage({})
end

function PropPlacer.setPage(Page: number)
    Panel.Page(Page)
end

function PropPlacer.getPage(): number
    return tonumber(Panel.Page()) or 1
end

function PropPlacer.bindPage(Handler: PageHandler): () -> ()
    return Bridges.Page:Bind(Handler)
end

function PropPlacer.bindSearch(Handler: SearchHandler): () -> ()
    return Bridges.Search:Bind(Handler)
end

function PropPlacer.unbindAll()
    Bridges.Page:Unbind()
    Bridges.Search:Unbind()
    Bridges.Select:Unbind()
    Bridges.Tool:Unbind()
    Bridges.Action:Unbind()
    Bridges.Saves:Unbind()
end

function PropPlacer.toast(Text: string, Kind: ToastKind?)
    Sounds.play(if Kind == "Info" then "Notify" else "Error")
    Toast.Push({ Text = Text, Kind = Kind or "Error" })
end

function PropPlacer.setTools(View: ToolView)
    Panel.Tools(View)
end

function PropPlacer.setMode(Mode: "Browse" | "Edit")
    Panel.Mode(Mode)
end

function PropPlacer.setCount(Current: number, Max: number)
    Panel.CountCurrent(Current)
    Panel.CountMax(Max)
end

function PropPlacer.setSelected(Count: number)
    Panel.Selected(Count)
end

function PropPlacer.setSlots(View: { [number]: SlotView })
    SaveMenu.Slots(View)
end

function PropPlacer.openSaves(Open: boolean)
    SaveMenu.Shown(Open)
end

function PropPlacer.isSavesOpen(): boolean
    return SaveMenu.Shown() == true
end

function PropPlacer.setSaveHint(Text: string?)
    SaveMenu.Hint(Text or "save your placed props, then load them near you or where they were")
end

function PropPlacer.askSlot(Slot: number | false)
    SaveMenu.Ask(Slot)
end

function PropPlacer.blockers(): { GuiObject }
    const Found: { GuiObject } = {}
    const Frame = Root
    if Frame and Frame:IsA("GuiObject") then
        table.insert(Found, Frame)
        const Column = Frame:FindFirstChild("Build_Tools")
        if Column and Column:IsA("GuiObject") then
            table.insert(Found, Column)
        end
    end
    const Menu = SaveRoot
    if Menu and Menu:IsA("GuiObject") then
        table.insert(Found, Menu)
    end
    return Found
end

return PropPlacer
