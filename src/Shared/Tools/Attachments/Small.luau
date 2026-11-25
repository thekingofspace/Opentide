--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Tools = require(ReplicatedStorage.Shared.Tools)

const Upright = CFrame.Angles(0, 0, math.rad(90))

const function wrap(Name: string, Order: number): Tools.AttachmentDef
    return {
        Name = Name,
        Kind = "BatWrap",
        Order = Order,
        Offset = Upright,
    }
end

const Small: { [string]: Tools.AttachmentDef } = {
    Nail = {
        Name = "Nail",
        Kind = "Spike",
        Order = 1,
    },

    RustyNail = {
        Name = "Rusty Nail",
        Kind = "Spike",
        Pack = "RustyNails",
        Order = 2,
    },

    RedWrap = wrap("Red Wrap", 1),
    BlueWrap = wrap("Blue Wrap", 2),
    WhiteWrap = wrap("White Wrap", 3),

    Flashlight = {
        Name = "Flashlight",
        Kind = "Light",
        Pack = "Gadgets",
        Order = 1,
        Description = "a small light that shines out from the bat",
    },
}

return Small
