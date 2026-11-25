--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const UserInputService = game:GetService("UserInputService")

const Customize = require(script.Parent)
const Tools = require(ReplicatedStorage.Shared.PropPlacer.Tools)

const CustomizeTest = {
    ToggleKey = Enum.KeyCode.Q,
    GoatMask = 140094373109538,
    TestSlot = 1,
}

const ModeOrder: { Customize.Mode } = { "None", "Translate", "Rotate", "Scale" }
const Materials = { Enum.Material.Neon, Enum.Material.Metal, Enum.Material.ForceField, Enum.Material.SmoothPlastic, Enum.Material.Wood }

local Cursor = 0
local ModeIndex = 1
local AttachIndex = 0
local MaterialIndex = 0
local Started = false

const function say(Text: string)
    print(`[CustomizeTest] {Text}`)
end

const function report(Ok: boolean, Problem: string?, Done: string)
    say(if Ok then Done else `failed: {Problem or "unknown"}`)
end

const function help()
    say("entered. WASD/Space/Ctrl fly, hold right mouse to look, Shift fast, left click selects")
    say("1 next part, 2 mode, 3 goat mask, 4 robot arm, 5 remove, 6 color, 7 material, 8 restore texture")
    say("9 attach to next body part, 0 skin, . visor, * stretch, / reset, + save slot 1, - load slot 1, Enter apply")
end

const function selected(): string?
    const Id = Customize.selected()
    if not Id then
        say("select something first with numpad 1 or a left click")
    end
    return Id
end

const function nextPart()
    const Entries = Customize.listParts()
    if #Entries == 0 then
        return
    end
    Cursor = Cursor % #Entries + 1
    const Entry = Entries[Cursor]
    Customize.select(Entry.Id)
    say(`selected {Entry.Name} ({Entry.Kind}) {Cursor}/{#Entries}`)
end

const function onKey(Key: Enum.KeyCode)
    if Key == Enum.KeyCode.KeypadOne then
        nextPart()
    elseif Key == Enum.KeyCode.KeypadTwo then
        ModeIndex = ModeIndex % #ModeOrder + 1
        Customize.setMode(ModeOrder[ModeIndex])
        say(`mode {ModeOrder[ModeIndex]}`)
    elseif Key == Enum.KeyCode.KeypadThree then
        if Customize.hasAsset(CustomizeTest.GoatMask) then
            say(`removed goat mask x{Customize.removeAsset(CustomizeTest.GoatMask)}`)
        else
            say("loading goat mask...")
            const Id, Problem = Customize.addAsset(CustomizeTest.GoatMask)
            report(Id ~= nil, Problem, `goat mask added as {Id}`)
        end
    elseif Key == Enum.KeyCode.KeypadFour then
        const On = Customize.getSwap("RightArm") ~= nil
        const Ok, Problem = Customize.swap("RightArm", if On then nil else "RobotArm")
        report(Ok, Problem, if On then "right arm restored" else "right arm is now a robot arm")
    elseif Key == Enum.KeyCode.KeypadFive then
        const Id = selected()
        if Id then
            report(Customize.remove(Id), nil, `removed {Id}`)
        end
    elseif Key == Enum.KeyCode.KeypadSix then
        const Id = selected()
        if Id then
            report(Customize.setColor(Id, Color3.fromHSV(math.random(), 0.7, 0.95)), nil, "recolored")
        end
    elseif Key == Enum.KeyCode.KeypadSeven then
        const Id = selected()
        if Id then
            MaterialIndex = MaterialIndex % #Materials + 1
            report(Customize.setMaterial(Id, Materials[MaterialIndex]), nil, `material {Materials[MaterialIndex].Name}, texture removed`)
        end
    elseif Key == Enum.KeyCode.KeypadEight then
        const Id = selected()
        if Id then
            report(Customize.restoreTexture(Id), nil, "texture restored")
        end
    elseif Key == Enum.KeyCode.KeypadNine then
        const Id = selected()
        if Id then
            const Bodies = Customize.Catalog.BodyParts
            AttachIndex = AttachIndex % #Bodies + 1
            report(Customize.attach(Id, Bodies[AttachIndex]), "body parts can not be re-attached", `attached to {Bodies[AttachIndex]}`)
        end
    elseif Key == Enum.KeyCode.KeypadZero then
        Customize.setSkin(Color3.fromHSV(math.random() * 0.12, 0.35 + math.random() * 0.3, 0.45 + math.random() * 0.5))
        say("new skin color")
    elseif Key == Enum.KeyCode.KeypadPeriod then
        const Id, Problem = Customize.addBuiltin("Cube")
        report(Id ~= nil, Problem, `visor added as {Id}`)
    elseif Key == Enum.KeyCode.KeypadMultiply then
        const Id = selected()
        if Id then
            report(Customize.stretch(Id, Vector3.new(1.25, 1, 1)), "body parts can not be stretched", "stretched wider")
        end
    elseif Key == Enum.KeyCode.KeypadDivide then
        Customize.reset()
        say("look reset")
    elseif Key == Enum.KeyCode.KeypadPlus then
        const Ok, Problem = Customize.save(CustomizeTest.TestSlot, "Test Look")
        report(Ok, Problem, `saved to slot {CustomizeTest.TestSlot}`)
    elseif Key == Enum.KeyCode.KeypadMinus then
        const Ok, Problem = Customize.loadSave(CustomizeTest.TestSlot)
        report(Ok, Problem, `loaded slot {CustomizeTest.TestSlot}`)
    elseif Key == Enum.KeyCode.KeypadEnter then
        const Ok, Problem = Customize.apply()
        report(Ok, Problem, "applied to your character for everyone")
    end
end

function CustomizeTest.start()
    if Started then
        return
    end
    Started = true
    Customize.start()

    UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
        if Processed then
            return
        end
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            if Customize.active() then
                const Id = Customize.selectAtMouse()
                if Id then
                    say(`selected {Id}`)
                end
            end
            return
        end
        const Key = Input.KeyCode
        if Key == CustomizeTest.ToggleKey then
            if Customize.active() then
                Customize.exit()
                say("left customize mode")
            elseif not Tools.active() then
                if Customize.enter() then
                    Cursor = 0
                    ModeIndex = 1
                    help()
                end
            end
            return
        end
        if Customize.active() then
            task.spawn(onKey, Key)
        end
    end)
end

return CustomizeTest
