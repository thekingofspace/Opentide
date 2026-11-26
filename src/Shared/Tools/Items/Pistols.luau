--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Clips = require(ReplicatedStorage.Shared.AnimationController.Clips)
const Tools = require(ReplicatedStorage.Shared.Tools)
const Guns = require(ReplicatedStorage.Shared.Tools.Guns)

const A = Clips.angles

const Rest: Clips.Poses = {
    RightUpperArm = A(0, 0, 0),
    RightLowerArm = A(0, 0, 0),
    LeftUpperArm = A(0, 0, 0),
    LeftLowerArm = A(0, 0, 0),
}

const Hold: Clips.Poses = {
    UpperTorso = A(0, -20, 0),
    RightUpperArm = A(53, 9, -61),
    RightLowerArm = A(40, 0, 0),
    RightHand = A(-13, 28, 18),
    LeftUpperArm = A(39, -14, 41),
    LeftLowerArm = A(59, 0, 0),
    LeftHand = A(-63, 19, 57),
}

const HoldOne: Clips.Poses = {
    RightUpperArm = A(45, 16, -24),
    RightLowerArm = A(71, 0, 0),
    RightHand = A(-25, 6, 23),
}

const Down: Clips.Poses = {
    UpperTorso = A(0, -15, 0),
    RightUpperArm = A(35, 10, -47),
    RightLowerArm = A(30, 0, 0),
    RightHand = A(-23, 8, 27),
    LeftUpperArm = A(39, -1, 49),
    LeftLowerArm = A(2, 0, 0),
    LeftHand = A(-9, -4, -6),
}

const DownOne: Clips.Poses = {
    RightUpperArm = A(3, 7, -8),
    RightLowerArm = A(61, 0, 0),
    RightHand = A(-18, 0, 8),
}

const Up: Clips.Poses = {
    RightUpperArm = A(9, 58, -23),
    RightLowerArm = A(147, 0, 0),
    RightHand = A(61, 63, -42),
    LeftUpperArm = A(0, 0, 3),
    LeftLowerArm = A(15, 0, 0),
}

const Unload: Clips.Poses = {
    UpperTorso = A(0, -10, 0),
    RightUpperArm = A(27, 40, -40),
    RightLowerArm = A(87, 0, 0),
    RightHand = A(-60, 10, 17),
    LeftUpperArm = A(-26, -11, 21),
    LeftLowerArm = A(77, 0, 0),
    LeftHand = A(-35, 4, -25),
}

const Load: Clips.Poses = {
    UpperTorso = A(0, -10, 0),
    RightUpperArm = A(27, 40, -40),
    RightLowerArm = A(87, 0, 0),
    RightHand = A(-60, 10, 17),
    LeftUpperArm = A(34, -2, 63),
    LeftLowerArm = A(2, 0, 0),
    LeftHand = A(3, -36, -34),
}

const function clips(): { [string]: Tools.ClipValue }
    return {
        Hold = { Name = "Hold", Loop = true, Priority = Enum.AnimationPriority.Idle, Frames = {
            { Time = 0, Poses = Hold },
            { Time = 1, Poses = Hold },
        } },
        Down = { Name = "Down", Loop = true, Priority = Enum.AnimationPriority.Movement, Frames = {
            { Time = 0, Poses = Down },
            { Time = 1, Poses = Down },
        } },
        Up = { Name = "Up", Loop = true, Priority = Enum.AnimationPriority.Movement, Frames = {
            { Time = 0, Poses = Up },
            { Time = 1, Poses = Up },
        } },
        Hold_OneHand = { Name = "Hold_OneHand", Loop = true, Priority = Enum.AnimationPriority.Idle, Frames = {
            { Time = 0, Poses = HoldOne },
            { Time = 1, Poses = HoldOne },
        } },
        Down_OneHand = { Name = "Down_OneHand", Loop = true, Priority = Enum.AnimationPriority.Movement, Frames = {
            { Time = 0, Poses = DownOne },
            { Time = 1, Poses = DownOne },
        } },
        Reload = { Name = "Reload", Priority = Enum.AnimationPriority.Action, Frames = {
            { Time = 0, Poses = Hold },
            { Time = 0.22, Poses = Unload },
            { Time = 0.5, Poses = Unload },
            { Time = 0.78, Poses = Load, Style = Enum.PoseEasingStyle.Cubic, Direction = Enum.PoseEasingDirection.Out },
            { Time = 0.92, Poses = Load },
            { Time = 1.2, Poses = Hold },
        } },
        Equip = { Name = "Equip", Priority = Enum.AnimationPriority.Action, Frames = {
            { Time = 0, Poses = Rest },
            { Time = 0.25, Poses = Hold },
        } },
        PutAway = { Name = "PutAway", Priority = Enum.AnimationPriority.Action, Frames = {
            { Time = 0, Poses = Hold },
            { Time = 0.25, Poses = Rest },
        } },
    }
end

const function sets(): { [string]: Tools.SetSpec }
    return {
        Held = { Body = { Idle = "Hold", Walk = "Hold" } },
        Down = { Body = { Idle = "Down", Walk = "Down" } },
        Up = { Body = { Idle = "Up", Walk = "Up" } },
    }
end

const function actions(): { Tools.Action }
    return {
        { Id = "Reload", Label = "reload", Key = Enum.KeyCode.R },
        { Id = "Lower", Label = "point down", Key = Enum.KeyCode.Q, Toggle = true },
        { Id = "Raise", Label = "point up", Key = Enum.KeyCode.E, Toggle = true },
    }
end

const Items: { [string]: Tools.ToolDef } = {
    Pistol = {
        Name = "Pistol",
        Category = "Guns",
        Order = 1,
        Description = "a basic pistol. swap the body, barrel and muzzle to change how it sounds and what it fires",
        Mounts = {
            { Id = "Frame", Label = "body", Accepts = { "PistolFrame" }, Offset = CFrame.identity, Required = true },
        },
        Defaults = {
            Frame = "StandardFrame",
            ["Frame/Barrel"] = "StandardBarrel",
        },
        Stats = {
            Bullet = "Standard",
            FireSound = 127604219525464,
            FireVolume = 0.8,
            FireRate = 0.22,
            Spread = 2,
            Range = 500,
            Magazine = 12,
            ReloadTime = 1.3,
        },
        Clips = clips(),
        Sets = sets(),
        Equip = "Equip",
        Unequip = "PutAway",
        Actions = actions(),
        Dual = { Tags = { "Gun" }, With = { "Gun", "Shield" } },
        client = Guns.client(),
        server = Guns.server(),
    },

    LaserPistol = {
        Name = "Laser Pistol",
        Category = "Guns",
        Order = 2,
        Description = "fires instant laser bolts. swap the emitter to change the color and the bolt",
        Mounts = {
            { Id = "Frame", Label = "body", Accepts = { "LaserFrame" }, Offset = CFrame.identity, Required = true },
        },
        Defaults = {
            Frame = "LaserFrame",
            ["Frame/Emitter"] = "RedEmitter",
        },
        Stats = {
            Bullet = "LaserRed",
            FireSound = 9065667699,
            FireVolume = 0.7,
            FireRate = 0.3,
            Spread = 0.8,
            Range = 600,
            Magazine = 20,
            ReloadTime = 1.6,
        },
        Clips = clips(),
        Sets = sets(),
        Equip = "Equip",
        Unequip = "PutAway",
        Actions = actions(),
        Dual = { Tags = { "Gun" }, With = { "Gun", "Shield" } },
        client = Guns.client(),
        server = Guns.server(),
    },
}

return Items
