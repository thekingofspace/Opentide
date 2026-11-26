--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const vision = require(ReplicatedStorage.MainPackages.vision)
const VisionKit = require(ReplicatedStorage.Shared.VisionKit)
const Parts = require(ReplicatedStorage.Shared.GUI_Elements.Parts)
const Kit = require(ReplicatedStorage.Shared.GUI_Elements.Customize.Kit)
const Bridges = require(ReplicatedStorage.Shared.Emotes.Bridges)

const Style = Kit.Style
const Bridge = Bridges.Emotes

return Kit.Scope:Capture(Kit.panel("Emotes", "emotes", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(420, 520),
    Visible = false,

    { ClassName = "UIScale" },

    vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
        VisionKit.fit(Self :: GuiObject, Later, 0.55)
        const Header = Self:FindFirstChild("Emotes_Header")
        if Header and Header:IsA("GuiObject") then
            Header.Active = true
            Parts.draggable(Self :: GuiObject, Header, Later)
        end
    end),

    vision.event("EmotesShown", false, function(Self: Instance, _, Value: boolean)
        (Self :: GuiObject).Visible = Value == true
    end),
}, {
    Kit.close("Emotes_Close", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -(Kit.Margin + 10), 0, Kit.Margin + Kit.HeaderHeight / 2),
        ZIndex = 5,
    }, Bridge, "Close", nil, 36),

    Parts.merge(Kit.body("Emotes_List"), {
        Kit.section("Emotes_Section", "pick an emote", 1, {
            Kit.chips("Emotes_Grid", "EmoteList", Vector2.new(170, 48), Bridge, "Play", 1),
            Kit.text("Emotes_Hint", "stand still to emote. moving stops it. you can not emote while holding a tool", 13, {
                TextWrapped = true,
                AutomaticSize = Enum.AutomaticSize.Y,
                TextColor3 = Style.OutlineColor,
                LayoutOrder = 2,
            }),
            Kit.press("Emotes_Stop", "stop", { Size = UDim2.new(1, 0, 0, 48), LayoutOrder = 3 }, Style.PlateColor, Style.InkColor, Bridge, "Stop", nil, false, 18),
        }),
    }),
}) :: Frame & any)
