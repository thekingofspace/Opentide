--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Clips = require(ReplicatedStorage.Shared.AnimationController.Clips)
const Tools = require(ReplicatedStorage.Shared.Tools)
const Guns = require(ReplicatedStorage.Shared.Tools.Guns)

const A = Clips.angles

const Rest: Clips.Poses = {
    RightUpperArm = A(0, 0, 0),
    RightLowerArm = A(0, 0, 0),
}

const Hold: Clips.Poses = {
    UpperTorso = A(0, -8, 0),
    RightUpperArm = A(90, 0, -8),
    RightLowerArm = A(0, 0, 0),
    LeftUpperArm = A(80, 0, 35),
    LeftLowerArm = A(25, 0, 0),
}

const Down: Clips.Poses = {
    RightUpperArm = A(40, 0, -5),
    RightLowerArm = A(25, 0, 0),
    LeftUpperArm = A(10, 0, 0),
    LeftLowerArm = A(10, 0, 0),
}

const Up: Clips.Poses = {
    RightUpperArm = A(20, 0, -15),
    RightLowerArm = A(150, 0, 0),
    LeftUpperArm = A(10, 0, 0),
    LeftLowerArm = A(10, 0, 0),
}

const Loading: Clips.Poses = {
    UpperTorso = A(0, -8, 0),
    RightUpperArm = A(50, 0, -30),
    RightLowerArm = A(65, 0, 0),
    RightHand = A(0, 0, 35),
    LeftUpperArm = A(35, 0, 25),
    LeftLowerArm = A(70, 0, 0),
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
        Reload = { Name = "Reload", Priority = Enum.AnimationPriority.Action, Frames = {
            { Time = 0, Poses = Hold },
            { Time = 0.25, Poses = Loading },
            { Time = 0.95, Poses = Loading },
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
        { Id = "Aim", Label = "zoom (right click)", Toggle = true },
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
            AimSpread = 0.5,
            Range = 500,
            Zoom = 1.25,
            Magazine = 12,
            ReloadTime = 1.3,
        },
        Clips = clips(),
        Sets = sets(),
        Equip = "Equip",
        Unequip = "PutAway",
        Actions = actions(),
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
            AimSpread = 0.2,
            Range = 600,
            Zoom = 1.25,
            Magazine = 20,
            ReloadTime = 1.6,
        },
        Clips = clips(),
        Sets = sets(),
        Equip = "Equip",
        Unequip = "PutAway",
        Actions = actions(),
        client = Guns.client(),
        server = Guns.server(),
    },
}

return Items
