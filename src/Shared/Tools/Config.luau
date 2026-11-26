--!strict
const Config = {
    Slots = 5,
    MaxDepth = 4,
    MaxHolsterOffset = 3,
    MinSize = 0.5,
    MaxSize = 1.5,
    SizeStep = 0.05,
    MoveStep = 0.1,
    TurnStep = 15,
    GripPosition = Vector3.new(0, -0.15, 0),
    Grip = CFrame.Angles(math.rad(-90), 0, 0),
    BenchOffset = Vector3.new(14, 3.5, 0),
    BenchName = "ToolBench",
    OrbitDistance = 6,
    OrbitSensitivity = 0.25,
    SaveDelay = 0.4,
    EquipCooldown = 0.25,
    Categories = {
        Melee = { Name = "melee", Order = 1 },
        Throwing = { Name = "throwing", Order = 2 },
        Guns = { Name = "guns", Order = 3 },
        Food = { Name = "food", Order = 4 },
    } :: { [string]: { Name: string, Order: number } },
}

return Config
