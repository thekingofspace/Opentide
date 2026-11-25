--!strict
const Catalog = require(script.Parent.Parent)

const Build = Catalog.Build
const White = Color3.fromRGB(242, 242, 242)
const Front = CFrame.new(0, 0, -1.1)

const function wedge(Name: string, Corner: boolean): BasePart
    const Made: BasePart = if Corner then Instance.new("CornerWedgePart") else Instance.new("WedgePart")
    Made.Name = Name
    Made.Size = Vector3.one
    Made.Color = White
    Made.Material = Enum.Material.SmoothPlastic
    Made.Anchored = false
    Made.CanCollide = false
    Made.CanTouch = false
    Made.Massless = true
    return Made
end

const Parts: Catalog.Parts = {
    Cube = {
        Name = "Cube",
        Order = 1,
        Attach = "UpperTorso",
        Offset = Front,
        build = function(): Catalog.Built
            return Build.part("Cube", Vector3.one, White)
        end,
    },

    Sphere = {
        Name = "Sphere",
        Order = 2,
        Attach = "UpperTorso",
        Offset = Front,
        build = function(): Catalog.Built
            return Build.ball("Sphere", 1, White)
        end,
    },

    Cylinder = {
        Name = "Cylinder",
        Order = 3,
        Attach = "UpperTorso",
        Offset = Front,
        build = function(): Catalog.Built
            return Build.part("Cylinder", Vector3.new(1, 1, 1), White, nil, Enum.PartType.Cylinder)
        end,
    },

    Wedge = {
        Name = "Wedge",
        Order = 4,
        Attach = "UpperTorso",
        Offset = Front,
        build = function(): Catalog.Built
            return wedge("Wedge", false)
        end,
    },

    CornerWedge = {
        Name = "Corner Wedge",
        Order = 5,
        Attach = "UpperTorso",
        Offset = Front,
        build = function(): Catalog.Built
            return wedge("CornerWedge", true)
        end,
    },

    Plate = {
        Name = "Plate",
        Order = 6,
        Attach = "UpperTorso",
        Offset = Front,
        build = function(): Catalog.Built
            return Build.part("Plate", Vector3.new(1, 0.2, 1), White)
        end,
    },
}

return Parts
