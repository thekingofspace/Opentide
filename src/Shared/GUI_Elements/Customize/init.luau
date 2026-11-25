--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const vision = require(ReplicatedStorage.MainPackages.vision)
const VisionKit = require(ReplicatedStorage.Shared.VisionKit)
const Kit = require(script.Kit)
const Nav = require(script.Nav)
const Body = require(script.Body)
const Rigging = require(script.Rigging)
const Editor = require(script.Editor)
const Saves = require(script.Saves)
const Shop = require(script.Shop)
const Clothes = require(script.Clothes)
const Picker = require(script.Picker)
const ToolsPage = require(script.Tools)
const InfoPage = require(script.Info)

const PageWidth = 480
const Gap = 12
const Height = 780
const MinimumScale = 0.5
const Pages: { [string]: string } = {
    Info = "Info",
    Body = "Body",
    Parts = "Rig",
    Saves = "Saves",
    Tools = "Tools",
}

const function child(Root: Instance, Name: string): GuiObject?
    const Found = Root:FindFirstChild(Name)
    return if Found and Found:IsA("GuiObject") then Found else nil
end

return Kit.Scope:Capture({
    ClassName = "Frame",
    Name = "Customize_Root",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Visible = false,

    vision.event("Shown", false, function(Self: Instance, _, Value: boolean)
        (Self :: GuiObject).Visible = Value == true
    end),

    vision.event("DockShown", true, function(Self: Instance, _, Value: boolean)
        const Dock = child(Self, "Customize_Dock")
        if Dock then
            Dock.Visible = Value
        end
        const Dim = child(Self, "Customize_Dim")
        if Dim then
            Dim.Visible = not Value
        end
    end),

    vision.event("SideShown", true, function(Self: Instance, _, Value: boolean)
        const Dock = child(Self, "Customize_Dock")
        if not Dock then
            return
        end
        const Side = child(Dock, "Nav")
        const Holder = child(Dock, "Customize_Pages")
        if Side then
            Side.Visible = Value
        end
        if Holder then
            Holder.Position = UDim2.fromOffset(if Value then Nav.Width + Gap else 0, 0)
        end
    end),

    vision.event("Page", "Body", function(Self: Instance, _, Value: string)
        const Dock = child(Self, "Customize_Dock")
        const Holder = if Dock then child(Dock, "Customize_Pages") else nil
        if not Holder then
            return
        end
        for Id, Name in Pages do
            const Panel = child(Holder, Name)
            if Panel then
                Panel.Visible = Id == Value
            end
        end
    end),

    vision.event("Editing", false, function(Self: Instance, _, Value: boolean)
        const Dock = child(Self, "Customize_Dock")
        if not Dock then
            return
        end
        const Side = child(Dock, "Nav")
        const Holder = child(Dock, "Customize_Pages")
        const Panel = child(Dock, "Editor")
        if Side then
            Side.Visible = not Value
        end
        if Holder then
            Holder.Visible = not Value
        end
        if Panel then
            Panel.Visible = Value
        end
    end),

    {
        ClassName = "Frame",
        Name = "Customize_Dim",
        Position = UDim2.fromOffset(0, -200),
        Size = UDim2.new(1, 0, 1, 200),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 0,
    },

    {
        ClassName = "Frame",
        Name = "Customize_Dock",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 16, 0.5, 0),
        Size = UDim2.fromOffset(Nav.Width + Gap + PageWidth, Height),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,

        {
            ClassName = "UIScale",
        },

        vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
            VisionKit.fit(Self :: GuiObject, Later, MinimumScale)
        end),

        Nav.build(),

        {
            ClassName = "Frame",
            Name = "Customize_Pages",
            Position = UDim2.fromOffset(Nav.Width + Gap, 0),
            Size = UDim2.fromOffset(PageWidth, Height),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,

            InfoPage.build(),
            Body.build(),
            Rigging.build(),
            Saves.build(),
            ToolsPage.page(),
        },

        Editor.build(),
    },

    Clothes.build(),
    ToolsPage.holster(),
    ToolsPage.slotBar(),
    Shop.build(),
    Picker.build(),
    ToolsPage.picker(),
    ToolsPage.ask(),
}::Frame & any)
