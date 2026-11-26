--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const UserInputService = game:GetService("UserInputService")

const vision = require(ReplicatedStorage.MainPackages.vision)
const PropPlacer = require(ReplicatedStorage.Shared.PropPlacer)
const PropControl = require(ReplicatedStorage.Shared.PropPlacer.Controller)
const CommonStyle = require(ReplicatedStorage.Shared.GUI_Elements.CommonStyle)
const UI = require(ReplicatedStorage.Shared.UI)
const SidebarView = UI.view("Sidebar")
const SettingsView = UI.view("Settings")
const Bridges = require(script.Bridges)
const Settings = require(script.Settings)
const SettingsList = require(script.SettingsList)
const Sidebar = require(script.Sidebar)
const MetaVision = require(script.MetaVision)
const Collisions = require(script.Collisions)
const VFX = require(script.VFX)
const DayNight = require(script.DayNight)
const Weather = require(script.Weather)
const PlayerCards = require(script.PlayerCards)
const Subzones = require(script.Subzones)
const CustomizeMenu = require(ReplicatedStorage.Shared.Customize.Menu)
const ToolsClient = require(ReplicatedStorage.Shared.Tools.Client)
const Movement = require(ReplicatedStorage.Shared.Movement)
const Sounds = require(ReplicatedStorage.Shared.Sounds)
const Images = require(ReplicatedStorage.Shared.Images)
const Radio = require(ReplicatedStorage.Shared.Radio)
const Ruler = require(ReplicatedStorage.Shared.Ruler)
const Dice = require(ReplicatedStorage.Shared.Dice)
const ActionLog = require(ReplicatedStorage.Shared.ActionLog)
const HeadLook = require(ReplicatedStorage.Shared.HeadLook)
const Emotes = require(ReplicatedStorage.Shared.Emotes)
const Footsteps = require(ReplicatedStorage.Shared.Footsteps)
const Omni = require(ReplicatedStorage.Shared.Omni)

const Utility = {
    Sidebar = Sidebar,
    Settings = Settings,
    MetaVisionKey = Enum.KeyCode.G,
    Colors = {
        Customize = Color3.fromRGB(60, 168, 160),
        MetaVision = Color3.fromRGB(140, 90, 230),
        Build = CommonStyle.AccentColor,
        Collisions = Color3.fromRGB(230, 150, 60),
        Settings = Color3.fromRGB(110, 114, 124),
        Run = Color3.fromRGB(70, 150, 210),
        Crouch = Color3.fromRGB(120, 130, 90),
        Crawl = Color3.fromRGB(150, 110, 80),
        Radio = Color3.fromRGB(200, 90, 120),
        Ruler = Color3.fromRGB(214, 170, 60),
        Dice = Color3.fromRGB(90, 170, 110),
        Log = Color3.fromRGB(150, 120, 90),
        Omni = Color3.fromRGB(51, 51, 221),
        Emotes = Color3.fromRGB(230, 120, 170),
    },
}

local Started = false
local SettingsOpen = false
local Hidden = false

const function snapshot(): { [string]: any }
    const Made: { [string]: any } = {}
    for _, Spec in SettingsList do
        Made[Spec.Id] = Settings.get(Spec.Id)
    end
    return Made
end

const function mark(Id: string, Active: boolean)
    const Button = Sidebar.get(Id)
    if Button then
        Button:setActive(Active)
    end
end

function Utility.setMetaVision(On: boolean)
    if MetaVision.active() ~= On then
        Sounds.play(if On then "MetaVisionOn" else "MetaVisionOff")
        Sounds.play(if On then "ToggleOn" else "ToggleOff")
    end
    MetaVision.setActive(On)
    mark("MetaVision", On)
end

function Utility.setCollisions(On: boolean)
    if Collisions.enabled() ~= On then
        Sounds.play(if On then "ToggleOn" else "ToggleOff")
    end
    Collisions.setEnabled(On)
    mark("Collisions", On)
end

const function route(Id: string, Value: any)
    const On = Value == true
    if Id == "VFX" then
        VFX.setEnabled(On)
    elseif Id == "DayNight" then
        DayNight.setEnabled(On)
    elseif Id == "Weather" then
        Weather.setEnabled(On)
    elseif Id == "NoHeadTurn" then
        HeadLook.setEnabled(not On)
    end
    SettingsView.Values(snapshot())
