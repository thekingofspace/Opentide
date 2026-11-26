--!strict
const KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

const signal = require(ReplicatedStorage.MainPackages.signal)

export type Part = "Full" | "Legs" | "Body" | "Right" | "Left"
export type Target = Part
export type Clip = string | number | Animation | KeyframeSequence

export type SlotSpec = {
    Clip: Clip,
    Speed: number?,
    ReferenceSpeed: number?,
    FadeTime: number?,
    Priority: Enum.AnimationPriority?,
}

export type Slot = Clip | SlotSpec | false

export type SlotTable = {
    Full: { [string]: Slot }?,
    Legs: { [string]: Slot }?,
    Body: { [string]: Slot }?,
    Right: { [string]: Slot }?,
    Left: { [string]: Slot }?,
}

export type Options = {
    KeepAnimate: boolean?,
    Exclusive: boolean?,
    Defaults: ({ [string]: Slot } | false)?,
}

export type ActionOptions = {
    Part: Target?,
    Priority: Enum.AnimationPriority?,
    Speed: number?,
    Weight: number?,
    FadeTime: number?,
    Looped: boolean?,
}

type Layer = {
    Spec: SlotSpec?,
    Track: AnimationTrack?,
    Suppressed: number,
    Speed: number,
}

type Action = {
    Track: AnimationTrack,
    Parts: { Part },
    Link: RBXScriptConnection,
}

type Set = {
    Name: string,
    Slots: SlotTable,
    Priority: number,
    Order: number,
}

type Fields = {
    Player: Player?,
    Character: Model?,
    Humanoid: Humanoid?,
    Root: BasePart?,
    Animator: Animator?,
    Mode: string,
    Base: { [Part]: { [string]: Slot } },
    Sets: { Set },
    Layers: { [Part]: Layer },
    Actions: { [string]: Action },
    Tracks: { [Animation]: AnimationTrack },
    ActionTracks: { [Animation]: AnimationTrack },
    Links: { RBXScriptConnection },
    CharacterLinks: { RBXScriptConnection },
    ModeChanged: signal.Signal<...any>,
    Binding: number,
    KeepAnimate: boolean,
    Exclusive: boolean,
    Guard: number,
    Destroyed: boolean,
}

const Controller = {}
Controller.__index = Controller

export type Controller = typeof(setmetatable({} :: Fields, Controller))

const AnimationController = {
    Parts = { "Full", "Legs", "Body", "Right", "Left" } :: { Part },
    LayerPriority = {
        Full = Enum.AnimationPriority.Movement,
        Legs = Enum.AnimationPriority.Action,
        Body = Enum.AnimationPriority.Action,
        Right = Enum.AnimationPriority.Action2,
        Left = Enum.AnimationPriority.Action2,
    } :: { [Part]: Enum.AnimationPriority },
    PartPriority = Enum.AnimationPriority.Action2,
    FullPriority = Enum.AnimationPriority.Action3,
    FadeTime = 0.2,
    MutedWeight = 1e-3,
    MoveThreshold = 0.05,
    GuardInterval = 0.25,
    Defaults = {
        Idle = "rbxassetid://507766666",
        Walk = { Clip = "rbxassetid://913376220", ReferenceSpeed = 16 },
        Jump = "rbxassetid://507765000",
        Fall = "rbxassetid://507767968",
        Climb = "rbxassetid://507765644",
        Swim = "rbxassetid://913384386",
        SwimIdle = "rbxassetid://913389285",
        Seated = "rbxassetid://2506281703",
    } :: { [string]: Slot },
}

const NamedStates: { [Enum.HumanoidStateType]: string } = {
    [Enum.HumanoidStateType.Jumping] = "Jump",
    [Enum.HumanoidStateType.Freefall] = "Fall",
    [Enum.HumanoidStateType.FallingDown] = "Fall",
    [Enum.HumanoidStateType.Ragdoll] = "Fall",
    [Enum.HumanoidStateType.Climbing] = "Climb",
    [Enum.HumanoidStateType.Seated] = "Seated",
    [Enum.HumanoidStateType.Dead] = "Dead",
}

