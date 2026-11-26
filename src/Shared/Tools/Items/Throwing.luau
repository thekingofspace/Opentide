--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Clips = require(ReplicatedStorage.Shared.AnimationController.Clips)
const Throwables = require(ReplicatedStorage.Shared.Tools.Throwables)

const A = Clips.angles

const Down: Clips.Poses = {}

const KnifeHold: Clips.Poses = {
    RightUpperArm = A(-9, 17, -14),
    RightLowerArm = A(94, 0, 0),
    RightHand = A(-45, -4, 17),
}

const KnifeBob: Clips.Poses = {
    RightUpperArm = A(-15, 20, -15),
    RightLowerArm = A(105, 0, 0),
    RightHand = A(-46, -1, 19),
}

const KnifeCock: Clips.Poses = {
    UpperTorso = A(0, -20, 0),
    RightUpperArm = A(55, 26, 84),
    RightLowerArm = A(80, 0, 0),
    RightHand = A(-94, 0, 86),
}

const KnifeRelease: Clips.Poses = {
    UpperTorso = A(-5, 15, 0),
    RightUpperArm = A(22, 38, 54),
    RightLowerArm = A(108, 0, 0),
    RightHand = A(-131, -51, -49),
}

const KnifeFollow: Clips.Poses = {
    UpperTorso = A(-8, 25, 0),
    RightUpperArm = A(9, 24, -52),
    RightLowerArm = A(128, 0, 0),
    RightHand = A(-43, -42, 37),
}

const KnifeSlashWind: Clips.Poses = {
    UpperTorso = A(0, -25, 0),
    RightUpperArm = A(52, 0, -37),
    RightLowerArm = A(125, 0, 0),
    RightHand = A(-8, -11, -23),
}

const KnifeSlashHit: Clips.Poses = {
    UpperTorso = A(-5, 30, 0),
    RightUpperArm = A(26, 1, -60),
    RightLowerArm = A(82, 0, 0),
    RightHand = A(-18, -28, 14),
}

const CleaverHold: Clips.Poses = {
    RightUpperArm = A(-17, 13, -11),
    RightLowerArm = A(93, 0, 0),
    RightHand = A(-43, -4, 11),
}

const CleaverBob: Clips.Poses = {
    RightUpperArm = A(-23, 15, -11),
    RightLowerArm = A(102, 0, 0),
    RightHand = A(-43, -1, 13),
}

const CleaverWindup: Clips.Poses = {
    UpperTorso = A(8, -35, 0),
    RightUpperArm = A(66, 34, 63),
    RightLowerArm = A(70, 0, 0),
    RightHand = A(-96, 1, 84),
}

const CleaverRelease: Clips.Poses = {
    UpperTorso = A(-8, 15, 0),
    RightUpperArm = A(166, 19, -26),
    RightHand = A(-87, -30, -5),
}

const CleaverChopHit: Clips.Poses = {
    UpperTorso = A(-12, 10, 0),
    RightUpperArm = A(32, 46, -7),
    RightLowerArm = A(83, 0, 0),
    RightHand = A(-87, -56, 3),
}

const CleaverFollow: Clips.Poses = {
    UpperTorso = A(-14, 30, 0),
    RightUpperArm = A(3, 28, -67),
    RightLowerArm = A(130, 0, 0),
    RightHand = A(-34, -18, 34),
}

const KnifeCockOne: Clips.Poses = {
    RightUpperArm = A(56, 0, 111),
    RightLowerArm = A(104, 0, 0),
    RightHand = A(-105, 4, 75),
}

const KnifeReleaseOne: Clips.Poses = {
    RightUpperArm = A(66, 37, 0),
    RightLowerArm = A(75, 0, 0),
    RightHand = A(-100, -34, -18),
}

const KnifeFollowOne: Clips.Poses = {
    RightUpperArm = A(17, 23, -22),
    RightLowerArm = A(98, 0, 0),
    RightHand = A(-50, -4, 29),
}

const KnifeSlashWindOne: Clips.Poses = {
    RightUpperArm = A(71, -16, -5),
    RightLowerArm = A(139, 0, 0),
    RightHand = A(-36, -17, -19),
}

const KnifeSlashHitOne: Clips.Poses = {
    RightUpperArm = A(41, -6, -52),
    RightLowerArm = A(51, 0, 0),
    RightHand = A(-40, -42, -11),
}

