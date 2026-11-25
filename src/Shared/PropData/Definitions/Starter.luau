--!strict
const PropData = require(script.Parent.Parent)

const Definitions: PropData.Definitions = {
    [1] = {
        Name = "Abandoned Shelter - Empty",
        Pack = "Shelter",
        Limit = 1,
        Model = "Props/Shelter/Abandoned Shelter - Empty",
    },
    [2] = {
        Name = "Bed 1",
        Pack = "Bedroom",
        Model = "Props/Bedroom/Bed 1",
        Icon = CFrame.new(4, 3, -6) * CFrame.Angles(math.rad(-20), math.rad(150), 0),
    },
}

return Definitions
