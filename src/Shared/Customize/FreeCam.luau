--!strict
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")
const Workspace = game:GetService("Workspace")

const Config = require(script.Parent.Config)

type Saved = {
    Type: Enum.CameraType,
    Subject: Humanoid | BasePart | nil,
}

const FreeCam = {
    BindName = "CustomizeFreeCam",
    PitchLimit = math.rad(85),
}

const Links: { RBXScriptConnection } = {}
local Enabled = false
local Looking = false
local Position = Vector3.zero
local Yaw = 0
local Pitch = 0
local Saved: Saved? = nil

const function controls(): any
    const Scripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
    const Module = if Scripts then Scripts:FindFirstChild("PlayerModule") else nil
    if not Module or not Module:IsA("ModuleScript") then
        return nil
    end
    const Ok, Loaded = pcall((require :: any), Module)
    if not Ok or type(Loaded) ~= "table" then
        return nil
    end
    const Got, Found = pcall(function()
        return Loaded:GetControls()
    end)
    return if Got then Found else nil
end

const function setControls(On: boolean)
    const Found = controls()
    if Found then
        pcall(function()
            if On then
                Found:Enable()
            else
                Found:Disable()
            end
        end)
    end
end

const function held(Key: Enum.KeyCode): number
    return if UserInputService:IsKeyDown(Key) then 1 else 0
end

const function step(Delta: number)
    const Camera = Workspace.CurrentCamera
    if not Camera then
        return
    end
    if Looking then
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
    end
    const Rotation = CFrame.fromEulerAnglesYXZ(Pitch, Yaw, 0)
    if not UserInputService:GetFocusedTextBox() then
        const Flat = Vector3.new(
            held(Enum.KeyCode.D) - held(Enum.KeyCode.A),
            0,
            held(Enum.KeyCode.S) - held(Enum.KeyCode.W)
        )
        const Lift = held(Enum.KeyCode.Space) - held(Enum.KeyCode.LeftControl)
        const Speed = Config.CameraSpeed * (if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then Config.CameraFast else 1)
        if Flat.Magnitude > 0 then
            Position += Rotation:VectorToWorldSpace(Flat.Unit) * Speed * Delta
        end
        if Lift ~= 0 then
            Position += Vector3.yAxis * Lift * Speed * Delta
        end
    end
    Camera.CFrame = CFrame.new(Position) * Rotation
end

function FreeCam.active(): boolean
    return Enabled
end

function FreeCam.enable(At: CFrame)
    const Camera = Workspace.CurrentCamera
    if not Camera then
        return
    end
    if not Enabled and not Saved then
        Saved = {
            Type = Camera.CameraType,
            Subject = Camera.CameraSubject :: any,
        }
    end
    FreeCam.disable(true)
    Enabled = true
    Position = At.Position
    const X, Y = At:ToEulerAnglesYXZ()
    Pitch = math.clamp(X, -FreeCam.PitchLimit, FreeCam.PitchLimit)
    Yaw = Y
    Camera.CameraType = Enum.CameraType.Scriptable
    Camera.CFrame = At
    setControls(false)
    RunService:BindToRenderStep(FreeCam.BindName, Enum.RenderPriority.Camera.Value + 1, step)

    table.insert(Links, UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
        if not Processed and Input.UserInputType == Enum.UserInputType.MouseButton2 then
            Looking = true
        end
    end))
    table.insert(Links, UserInputService.InputEnded:Connect(function(Input: InputObject)
        if Input.UserInputType == Enum.UserInputType.MouseButton2 then
            Looking = false
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
    end))
    table.insert(Links, UserInputService.InputChanged:Connect(function(Input: InputObject, Processed: boolean)
        if Input.UserInputType == Enum.UserInputType.MouseWheel and not Processed then
            const Rotation = CFrame.fromEulerAnglesYXZ(Pitch, Yaw, 0)
            Position += Rotation.LookVector * Input.Position.Z * Config.ZoomStep
            return
        end
        if Looking and Input.UserInputType == Enum.UserInputType.MouseMovement then
            const Turn = math.rad(Config.CameraSensitivity)
            Yaw -= Input.Delta.X * Turn
            Pitch = math.clamp(Pitch - Input.Delta.Y * Turn, -FreeCam.PitchLimit, FreeCam.PitchLimit)
        end
    end))
end

function FreeCam.disable(Keep: boolean?)
    if not Enabled then
        return
    end
    Enabled = false
    Looking = false
    RunService:UnbindFromRenderStep(FreeCam.BindName)
    for _, Link in Links do
        Link:Disconnect()
    end
    table.clear(Links)
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    if Keep then
        return
    end
    const Camera = Workspace.CurrentCamera
    const Old = Saved
    Saved = nil
    if Camera then
        Camera.CameraType = if Old then Old.Type else Enum.CameraType.Custom
        const Character = Players.LocalPlayer.Character
        const Humanoid = if Character then Character:FindFirstChildOfClass("Humanoid") else nil
        Camera.CameraSubject = Humanoid or (if Old then Old.Subject else nil)
    end
    setControls(true)
end

return FreeCam
