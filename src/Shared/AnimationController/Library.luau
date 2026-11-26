--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const AnimationController = require(script.Parent)

const Library = {
    FolderName = "Animations",
    Ids = {
        Walk_Legs = "",
        Walk_Body = "",
        CrouchIdle_Legs = "",
        CrouchIdle_Body = "",
        CrouchWalk_Legs = "",
        CrouchWalk_Body = "",
        Point = "",
        CrouchPoint = "",
        Wave = 507770239,
        Cheer = 507770677,
        Laugh = 507770818,
        Dance = 507771019,
    } :: { [string]: string | number },
}

function Library.get(Name: string): AnimationController.Clip?
    const Id = Library.Ids[Name]
    if (type(Id) == "number" and Id > 0) or (type(Id) == "string" and Id ~= "") then
        return Id
    end
    const Folder = ReplicatedStorage:FindFirstChild(Library.FolderName)
    const Found = if Folder then Folder:FindFirstChild(Name) else nil
    if Found and (Found:IsA("KeyframeSequence") or Found:IsA("Animation")) then
        return Found
    end
    return nil
end

function Library.spec(Name: string, ReferenceSpeed: number?): AnimationController.SlotSpec?
    const Clip = Library.get(Name)
    if Clip == nil then
        return nil
    end
    return { Clip = Clip, ReferenceSpeed = ReferenceSpeed }
end

return Library
