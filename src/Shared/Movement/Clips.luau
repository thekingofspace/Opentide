--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Clips = require(ReplicatedStorage.Shared.AnimationController.Clips)

const A = Clips.angles

const function stride(Front: string, Back: string, Lean: number): Clips.Poses
    return {
        LowerTorso = A(Lean, 0, 0),
        [`{Front}UpperLeg`] = A(45, 0, 0),
        [`{Front}LowerLeg`] = A(-25, 0, 0),
        [`{Back}UpperLeg`] = A(-35, 0, 0),
        [`{Back}LowerLeg`] = A(-75, 0, 0),
    }
end

const function swing(Front: string, Back: string): Clips.Poses
    return {
        UpperTorso = A(-6, 0, 0),
        [`{Front}UpperArm`] = A(55, 0, 0),
        [`{Front}LowerArm`] = A(70, 0, 0),
        [`{Back}UpperArm`] = A(-45, 0, 0),
        [`{Back}LowerArm`] = A(55, 0, 0),
    }
end

const Low = CFrame.new(0, -1.35, 0) * A(-78, 0, 0)

const function crawl(Reach: number, Knee: number): Clips.Poses
    return {
        LowerTorso = Low,
        Head = A(62, 0, 0),
        RightUpperArm = A(75 + Reach, 0, 0),
        RightLowerArm = A(10, 0, 0),
        LeftUpperArm = A(75 - Reach, 0, 0),
        LeftLowerArm = A(10, 0, 0),
        RightUpperLeg = A(78 - Knee, 0, 0),
        RightLowerLeg = A(-95, 0, 0),
        LeftUpperLeg = A(78 + Knee, 0, 0),
        LeftLowerLeg = A(-95, 0, 0),
    }
end

const Specs: { [string]: Clips.Spec } = {
    Run_Legs = { Name = "Run_Legs", Loop = true, Priority = Enum.AnimationPriority.Movement, Frames = {
        { Time = 0, Poses = stride("Right", "Left", -6) },
        { Time = 0.3, Poses = stride("Left", "Right", -6) },
        { Time = 0.6, Poses = stride("Right", "Left", -6) },
    } },
    Run_Body = { Name = "Run_Body", Loop = true, Priority = Enum.AnimationPriority.Movement, Frames = {
        { Time = 0, Poses = swing("Left", "Right") },
        { Time = 0.3, Poses = swing("Right", "Left") },
        { Time = 0.6, Poses = swing("Left", "Right") },
    } },
    CrawlIdle = { Name = "CrawlIdle", Loop = true, Priority = Enum.AnimationPriority.Movement, Frames = {
        { Time = 0, Poses = crawl(0, 0) },
        { Time = 1, Poses = crawl(0, 0) },
    } },
    Crawl = { Name = "Crawl", Loop = true, Priority = Enum.AnimationPriority.Movement, Frames = {
        { Time = 0, Poses = crawl(18, 14) },
        { Time = 0.5, Poses = crawl(-18, -14) },
        { Time = 1, Poses = crawl(18, 14) },
    } },
}

return Specs