end

function Utility.openSettings(Value: boolean)
    if SettingsOpen ~= Value then
        Sounds.play(if Value then "MenuOpen" else "MenuClose")
    end
    SettingsOpen = Value
    SettingsView.Shown(Value)
end

function Utility.toggleSettings()
    Utility.openSettings(not SettingsOpen)
end

function Utility.setHidden(Gui: ScreenGui, Value: boolean)
    Hidden = Value
    Gui.Enabled = not Value
    PropControl.setLocked(Value)
    if Value then
        Utility.openSettings(false)
    end
end

function Utility.start()
    if Started then
        return
    end
    Started = true
    Settings.start()
    HeadLook.start()
    Footsteps.start()
    VFX.start()
    MetaVision.start()
    Collisions.start()
    PlayerCards.start()

    const Gui = vision.create({
        ClassName = "ScreenGui",
        Name = "Utility",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 4,
    }) :: ScreenGui
    Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    UI.mount("Sidebar", Gui)
    UI.mount("Settings", Gui)
    Sidebar.attach(SidebarView)

    Sidebar.addButton({
        Id = "Customize",
        Text = "customize",
        Icon = Images.get("SidebarCustomize"),
        Color = Utility.Colors.Customize,
        Order = 0,
        pressed = function()
            task.spawn(CustomizeMenu.open)
        end,
    })
    Sidebar.addButton({
        Id = "MetaVision",
        Text = "meta vision",
        Icon = Images.get("SidebarMetaVision"),
        Color = Utility.Colors.MetaVision,
        Order = 10,
        Key = "G",
        Toggle = true,
        Active = MetaVision.active(),
        pressed = function()
            Utility.setMetaVision(not MetaVision.active())
        end,
    })
    Sidebar.addButton({
        Id = "Build",
        Text = "build",
        Icon = Images.get("SidebarBuild"),
        Key = "B",
        Color = Utility.Colors.Build,
        Order = 1,
        pressed = function()
            PropControl.togglePanel()
        end,
    })
    Sidebar.addButton({
        Id = "Collisions",
        Text = "prop collide",
        Icon = Images.get("SidebarCollide"),
        Color = Utility.Colors.Collisions,
        Order = 2,
        Toggle = true,
        Active = Collisions.enabled(),
        pressed = function()
            Utility.setCollisions(not Collisions.enabled())
        end,
    })
    Sidebar.addButton({
        Id = "Run",
        Text = "run",
        Icon = Images.get("SidebarRun"),
        Key = "Shift",
        Color = Utility.Colors.Run,
        Order = 4,
        Toggle = true,
        Active = Movement.running(),
        pressed = function()
            Movement.toggleRun()
            Sounds.play(if Movement.runToggled() then "ToggleOn" else "ToggleOff")
        end,
    })
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        Sidebar.addButton({
            Id = "Crouch",
            Text = "crouch",
            Icon = Images.get("SidebarCrouch"),
            Color = Utility.Colors.Crouch,
            Order = 5,
            Toggle = true,
            Active = false,
            pressed = function()
                Movement.toggleCrouch()
            end,
        })
        Sidebar.addButton({
            Id = "Crawl",
            Text = "crawl",
            Icon = Images.get("SidebarCrawl"),
            Color = Utility.Colors.Crawl,
            Order = 6,
            Toggle = true,
            Active = false,
            pressed = function()
                if not Movement.toggleCrawl() then
                    PropPlacer.toast("Put your tool away to crawl", "Info")
                end
            end,
        })
    end
    Movement.Changed:Connect(function()
        mark("Run", Movement.running())
        mark("Crouch", Movement.stance() == "Crouch")
        mark("Crawl", Movement.stance() == "Crawl")
    end)

    Radio.start()
    Sidebar.addButton({
        Id = "Radio",
        Text = "radio",
        Icon = Images.get("SidebarRadio"),
        Color = Utility.Colors.Radio,
        Order = 9,
        pressed = function()
            Radio.toggle()
        end,
    })

    Emotes.start()
    Sidebar.addButton({
        Id = "Emotes",
        Text = "emotes",
        Icon = Images.get("SidebarEmotes"),
        Color = Utility.Colors.Emotes,
        Order = 6.5,
        pressed = function()
            Emotes.toggle()
        end,
    })

    Ruler.start()
    Sidebar.addButton({
        Id = "Ruler",
        Text = "ruler",
        Icon = Images.get("SidebarRuler"),
        Key = "V",
        Color = Utility.Colors.Ruler,
        Order = 3,
        Toggle = true,
        Active = false,
        pressed = function()
            Ruler.toggle()
        end,
    })
    Ruler.Changed:Connect(function(Value: boolean)
        mark("Ruler", Value)
    end)

    Dice.start()
    Sidebar.addButton({
        Id = "Dice",
        Text = "roll",
        Icon = Images.get("SidebarDice"),
        Color = Utility.Colors.Dice,
        Order = 7,
        pressed = function()
            Dice.toggle()
        end,
    })

    ActionLog.start()
    Sidebar.addButton({
        Id = "ActionLog",
        Text = "action log",
        Icon = Images.get("SidebarLog"),
        Color = Utility.Colors.Log,
        Order = 8,
        pressed = function()
            ActionLog.toggle()
        end,
    })

    Sidebar.addButton({
        Id = "Settings",
        Text = "settings",
        Icon = Images.get("SidebarSettings"),
        Color = Utility.Colors.Settings,
        Order = 20,
        pressed = function()
            Utility.toggleSettings()
        end,
    })

    Bridges.Settings:Bind(function(Action: string, Id: string?)
        if Action == "Close" then
            Utility.openSettings(false)
        elseif Action == "Toggle" and Id then
            Settings.toggle(Id)
            Sounds.play(if Settings.enabled(Id) then "ToggleOn" else "ToggleOff")
        elseif Action == "Up" and Id then
            Settings.step(Id, 1)
        elseif Action == "Down" and Id then
            Settings.step(Id, -1)
        elseif Action == "Save" then
            task.spawn(function()
                const Ok, Problem = Settings.save()
                if Ok then
                    Sounds.play("SettingsSaved")
                end
                PropPlacer.toast(if Ok then "Settings saved" else Problem or "Your settings could not be saved", if Ok then "Info" else "Error")
            end)
        end
    end)

    UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
        if not Processed and not Hidden and Input.KeyCode == Utility.MetaVisionKey then
            Utility.setMetaVision(not MetaVision.active())
        end
    end)

    Settings.Changed:Connect(route)
    Settings.DirtyChanged:Connect(function(Value: boolean)
        SettingsView.Dirty(Value)
    end)
    for _, Spec in SettingsList do
        route(Spec.Id, Settings.get(Spec.Id))
    end
    SettingsView.Dirty(Settings.dirty())
    Subzones.start()

    PropControl.setGate(function(): string?
        return if ToolsClient.current() then "Put your tool away to build" else nil
    end)
    PropControl.Shown:Connect(function(Value: boolean)
        if Value then
            Ruler.set(false)
        end
        Movement.setBlocked(Value)
        ToolsClient.blockInput("Build", Value)
    end)
    task.spawn(function()
        const Allowed = Omni.start()
        if not Allowed.Omni then
            return
        end
        Sidebar.addButton({
            Id = "Omni",
            Text = "omni tool",
            Icon = Images.get("SidebarOmni"),
            Color = Utility.Colors.Omni,
            Ink = Color3.new(1, 1, 1),
            Order = 19,
            pressed = function()
                Omni.toggle()
            end,
        })
    end)

    CustomizeMenu.Opened:Connect(function()
        Omni.show(false)
        Radio.show(false)
        Dice.show(false)
        Emotes.show(false)
        ActionLog.show(false)
        Ruler.set(false)
        Utility.setHidden(Gui, true)
        ToolsClient.setBlocked(true)
    end)
    CustomizeMenu.Closed:Connect(function()
        Utility.setHidden(Gui, false)
        ToolsClient.setBlocked(false)
    end)
    CustomizeMenu.start()
end

return Utility
