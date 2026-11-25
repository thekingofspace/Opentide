--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const vision = require(ReplicatedStorage.MainPackages.vision)
const Parts = require(ReplicatedStorage.Shared.GUI_Elements.Parts)
const Bridges = require(ReplicatedStorage.Shared.Customize.Bridges)
const Config = require(ReplicatedStorage.Shared.Customize.Config)
const Kit = require(script.Parent.Kit)

const Style = Kit.Style
const Common = Kit.Common
const Bridge = Bridges.Saves

const Saves = {
    RowHeight = 92,
    Hint = "saves let you load a look again later. leaving always wears your look, you do not need to save first",
}

const function row(Slot: number): Kit.Declaration
    return Parts.card(`Look_Slot_{Slot}`, {
        Size = UDim2.new(1, 0, 0, Saves.RowHeight),
        LayoutOrder = Slot,
    }, {
        BackgroundColor3 = Common["CardColor"],

        Parts.card(`Look_Slot_{Slot}_Plate`, {
            Position = UDim2.fromOffset(10, 10),
            Size = UDim2.fromOffset(48, 48),
        }, {
            BackgroundColor3 = Style.PlateColor,
            Kit.text("Number", tostring(Slot), 24, {
                Position = UDim2.fromOffset(0, 2),
                Size = UDim2.fromScale(1, 1),
                FontFace = Parts.Heading,
                TextXAlignment = Enum.TextXAlignment.Center,
            }),
        }, 3, nil, 1.6),

        Kit.input(`Look_Slot_{Slot}_Name`, `name look {Slot}`, {
            Position = UDim2.fromOffset(68, 10),
            Size = UDim2.new(1, -78, 0, 32),
        }, function(Text: string)
            Bridge:Call("Name", Slot, Text)
        end),

        Kit.text("Detail", "empty slot", 14, {
            Position = UDim2.fromOffset(70, 46),
            Size = UDim2.new(1, -260, 0, 16),
            TextColor3 = Common["PackColor"],
        }),

        Kit.text("Stamp", "", 12, {
            Position = UDim2.fromOffset(70, 64),
            Size = UDim2.new(1, -260, 0, 14),
            TextColor3 = Common["MutedColor"],
        }),

        Kit.close(`Look_Slot_{Slot}_Clear`, {
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -10, 1, -10),
            Visible = false,
        }, Bridge, "Clear", Slot, 36),

        Kit.press(`Look_Slot_{Slot}_Load`, "load", {
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -54, 1, -8),
            Size = UDim2.fromOffset(72, 36),
            Visible = false,
        }, Style.SuccessColor, Style.SuccessText, Bridge, "Load", Slot, true, 16),

        Kit.press(`Look_Slot_{Slot}_Save`, "save", {
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -10, 1, -8),
            Size = UDim2.fromOffset(72, 36),
        }, Style.AccentColor, Style.AccentText, Bridge, "Save", Slot, true, 16),
    }, nil, nil, Kit.ItemStroke)
end

const function fill(Root: Instance, Views: { Bridges.SlotView })
    for Slot = 1, Config.SaveSlots do
        const View = Views[Slot]
        const Body = Root:FindFirstChild(`Look_Slot_{Slot}_Body`, true)
        if not View or not Body or not Body:IsA("GuiObject") then
            continue
        end
        Body.BackgroundColor3 = if View.Filled then Style.ButtonColor else Style.CardColor
        Kit.boxText(Body, `Look_Slot_{Slot}_Name`, View.Name)
        Kit.label(Body, "Detail", View.Detail)
        Kit.label(Body, "Stamp", View.Stamp)
        Kit.setButton(Body, `Look_Slot_{Slot}_Save`, if View.Confirm then "sure?" else "save", if View.Confirm then Style.CloseColor else Style.AccentColor)
        Kit.show(Body, `Look_Slot_{Slot}_Load`, View.Filled)
        Kit.show(Body, `Look_Slot_{Slot}_Clear`, View.Filled)
        Kit.setButton(Body, `Look_Slot_{Slot}_Clear`, if View.ConfirmClear then "?" else "X")
        const Plate = Body:FindFirstChild(`Look_Slot_{Slot}_Plate_Body`, true)
        if Plate and Plate:IsA("GuiObject") then
            Plate.BackgroundColor3 = if View.Filled then Style.AccentColor else Style.PlateColor
            const Number = Plate:FindFirstChild("Number")
            if Number and Number:IsA("TextLabel") then
                Number.TextColor3 = if View.Filled then Style.AccentText else Style.InkColor
            end
        end
        const Save = Body:FindFirstChild(`Look_Slot_{Slot}_Save`)
        if Save and Save:IsA("GuiObject") then
            Save.Position = if View.Filled then UDim2.new(1, -130, 1, -8) else UDim2.new(1, -10, 1, -8)
        end
    end
end

function Saves.build(): Kit.Declaration
    const List = Kit.body("Saves_List", Kit.Margin + Kit.HeaderHeight + 52)
    for Slot = 1, Config.SaveSlots do
        table.insert(List, row(Slot))
    end
    return Kit.panel("Saves", "saves", {
        Size = UDim2.fromScale(1, 1),
        Visible = false,

        vision.event("SaveSlots", {}, function(Self: Instance, _, Views: { Bridges.SlotView })
            fill(Self, Views)
        end),
    }, {
        Kit.text("Saves_Hint", Saves.Hint, 14, {
            Position = UDim2.fromOffset(Kit.Margin + 4, Kit.Margin + Kit.HeaderHeight + 8),
            Size = UDim2.new(1, -(Kit.Margin + 4) * 2, 0, 36),
            TextWrapped = true,
            TextColor3 = Common["OutlineColor"],
            TextYAlignment = Enum.TextYAlignment.Top,
        }),
        List,
    })
end

return Saves