const Animations: { [string]: Animation } = {}
const Registered: { [KeyframeSequence]: Animation } = {}

const function animationFor(Id: string): Animation
    const Known = Animations[Id]
    if Known then
        return Known
    end
    const Made = Instance.new("Animation")
    Made.AnimationId = Id
    Animations[Id] = Made
    return Made
end

function AnimationController.animation(Clip: Clip): Animation?
    if type(Clip) == "number" then
        return animationFor(`rbxassetid://{Clip}`)
    elseif type(Clip) == "string" then
        return animationFor(if string.match(Clip, "^%d+$") then `rbxassetid://{Clip}` else Clip)
    elseif typeof(Clip) == "Instance" then
        if Clip:IsA("Animation") then
            return Clip
        elseif Clip:IsA("KeyframeSequence") then
            const Known = Registered[Clip]
            if Known then
                return Known
            end
            const Ok, Id = pcall(KeyframeSequenceProvider.RegisterKeyframeSequence, KeyframeSequenceProvider, Clip)
            if not Ok then
                warn(`[AnimationController] could not register "{Clip.Name}": {Id}`)
                return nil
            end
            const Made = Instance.new("Animation")
            Made.Name = Clip.Name
            Made.AnimationId = Id
            Registered[Clip] = Made
            return Made
        end
    end
    return nil
end

const function normalize(Value: Slot?): SlotSpec?
    if Value == nil or Value == false then
        return nil
    end
    if type(Value) == "table" and (Value :: any).Clip ~= nil then
        return Value :: SlotSpec
    end
    return { Clip = Value :: Clip }
end

const function partsOf(Target: Target): { Part }
    if Target == "Full" then
        return { "Full", "Legs", "Body", "Right", "Left" }
    end
    return { Target }
end

const function trackOf(Self: Controller, Cache: { [Animation]: AnimationTrack }, Clip: Clip): AnimationTrack?
    const Animator = Self.Animator
    const Animation = AnimationController.animation(Clip)
    if not Animator or not Animation then
        return nil
    end
    const Known = Cache[Animation]
    if Known then
        return Known
    end
    const Ok, Track = pcall(Animator.LoadAnimation, Animator, Animation)
    if not Ok then
        warn(`[AnimationController] could not load {Animation.AnimationId}: {Track}`)
        return nil
    end
    Cache[Animation] = Track
    return Track
end

const function slotsOf(Table: SlotTable, Part: Part): { [string]: Slot }?
    if Part == "Full" then
        return Table.Full
    end
    if Part == "Right" then
        return Table.Right
    elseif Part == "Left" then
        return Table.Left
    end
    return if Part == "Legs" then Table.Legs else Table.Body
end

const function resolve(Self: Controller, Part: Part, Mode: string): SlotSpec?
    for Index = #Self.Sets, 1, -1 do
        const Slots = slotsOf(Self.Sets[Index].Slots, Part)
        const Value = if Slots then Slots[Mode] else nil
        if Value == false then
            return nil
        elseif Value ~= nil then
            return normalize(Value)
        end
    end
    return normalize(Self.Base[Part][Mode])
end

const function layerWeight(Layer: Layer): number
    return if Layer.Suppressed > 0 then AnimationController.MutedWeight else 1
end

const function custom(Self: Controller): boolean
    return resolve(Self, "Legs", Self.Mode) ~= nil or resolve(Self, "Body", Self.Mode) ~= nil
end

const function apply(Self: Controller, Part: Part)
    const Layer = Self.Layers[Part]
    const Spec = if Part == "Full" and custom(Self) then nil else resolve(Self, Part, Self.Mode)
    const Old = Layer.Spec
    if Old and Spec and Old.Clip == Spec.Clip and Layer.Track and Layer.Track.IsPlaying then
        Layer.Spec = Spec
        return
    end
    const Fade = if Spec and Spec.FadeTime then Spec.FadeTime else AnimationController.FadeTime
    const Previous = Layer.Track
    Layer.Spec = Spec
    Layer.Track = nil
    Layer.Speed = 1
    if Previous then
        Previous:Stop(Fade)
    end
    if not Spec then
        return
    end
    const Track = trackOf(Self, Self.Tracks, Spec.Clip)
    if not Track then
        return
    end
    Track.Priority = Spec.Priority or AnimationController.LayerPriority[Part]
    Track.Looped = true
    Layer.Track = Track
    Layer.Speed = Spec.Speed or 1
    Track:Play(Fade, layerWeight(Layer), Layer.Speed)
