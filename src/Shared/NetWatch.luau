const ReplicatedStorage = game:GetService("ReplicatedStorage")
const pigeon = require(ReplicatedStorage.MainPackages.pigeon)
local self

self = table.freeze({
    PropPlacer = pigeon.new("Prop_Placer_Net"),
    AdminNet = pigeon.new("Admin_Network"),
    DataNet = pigeon.new("Data_Net"),
    Customize = pigeon.new("Customize_Net"),
    Shop = pigeon.new("Shop_Net"),
    Tools = pigeon.new("Tools_Net"),
    Dice = pigeon.new("Dice_Net"),
    Bio = pigeon.new("Bio_Net"),
    Look = pigeon.new("Look_Net"),
    Bullets = pigeon.new("Bullets_Net", { Unreliable = true }),

    Start = function()
        self.AdminNet:Init()
        self.PropPlacer:Init()
        self.DataNet:Init()
        self.Customize:Init()
        self.Shop:Init()
        self.Tools:Init()
        self.Dice:Init()
        self.Bio:Init()
        self.Look:Init()
        self.Bullets:Init()
    end
})

return self