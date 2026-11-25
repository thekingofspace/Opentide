--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const UserInputService = game:GetService("UserInputService")

const LocalAnimations = require(script.Parent.LocalAnimations)
const Customize = require(ReplicatedStorage.Shared.Customize)

const AnimationTest = {
    CrouchKey = Enum.KeyCode.KeypadZero,
    PointKey = Enum.KeyCode.KeypadOne,
}

local Started = false

function AnimationTest.start()
    if Started then
        return
    end
    Started = true
    LocalAnimations.start()

    UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
        if Processed or Customize.active() then
            return
        end
        const Key = Input.KeyCode
        if Key == AnimationTest.CrouchKey then
            if LocalAnimations.hasSet("Crouch") then
                LocalAnimations.popSet("Crouch")
            else
                LocalAnimations.pushSet("Crouch")
            end
        elseif Key == AnimationTest.PointKey then
            LocalAnimations.emote("Point")
        end
    end)
end

return AnimationTest