const CleaverWindupOne: Clips.Poses = {
    RightUpperArm = A(78, 5, 111),
    RightLowerArm = A(98, 0, 0),
    RightHand = A(-108, 19, 72),
}

const CleaverReleaseOne: Clips.Poses = {
    RightUpperArm = A(142, 11, -20),
    RightHand = A(-69, -23, -6),
}

const CleaverFollowOne: Clips.Poses = {
    RightUpperArm = A(14, 21, -18),
    RightLowerArm = A(89, 0, 0),
    RightHand = A(-59, -14, 22),
}

const CleaverChopHitOne: Clips.Poses = {
    RightUpperArm = A(67, 8, -23),
    RightLowerArm = A(3, 0, 0),
    RightHand = A(-56, -24, 4),
}

const Cubic = Enum.PoseEasingStyle.Cubic
const Out = Enum.PoseEasingDirection.Out
const Linear = Enum.PoseEasingStyle.Linear

const function held(Hold: Clips.Poses, Bob: Clips.Poses): { [string]: Clips.Spec }
    return {
        Hold = { Name = "Hold", Loop = true, Priority = Enum.AnimationPriority.Idle, Frames = {
            { Time = 0, Poses = Hold },
            { Time = 1, Poses = Hold },
        } },
        HoldWalk = { Name = "HoldWalk", Loop = true, Priority = Enum.AnimationPriority.Movement, Frames = {
            { Time = 0, Poses = Hold },
            { Time = 0.4, Poses = Bob },
            { Time = 0.8, Poses = Hold },
        } },
        Equip = { Name = "Equip", Priority = Enum.AnimationPriority.Action, Frames = {
            { Time = 0, Poses = Down },
            { Time = 0.25, Poses = Hold, Style = Cubic, Direction = Out },
        } },
        PutAway = { Name = "PutAway", Priority = Enum.AnimationPriority.Action, Frames = {
            { Time = 0, Poses = Hold },
            { Time = 0.25, Poses = Down },
        } },
    }
end

const function actions(): { any }
    return {
        { Id = "Throw", Label = "throw", Key = Enum.KeyCode.T },
        { Id = "Retrieve", Label = "retrieve", Key = Enum.KeyCode.R },
    }
end

const KnifeClips = held(KnifeHold, KnifeBob)
KnifeClips.Throw = { Name = "Throw", Priority = Enum.AnimationPriority.Action, Frames = {
    { Time = 0, Poses = KnifeHold },
    { Time = 0.12, Poses = KnifeCock, Style = Cubic, Direction = Out },
    { Time = 0.2, Poses = KnifeRelease, Style = Linear },
    { Time = 0.34, Poses = KnifeFollow, Style = Cubic, Direction = Out },
    { Time = 0.5, Poses = KnifeFollow },
} }
KnifeClips.Throw_OneHand = { Name = "Throw_OneHand", Priority = Enum.AnimationPriority.Action, Frames = {
    { Time = 0, Poses = KnifeHold },
    { Time = 0.12, Poses = KnifeCockOne, Style = Cubic, Direction = Out },
    { Time = 0.2, Poses = KnifeReleaseOne, Style = Linear },
    { Time = 0.34, Poses = KnifeFollowOne, Style = Cubic, Direction = Out },
    { Time = 0.5, Poses = KnifeFollowOne },
} }
KnifeClips.Swing = { Name = "Swing", Priority = Enum.AnimationPriority.Action, Frames = {
    { Time = 0, Poses = KnifeHold },
    { Time = 0.12, Poses = KnifeSlashWind, Style = Cubic, Direction = Out },
    { Time = 0.16, Poses = KnifeSlashWind },
    { Time = 0.26, Poses = KnifeSlashHit, Style = Linear },
    { Time = 0.34, Poses = KnifeSlashHit },
    { Time = 0.55, Poses = KnifeHold, Style = Cubic, Direction = Out },
} }
KnifeClips.Swing_OneHand = { Name = "Swing_OneHand", Priority = Enum.AnimationPriority.Action, Frames = {
    { Time = 0, Poses = KnifeHold },
    { Time = 0.12, Poses = KnifeSlashWindOne, Style = Cubic, Direction = Out },
    { Time = 0.16, Poses = KnifeSlashWindOne },
    { Time = 0.26, Poses = KnifeSlashHitOne, Style = Linear },
    { Time = 0.34, Poses = KnifeSlashHitOne },
    { Time = 0.55, Poses = KnifeHold, Style = Cubic, Direction = Out },
} }

