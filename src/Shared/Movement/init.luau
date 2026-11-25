--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const UserInputService = game:GetService("UserInputService")

const signal = require(ReplicatedStorage.MainPackages.signal)
const AnimationController = require(ReplicatedStorage.Shared.AnimationController)
const Clips = require(ReplicatedStorage.Shared.AnimationController.Clips)
const Library = require(ReplicatedStorage.Shared.AnimationController.Library)
const LocalAnimations = require(ReplicatedStorage.Shared.AnimationController.LocalAnimations)
const ToolsClient = require(ReplicatedStorage.Shared.Tools.Client)
const Specs = require(script.Clips)

export type Stance = "Stand" | "Crouch" | "Crawl"

const Movement = {
    WalkSpeed = 16,
    RunSpeed = 26,
    CrouchSpeed = 8,
    CrawlSpeed = 5,
    RunKey = Enum.KeyCode.LeftShift,
    CrouchKey = Enum.KeyCode.C,
    CrawlKey = Enum.KeyCode.X,
    RunPriority = 5,
    CrouchPriority = 5,
    CrawlPriority = 6,
    JumpPause = 0.25,
    Changed = signal.new(),
}

const Built: { [string]: KeyframeSequence } = {}
local Stance: Stance = "Stand"
local RunToggle = false
local RunHeld = false
local Blocked = false
local Started = false

const function clip(Name: string): AnimationController.Clip?
    const Known = Library.get(Name)
    if Known ~= nil then
        return Known
    end
    const Spec = Specs[Name]
    if not Spec then
        return nil
    end
    const Made = Built[Name] or Clips.sequence(Spec)
    Built[Name] = Made
    return Made
end

const function humanoid(): Humanoid?
    const Character = Players.LocalPlayer.Character
    return if Character then Character:FindFirstChildOfClass("Humanoid") else nil
end

const function controller(): AnimationController.Controller
    return LocalAnimations.get() or LocalAnimations.start()
end

function Movement.running(): boolean
    return (RunToggle or RunHeld) and Stance == "Stand"
end

function Movement.stance(): Stance
    return Stance
end

const function apply()
    const Animations = controller()
    if Movement.running() then
        Animations:pushSet("Move_Run", {
            Legs = { Walk = { Clip = clip("Run_Legs") :: any, ReferenceSpeed = Movement.RunSpeed } },
            Body = { Walk = { Clip = clip("Run_Body") :: any, ReferenceSpeed = Movement.RunSpeed } },
        }, Movement.RunPriority)
    else
        Animations:popSet("Move_Run")
    end
    if Stance == "Crouch" then
        if not LocalAnimations.hasSet("Crouch") then
            LocalAnimations.pushSet("Crouch")
        end
    elseif LocalAnimations.hasSet("Crouch") then
        LocalAnimations.popSet("Crouch")
    end
    if Stance == "Crawl" then
        Animations:pushSet("Move_Crawl", {
            Full = { Idle = clip("CrawlIdle") :: any, Walk = { Clip = clip("Crawl") :: any, ReferenceSpeed = Movement.CrawlSpeed } },
            Legs = { Idle = false, Walk = false },
            Body = { Idle = false, Walk = false },
        }, Movement.CrawlPriority)
    else
        Animations:popSet("Move_Crawl")
    end
    const Found = humanoid()
    if Found then
        Found.WalkSpeed = if Stance == "Crawl" then Movement.CrawlSpeed
            elseif Stance == "Crouch" then Movement.CrouchSpeed
            elseif Movement.running() then Movement.RunSpeed
            else Movement.WalkSpeed
        Found:SetStateEnabled(Enum.HumanoidStateType.Jumping, Stance == "Stand")
    end
    Movement.Changed:Fire()
end

function Movement.setStance(Next: Stance): boolean
    if Next == "Crawl" and not ToolsClient.allows("AllowCrawl") then
        return false
    end
    if Next ~= "Stand" then
        RunToggle = false
        RunHeld = false
    end
    Stance = Next
    apply()
    return true
end

function Movement.toggleCrouch()
    Movement.setStance(if Stance == "Crouch" then "Stand" else "Crouch")
end

function Movement.toggleCrawl(): boolean
    return Movement.setStance(if Stance == "Crawl" then "Stand" else "Crawl")
end

function Movement.setBlocked(Value: boolean)
    Blocked = Value
    if Value and RunHeld then
        RunHeld = false
        apply()
    end
end

function Movement.setRun(Value: boolean)
    RunToggle = Value
    if Value and Stance ~= "Stand" then
        Stance = "Stand"
    end
    apply()
end

function Movement.toggleRun()
    Movement.setRun(not RunToggle)
end

function Movement.runToggled(): boolean
    return RunToggle
end

function Movement.start()
    if Started then
        return
    end
    Started = true
    UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
        if Processed or Blocked then
            return
        end
        if Input.KeyCode == Movement.RunKey then
            RunHeld = true
            if Stance ~= "Stand" then
                Stance = "Stand"
            end
            apply()
        elseif Input.KeyCode == Movement.CrouchKey then
            Movement.toggleCrouch()
        elseif Input.KeyCode == Movement.CrawlKey then
            Movement.toggleCrawl()
        end
    end)
    UserInputService.InputEnded:Connect(function(Input: InputObject)
        if Input.KeyCode == Movement.RunKey and RunHeld then
            RunHeld = false
            apply()
        end
    end)
    UserInputService.JumpRequest:Connect(function()
        if Stance == "Stand" then
            return
        end
        Stance = "Stand"
        const Found = humanoid()
        if Found then
            Found.Jump = false
        end
        apply()
        if Found then
            Found:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
            task.delay(Movement.JumpPause, function()
                if Stance == "Stand" then
                    Found:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
                end
            end)
        end
    end)
    ToolsClient.Equipped:Connect(function(ToolId: string?)
        if ToolId and Stance == "Crawl" and not ToolsClient.allows("AllowCrawl") then
            Movement.setStance("Stand")
        end
    end)
    Players.LocalPlayer.CharacterAdded:Connect(function(Character: Model)
        Stance = "Stand"
        RunHeld = false
        Character:WaitForChild("Humanoid", 10)
        apply()
    end)
    apply()
end

return Movement