end

const function refresh(Self: Controller)
    if Self.Destroyed or not Self.Animator then
        return
    end
    for _, Part in AnimationController.Parts do
        apply(Self, Part)
    end
end

const function modeOf(Humanoid: Humanoid): string
    const State = Humanoid:GetState()
    const Named = NamedStates[State]
    if Named then
        return Named
    end
    const Moving = Humanoid.MoveDirection.Magnitude > AnimationController.MoveThreshold
    if State == Enum.HumanoidStateType.Swimming then
        return if Moving then "Swim" else "SwimIdle"
    end
    return if Moving then "Walk" else "Idle"
end

const function syncSpeed(Self: Controller)
    const Root = Self.Root
    if not Root then
        return
    end
    const Velocity = Root.AssemblyLinearVelocity
    const Horizontal = Vector3.new(Velocity.X, 0, Velocity.Z).Magnitude
    for _, Part in AnimationController.Parts do
        const Layer = Self.Layers[Part]
        const Spec = Layer.Spec
        const Track = Layer.Track
        const Reference = if Spec then Spec.ReferenceSpeed else nil
        if Track and Spec and Reference and Reference > 0 then
            const Speed = math.clamp(Horizontal / Reference, 0.3, 3) * (Spec.Speed or 1)
            if math.abs(Speed - Layer.Speed) > 0.02 then
                Layer.Speed = Speed
                Track:AdjustSpeed(Speed)
            end
        end
    end
end

const function owned(Self: Controller, Track: AnimationTrack): boolean
    for _, Known in Self.Tracks do
        if Known == Track then
            return true
        end
    end
    for _, Known in Self.ActionTracks do
        if Known == Track then
            return true
        end
    end
    return false
end

const function stopForeign(Self: Controller)
    const Animator = Self.Animator
    if not Animator then
        return
    end
    for _, Track in Animator:GetPlayingAnimationTracks() do
        if not owned(Self, Track) then
            Track:Stop(0)
        end
    end
end

const function step(Self: Controller, Delta: number)
    const Humanoid = Self.Humanoid
    if Self.Destroyed or not Humanoid or not Self.Animator then
        return
    end
    if Self.Exclusive then
        Self.Guard += Delta
        if Self.Guard >= AnimationController.GuardInterval then
            Self.Guard = 0
            stopForeign(Self)
        end
    end
    const Mode = modeOf(Humanoid)
    if Mode ~= Self.Mode then
        Self.Mode = Mode
        refresh(Self)
        Self.ModeChanged:Fire(Mode)
    end
    for _, Part in AnimationController.Parts do
        const Track = Self.Layers[Part].Track
        if Track and not Track.IsPlaying then
            apply(Self, Part)
        end
    end
    syncSpeed(Self)
end

const function suppress(Self: Controller, Part: Part, Fade: number)
    const Layer = Self.Layers[Part]
    Layer.Suppressed += 1
    const Track = Layer.Track
    if Layer.Suppressed == 1 and Track then
        Track:AdjustWeight(AnimationController.MutedWeight, Fade)
    end
end

const function release(Self: Controller, Part: Part, Fade: number)
    const Layer = Self.Layers[Part]
    Layer.Suppressed = math.max(Layer.Suppressed - 1, 0)
    const Track = Layer.Track
    if Layer.Suppressed > 0 or not Track then
        return
    end
    if Track.IsPlaying then
        Track:AdjustWeight(1, Fade)
    else
        apply(Self, Part)
    end
end

const function finish(Self: Controller, Name: string, Action: Action)
    if Self.Actions[Name] ~= Action then
        return
    end
    Self.Actions[Name] = nil
    Action.Link:Disconnect()
    for _, Part in Action.Parts do
        release(Self, Part, AnimationController.FadeTime)
    end
end