const CleaverClips = held(CleaverHold, CleaverBob)
CleaverClips.Throw = { Name = "Throw", Priority = Enum.AnimationPriority.Action, Frames = {
    { Time = 0, Poses = CleaverHold },
    { Time = 0.2, Poses = CleaverWindup, Style = Cubic, Direction = Out },
    { Time = 0.27, Poses = CleaverWindup },
    { Time = 0.36, Poses = CleaverRelease, Style = Linear },
    { Time = 0.52, Poses = CleaverFollow, Style = Cubic, Direction = Out },
    { Time = 0.7, Poses = CleaverFollow },
} }
CleaverClips.Throw_OneHand = { Name = "Throw_OneHand", Priority = Enum.AnimationPriority.Action, Frames = {
    { Time = 0, Poses = CleaverHold },
    { Time = 0.2, Poses = CleaverWindupOne, Style = Cubic, Direction = Out },
    { Time = 0.27, Poses = CleaverWindupOne },
    { Time = 0.36, Poses = CleaverReleaseOne, Style = Linear },
    { Time = 0.52, Poses = CleaverFollowOne, Style = Cubic, Direction = Out },
    { Time = 0.7, Poses = CleaverFollowOne },
} }
CleaverClips.Swing = { Name = "Swing", Priority = Enum.AnimationPriority.Action, Frames = {
    { Time = 0, Poses = CleaverHold },
    { Time = 0.18, Poses = CleaverWindup, Style = Cubic, Direction = Out },
    { Time = 0.24, Poses = CleaverWindup },
    { Time = 0.36, Poses = CleaverChopHit, Style = Linear },
    { Time = 0.46, Poses = CleaverChopHit },
    { Time = 0.72, Poses = CleaverHold, Style = Cubic, Direction = Out },
} }
CleaverClips.Swing_OneHand = { Name = "Swing_OneHand", Priority = Enum.AnimationPriority.Action, Frames = {
    { Time = 0, Poses = CleaverHold },
    { Time = 0.18, Poses = CleaverWindupOne, Style = Cubic, Direction = Out },
    { Time = 0.24, Poses = CleaverWindupOne },
    { Time = 0.36, Poses = CleaverChopHitOne, Style = Linear },
    { Time = 0.46, Poses = CleaverChopHitOne },
    { Time = 0.72, Poses = CleaverHold, Style = Cubic, Direction = Out },
} }

const Items = {
    Knife = {
        Name = "Throwing Knife",
        Category = "Throwing",
        Order = 1,
        Description = "a light knife you slash with, or throw straight so it sticks where it lands",
        OneHand = true,
        Clips = KnifeClips,
        Sets = {
            Held = { Body = { Idle = "Hold", Walk = "HoldWalk" } },
        },
        Equip = "Equip",
        Unequip = "PutAway",
        Stats = {
            Throw = "Toss",
            ThrowSpeed = 110,
            ThrowRange = 90,
            ReleaseTime = 0.19,
            SwingTime = 0.55,
            ThrowCooldown = 0.4,
            Embed = 0.3,
            StickSquare = 0.25,
        },
        Dual = { Tags = { "Throwing", "Melee" }, With = { "Throwing", "Shield" } },
        Actions = actions(),
        client = Throwables.client(),
    },

    Cleaver = {
        Name = "Cleaver",
        Category = "Throwing",
        Order = 2,
        Description = "a heavy cleaver you chop with, or lob in a spinning arc",
        OneHand = true,
        Clips = CleaverClips,
        Sets = {
            Held = { Body = { Idle = "Hold", Walk = "HoldWalk" } },
        },
        Equip = "Equip",
        Unequip = "PutAway",
        Stats = {
            Throw = "Arc",
            ThrowSpeed = 45,
            ThrowRange = 60,
            ReleaseTime = 0.34,
            SwingTime = 0.72,
            ThrowCooldown = 0.6,
            Embed = 0.18,
            StickSquare = 0.9,
        },
        Dual = { Tags = { "Throwing", "Melee" }, With = { "Throwing", "Shield" } },
        Actions = actions(),
        client = Throwables.client(),
    },
}

return Items
