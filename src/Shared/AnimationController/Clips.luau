--!strict
export type Poses = { [string]: CFrame }

export type Frame = {
    Time: number,
    Poses: Poses,
    Style: Enum.PoseEasingStyle?,
    Direction: Enum.PoseEasingDirection?,
}

export type Spec = {
    Name: string,
    Loop: boolean?,
    Priority: Enum.AnimationPriority?,
    Frames: { Frame },
}

const Clips = {
    Parents = {
        LowerTorso = "HumanoidRootPart",
        UpperTorso = "LowerTorso",
        Head = "UpperTorso",
        LeftUpperArm = "UpperTorso",
        LeftLowerArm = "LeftUpperArm",
        LeftHand = "LeftLowerArm",
        RightUpperArm = "UpperTorso",
        RightLowerArm = "RightUpperArm",
        RightHand = "RightLowerArm",
        LeftUpperLeg = "LowerTorso",
        LeftLowerLeg = "LeftUpperLeg",
        LeftFoot = "LeftLowerLeg",
        RightUpperLeg = "LowerTorso",
        RightLowerLeg = "RightUpperLeg",
        RightFoot = "RightLowerLeg",
    } :: { [string]: string },
    Legs = { "LowerTorso", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" },
    Body = { "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" },
}

const function depthOf(Joint: string): number
    local Depth = 0
    local Current = Clips.Parents[Joint]
    while Current do
        Depth += 1
        Current = Clips.Parents[Current]
    end
    return Depth
end

function Clips.angles(X: number, Y: number?, Z: number?): CFrame
    return CFrame.Angles(math.rad(X), math.rad(Y or 0), math.rad(Z or 0))
end

function Clips.offset(Position: Vector3, X: number?, Y: number?, Z: number?): CFrame
    return CFrame.new(Position) * Clips.angles(X or 0, Y, Z)
end

function Clips.mirror(Poses: Poses): Poses
    const Made: Poses = {}
    for Joint, Frame in Poses do
        const Swapped = if string.sub(Joint, 1, 4) == "Left"
            then `Right{string.sub(Joint, 5)}`
            elseif string.sub(Joint, 1, 5) == "Right" then `Left{string.sub(Joint, 6)}`
            else Joint
        Made[Swapped] = Frame
    end
    return Made
end

function Clips.merge(...: Poses): Poses
    const Made: Poses = {}
    for _, Poses in { ... } do
        for Joint, Frame in Poses do
            Made[Joint] = Frame
        end
    end
    return Made
end

function Clips.sequence(Spec: Spec): KeyframeSequence
    const Sequence = Instance.new("KeyframeSequence")
    Sequence.Name = Spec.Name
    Sequence.Loop = Spec.Loop == true
    Sequence.Priority = Spec.Priority or Enum.AnimationPriority.Action

    const Used: { [string]: boolean } = {}
    for _, Frame in Spec.Frames do
        for Joint in Frame.Poses do
            Used[Joint] = true
        end
    end
    const Needed: { [string]: boolean } = {}
    for Joint in Used do
        local Current: string? = Joint
        while Current do
            Needed[Current] = true
            Current = Clips.Parents[Current]
        end
    end
    const Order: { string } = {}
    for Joint in Needed do
        table.insert(Order, Joint)
    end
    table.sort(Order, function(A: string, B: string): boolean
        return depthOf(A) < depthOf(B)
    end)

    for _, Frame in Spec.Frames do
        const Key = Instance.new("Keyframe")
        Key.Time = Frame.Time
        const Made: { [string]: Pose } = {}
        for _, Joint in Order do
            const Pose = Instance.new("Pose")
            Pose.Name = Joint
            Pose.CFrame = Frame.Poses[Joint] or CFrame.identity
            Pose.Weight = if Used[Joint] then 1 else 0
            Pose.EasingStyle = Frame.Style or Enum.PoseEasingStyle.Cubic
            Pose.EasingDirection = Frame.Direction or Enum.PoseEasingDirection.InOut
            const Parent = Clips.Parents[Joint]
            Pose.Parent = if Parent then Made[Parent] else Key
            Made[Joint] = Pose
        end
        Key.Parent = Sequence
    end
    return Sequence
end

return Clips