const function clearCharacter(Self: Controller)
    for Name, Action in Self.Actions do
        Self.Actions[Name] = nil
        Action.Link:Disconnect()
    end
    for _, Link in Self.CharacterLinks do
        Link:Disconnect()
    end
    table.clear(Self.CharacterLinks)
    for _, Part in AnimationController.Parts do
        Self.Layers[Part] = { Spec = nil, Track = nil, Suppressed = 0, Speed = 1 }
    end
    table.clear(Self.Tracks)
    table.clear(Self.ActionTracks)
    Self.Character = nil
    Self.Humanoid = nil
    Self.Root = nil
    Self.Animator = nil
    Self.Mode = "Idle"
end

const function silence(Self: Controller, Character: Model)
    if Self.KeepAnimate then
        return
    end
    const Script = Character:FindFirstChild("Animate")
    if Script and Script:IsA("LocalScript") then
        Script.Enabled = false
        Script:Destroy()
    end
    stopForeign(Self)
end

const function bind(Self: Controller, Character: Model)
    clearCharacter(Self)
    Self.Binding += 1
    const Mine = Self.Binding
    Self.Character = Character
    task.spawn(function()
        const Humanoid = Character:WaitForChild("Humanoid", 10)
        const Root = Character:WaitForChild("HumanoidRootPart", 10)
        if not Humanoid or not Humanoid:IsA("Humanoid") or Self.Binding ~= Mine or Self.Destroyed then
            return
        end
        const Animator = Humanoid:FindFirstChildOfClass("Animator") or Humanoid:WaitForChild("Animator", 10)
        if not Animator or not Animator:IsA("Animator") or Self.Binding ~= Mine or Self.Destroyed then
            return
        end
        Self.Humanoid = Humanoid
        Self.Root = if Root and Root:IsA("BasePart") then Root else nil
        Self.Animator = Animator
        Self.Mode = modeOf(Humanoid)
        silence(Self, Character)
        refresh(Self)
        table.insert(Self.CharacterLinks, Character.ChildAdded:Connect(function(Child: Instance)
            if Child.Name == "Animate" then
                task.defer(silence, Self, Character)
            end
        end))
        table.insert(Self.CharacterLinks, Character.Destroying:Connect(function()
            if Self.Character == Character then
                clearCharacter(Self)
            end
        end))
    end)
end

function AnimationController.new(Target: Player | Model, Given: Options?): Controller
    const Settings: Options = Given or {}
    const Self = setmetatable({
        Player = if typeof(Target) == "Instance" and Target:IsA("Player") then Target else nil,
        Character = nil,
        Humanoid = nil,
        Root = nil,
        Animator = nil,
        Mode = "Idle",
        Base = {
            Full = if Settings.Defaults == false then {} else table.clone(Settings.Defaults or AnimationController.Defaults),
            Legs = {},
            Body = {},
            Right = {},
            Left = {},
        },
        Sets = {},
        Layers = {
            Full = { Spec = nil, Track = nil, Suppressed = 0, Speed = 1 },
            Legs = { Spec = nil, Track = nil, Suppressed = 0, Speed = 1 },
            Body = { Spec = nil, Track = nil, Suppressed = 0, Speed = 1 },
            Right = { Spec = nil, Track = nil, Suppressed = 0, Speed = 1 },
            Left = { Spec = nil, Track = nil, Suppressed = 0, Speed = 1 },
        },
        Actions = {},
        Tracks = {},
        ActionTracks = {},
        Links = {},
        CharacterLinks = {},
        ModeChanged = signal.new(),
        Binding = 0,
        KeepAnimate = Settings.KeepAnimate == true,
        Exclusive = Settings.Exclusive ~= false and Settings.KeepAnimate ~= true,
        Guard = 0,
        Destroyed = false,
    } :: Fields, Controller)

    table.insert(Self.Links, RunService.Heartbeat:Connect(function(Delta: number)
        step(Self, Delta)
    end))

    const Owner = Self.Player
    if Owner then
        table.insert(Self.Links, Owner.CharacterAdded:Connect(function(Character: Model)
            bind(Self, Character)
        end))
        const Current = Owner.Character
        if Current then
            bind(Self, Current)
        end
    elseif typeof(Target) == "Instance" and Target:IsA("Model") then
        bind(Self, Target)
    end
    return Self
