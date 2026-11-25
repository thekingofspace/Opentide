--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Tools = require(ReplicatedStorage.Shared.Tools)

const function frame(Name: string, Slide: Vector3, Order: number, Description: string, Mods: { [string]: any }?): Tools.AttachmentDef
    return {
        Name = Name,
        Kind = "PistolFrame",
        Order = Order,
        Description = Description,
        Mods = Mods,
        Mounts = {
            { Id = "Barrel", Label = "barrel", Accepts = { "PistolBarrel" }, Offset = CFrame.new(0, 0.38, 0.2 - Slide.Z), Required = true },
            { Id = "Rail", Label = "sight", Accepts = { "Sight" }, Offset = CFrame.new(0, 0.38 + Slide.Y / 2, -0.25) },
        },
    }
end

const function barrel(Name: string, Order: number, Description: string, Mods: { [string]: any }?): Tools.AttachmentDef
    return {
        Name = Name,
        Kind = "PistolBarrel",
        Order = Order,
        Description = Description,
        Mods = Mods,
        Mounts = {
            { Id = "Muzzle", Label = "muzzle", Accepts = { "MuzzleDevice" }, Offset = CFrame.new(0, 0, -0.35) },
        },
    }
end

const function emitter(Name: string, Order: number, Description: string, Mods: { [string]: any }?): Tools.AttachmentDef
    return {
        Name = Name,
        Kind = "LaserEmitter",
        Order = Order,
        Description = Description,
        Mods = Mods,
    }
end

const Parts: { [string]: Tools.AttachmentDef } = {
    StandardFrame = frame("Standard Frame", Vector3.new(0.26, 0.28, 1.05), 1, "a plain pistol body"),
    HeavyFrame = frame("Heavy Frame", Vector3.new(0.32, 0.34, 1.2), 2, "big and loud, fires slower but steadier", {
        FireSound = 3102797479,
        FireVolume = 0.9,
        FireRateScale = 1.6,
        SpreadScale = 0.7,
        MagazineScale = 0.6,
    }),

    StandardBarrel = barrel("Standard Barrel", 1, "fires normal rounds"),
    TracerBarrel = barrel("Tracer Barrel", 2, "fires bright tracer rounds", {
        Bullet = "Tracer",
    }),

    Suppressor = {
        Name = "Suppressor",
        Kind = "MuzzleDevice",
        Order = 1,
        Description = "makes shots much quieter",
        Mods = {
            FireSound = 89214508659473,
            FireVolume = 0.5,
            SpreadScale = 0.85,
        },
    },

    Scope = {
        Name = "Scope",
        Kind = "Sight",
        Order = 1,
        Description = "zooms in further when you aim and steadies your shots",
        Mods = {
            Zoom = 2.5,
            AimSpreadScale = 0.5,
        },
    },

    LaserFrame = {
        Name = "Laser Frame",
        Kind = "LaserFrame",
        Order = 1,
        Description = "a light sci fi body with a cell in the side",
        Mounts = {
            { Id = "Emitter", Label = "emitter", Accepts = { "LaserEmitter" }, Offset = CFrame.new(0, 0.4, -0.8), Required = true },
            { Id = "Rail", Label = "sight", Accepts = { "Sight" }, Offset = CFrame.new(0, 0.57, -0.25) },
        },
    },

    RedEmitter = emitter("Red Emitter", 1, "fires quick red bolts", {
        Bullet = "LaserRed",
    }),
    BlueEmitter = emitter("Blue Emitter", 2, "fires thick blue beams, a little slower", {
        Bullet = "LaserBlue",
        FireSound = 6603571443,
        FireRateScale = 1.3,
    }),
}

return Parts
