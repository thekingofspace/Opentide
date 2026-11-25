--!strict
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")

const AnimationController = require(script.Parent)
const Library = require(script.Parent.Library)
const Defaults = require(script.Parent.Defaults)

const LocalAnimations = {
    EmoteSlot = "Emote",
    MoveThreshold = 0.05,
}

local Controller: AnimationController.Controller? = nil
local Emoting: string? = nil
local Watch: RBXScriptConnection? = nil

const function slots(Refs: { [string]: Defaults.SlotRef }?): { [string]: AnimationController.Slot }?
    if not Refs then
        return nil
    end
    const Made: { [string]: AnimationController.Slot } = {}
    for Mode, Ref in Refs do
        const Spec = Library.spec(Ref.Name, Ref.ReferenceSpeed)
        if Spec then
            Made[Mode] = Spec
        end
    end
    return Made
end

const function setOf(Ref: Defaults.SetRef): AnimationController.SlotTable
    return {
        Full = slots(Ref.Full),
        Legs = slots(Ref.Legs),
        Body = slots(Ref.Body),
    }
end

function LocalAnimations.start(): AnimationController.Controller
    const Existing = Controller
    if Existing then
        return Existing
    end
    const Made = AnimationController.new(Players.LocalPlayer, {
        Defaults = if Defaults.UseRobloxAnimations then nil else false,
    })
    Controller = Made
    const Base = setOf(Defaults.Slots)
    for _, Part in { "Full", "Legs", "Body" } :: { AnimationController.Part } do
        const Table = if Part == "Full" then Base.Full elseif Part == "Legs" then Base.Legs else Base.Body
        for Mode, Spec in Table or {} do
            Made:setSlot(Part, Mode, Spec)
        end
    end
    return Made
end

function LocalAnimations.get(): AnimationController.Controller?
    return Controller
end

function LocalAnimations.pushSet(Name: string): boolean
    const Made = Controller
    const Ref = Defaults.Sets[Name]
    if not Made or not Ref then
        return false
    end
    Made:pushSet(Name, setOf(Ref))
    return true
end

function LocalAnimations.popSet(Name: string)
    const Made = Controller
    if Made then
        Made:popSet(Name)
    end
end

function LocalAnimations.hasSet(Name: string): boolean
    const Made = Controller
    return Made ~= nil and Made:hasSet(Name)
end

function LocalAnimations.play(Name: string): AnimationTrack?
    const Made = Controller
    const Ref = Defaults.Actions[Name]
    const Clip = if Ref then Library.get(Ref.Name) else nil
    if not Made or not Ref or not Clip then
        return nil
    end
    return Made:play(Name, Clip, { Part = Ref.Part or "Full" })
end

const function humanoid(): Humanoid?
    const Character = Players.LocalPlayer.Character
    return if Character then Character:FindFirstChildOfClass("Humanoid") else nil
end

const function moving(): boolean
    const Found = humanoid()
    if not Found then
        return false
    end
    const State = Found:GetState()
    return Found.MoveDirection.Magnitude > LocalAnimations.MoveThreshold
        or State == Enum.HumanoidStateType.Jumping
        or State == Enum.HumanoidStateType.Freefall
end

function LocalAnimations.stopEmote()
    Emoting = nil
    const Link = Watch
    Watch = nil
    if Link then
        Link:Disconnect()
    end
    const Made = Controller
    if Made then
        Made:stop(LocalAnimations.EmoteSlot)
    end
end

function LocalAnimations.emoting(): string?
    return Emoting
end

function LocalAnimations.emote(Name: string): AnimationTrack?
    const Made = Controller
    const Ref = Defaults.Emotes[Name]
    if not Made or not Ref or moving() then
        return nil
    end
    const Use = if Ref.Crouch and Made:hasSet("Crouch") then Ref.Crouch else Ref.Name
    const Clip = Library.get(Use)
    if not Clip then
        return nil
    end
    LocalAnimations.stopEmote()
    const Track = Made:play(LocalAnimations.EmoteSlot, Clip, {
        Part = Ref.Part or "Full",
        Looped = Ref.Looped,
    })
    if not Track then
        return nil
    end
    Emoting = Name
    Watch = RunService.Heartbeat:Connect(function()
        if moving() or not Made:isPlaying(LocalAnimations.EmoteSlot) then
            LocalAnimations.stopEmote()
        end
    end)
    return Track
end

function LocalAnimations.stop(Name: string)
    const Made = Controller
    if Made then
        Made:stop(Name)
    end
end

return LocalAnimations