end

function AnimationController.forLocalPlayer(Given: Options?): Controller
    return AnimationController.new(Players.LocalPlayer, Given)
end

function Controller.setSlot(Self: Controller, Part: Part, Mode: string, Value: Slot?)
    Self.Base[Part][Mode] = Value
    refresh(Self)
end

function Controller.getSlot(Self: Controller, Part: Part, Mode: string): SlotSpec?
    return resolve(Self, Part, Mode)
end

local SetCounter = 0

function Controller.pushSet(Self: Controller, Name: string, Slots: SlotTable, Priority: number?)
    for Index = #Self.Sets, 1, -1 do
        if Self.Sets[Index].Name == Name then
            table.remove(Self.Sets, Index)
        end
    end
    SetCounter += 1
    table.insert(Self.Sets, { Name = Name, Slots = Slots, Priority = Priority or 0, Order = SetCounter })
    table.sort(Self.Sets, function(A: Set, B: Set): boolean
        if A.Priority ~= B.Priority then
            return A.Priority < B.Priority
        end
        return A.Order < B.Order
    end)
    refresh(Self)
end

function Controller.popSet(Self: Controller, Name: string)
    for Index = #Self.Sets, 1, -1 do
        if Self.Sets[Index].Name == Name then
            table.remove(Self.Sets, Index)
        end
    end
    refresh(Self)
end

function Controller.hasSet(Self: Controller, Name: string): boolean
    for _, Entry in Self.Sets do
        if Entry.Name == Name then
            return true
        end
    end
    return false
end

function Controller.play(Self: Controller, Name: string, Clip: Clip, Options: ActionOptions?): AnimationTrack?
    Self:stop(Name, 0)
    const Given: ActionOptions = Options or {}
    const Target: Target = Given.Part or "Full"
    const Track = trackOf(Self, Self.ActionTracks, Clip)
    if not Track then
        return nil
    end
    const Fade = Given.FadeTime or AnimationController.FadeTime
    Track.Priority = Given.Priority or (if Target == "Full" then AnimationController.FullPriority else AnimationController.PartPriority)
    if Given.Looped ~= nil then
        Track.Looped = Given.Looped
    end
    const Parts = partsOf(Target)
    for _, Part in Parts do
        suppress(Self, Part, Fade)
    end
    local Made: Action? = nil
    const Link = Track.Stopped:Connect(function()
        const Done = Made
        if Done and not Track.IsPlaying then
            finish(Self, Name, Done)
        end
    end)
    const Entry: Action = {
        Track = Track,
        Parts = Parts,
        Link = Link,
    }
    Made = Entry
    Self.Actions[Name] = Entry
    Track:Play(Fade, Given.Weight or 1, Given.Speed or 1)
    return Track
end

function Controller.stop(Self: Controller, Name: string, FadeTime: number?)
    const Action = Self.Actions[Name]
    if not Action then
        return
    end
    const Fade = FadeTime or AnimationController.FadeTime
    finish(Self, Name, Action)
    Action.Track:Stop(Fade)
end

function Controller.isPlaying(Self: Controller, Name: string): boolean
    return Self.Actions[Name] ~= nil
end

function Controller.stopAll(Self: Controller, FadeTime: number?)
    for Name in Self.Actions do
        Self:stop(Name, FadeTime)
    end
end

function Controller.getMode(Self: Controller): string
    return Self.Mode
end

function Controller.refresh(Self: Controller)
    refresh(Self)
end

function Controller.destroy(Self: Controller)
    if Self.Destroyed then
        return
    end
    Self:stopAll(0)
    for _, Part in AnimationController.Parts do
        const Track = Self.Layers[Part].Track
        if Track then
            Track:Stop(0)
        end
    end
    clearCharacter(Self)
    Self.Destroyed = true
    for _, Link in Self.Links do
        Link:Disconnect()
    end
    table.clear(Self.Links)
    table.clear(Self.Sets)
    Self.ModeChanged:Destroy()
end

return AnimationController
