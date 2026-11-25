--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Tools = require(ReplicatedStorage.Shared.Tools)

const function around(Count: number, Height: number, Radius: number, Accepts: { string }, Label: string, Prefix: string): { Tools.Mount }
    const Made: { Tools.Mount } = {}
    for Index = 1, Count do
        table.insert(Made, {
            Id = `{Prefix}{Index}`,
            Label = Label,
            Accepts = Accepts,
            Offset = CFrame.new(0, Height, 0) * CFrame.Angles(0, math.rad((Index - 1) * 360 / Count), 0) * CFrame.new(Radius, 0, 0),
        })
    end
    return Made
end

const function handle(Name: string, Order: number, Description: string): Tools.AttachmentDef
    return {
        Name = Name,
        Kind = "BatHandle",
        Order = Order,
        Description = Description,
        Mounts = {
            { Id = "Wrap", Label = "grip wrap", Accepts = { "BatWrap" }, Offset = CFrame.new(0, 0.35, 0) },
        },
    }
end

const Barrels: { [string]: Tools.AttachmentDef } = {
    WoodHandle = handle("Wood Handle", 1, "a taped wood handle"),
    MetalHandle = handle("Metal Handle", 2, "a cold metal handle"),

    WoodBarrel = {
        Name = "Wood Barrel",
        Kind = "BatBarrel",
        Order = 1,
        Description = "a classic wood top with room for nails",
        Mounts = around(4, 1.25, 0.21, { "Spike" }, "nail", "Nail"),
    },

    MetalBarrel = {
        Name = "Metal Barrel",
        Kind = "BatBarrel",
        Order = 2,
        Description = "a light metal top with a tip and two side spots",
        Mounts = {
            { Id = "Tip", Label = "tip", Accepts = { "Light" }, Offset = CFrame.new(0, 1.86, 0) },
            { Id = "Side1", Label = "side", Accepts = { "Light", "Spike" }, Offset = CFrame.new(0.18, 1.1, 0) },
            { Id = "Side2", Label = "side", Accepts = { "Light", "Spike" }, Offset = CFrame.new(-0.18, 1.1, 0) * CFrame.Angles(0, math.rad(180), 0) },
        },
    },
}

return Barrels
