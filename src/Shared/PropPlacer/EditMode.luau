--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const UserInputService = game:GetService("UserInputService")
const Workspace = game:GetService("Workspace")

const vision = require(ReplicatedStorage.MainPackages.vision)
const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const Config = require(ReplicatedStorage.Shared.PropData.Config)
const CommonStyle = require(ReplicatedStorage.Shared.GUI_Elements.CommonStyle)
const PropPlacer = require(script.Parent)
const PropObject = require(script.Parent.PropObject)
const World = require(script.Parent.World)
const Container = require(script.Parent.Container)
const Placement = require(script.Parent.Placement)
const Sounds = require(ReplicatedStorage.Shared.Sounds)

type Prop = PropObject.Prop

type Move = {
    Key: string,
    Pivot: CFrame,
    Scale: number,
}

const Scope = vision.Scope()
const _MainStyle = Scope:LoadStyle(table.clone(CommonStyle) :: any)
const Common = vision.style("Common")

const EditMode = {
    RefreshInterval = 0.5,
    MarkerSize = 18,
    DragThreshold = 6,
}

const Selected: { [string]: Prop } = {}
const Markers: { [string]: vision.Vision } = {}
const Anchors: { [string]: Attachment } = {}
local Active = false
local Editing = false
local Selection: Model? = nil
local MarkerFolder: Folder? = nil
local Loop: thread? = nil
local Started = false
local DragStart: Vector2? = nil
local Dragging = false
local DragBox: vision.Vision? = nil

const function selectionModel(): Model
    const Existing = Selection
    if Existing and Existing.Parent then
        return Existing
    end
    const Model = Instance.new("Model")
    Model.Name = "PropSelection"
    const Highlight = Instance.new("Highlight")
    Highlight.Name = "SelectionHighlight"
    Highlight.FillColor = Color3.new(1, 1, 1)
    Highlight.OutlineColor = Color3.new(1, 1, 1)
    Highlight.FillTransparency = 0.7
    Highlight.OutlineTransparency = 0
    Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    Highlight.Adornee = Model
    Highlight.Parent = Model
    Model.Parent = Workspace
    Selection = Model
    return Model
end

const function markerFolder(): Folder
    const Existing = MarkerFolder
    if Existing and Existing.Parent then
        return Existing
    end
    const Made = Instance.new("Folder")
    Made.Name = "PropMarkers"
    Made.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    MarkerFolder = Made
    return Made
end

const function count(): number
    local Total = 0
    for _ in Selected do
        Total += 1
    end
    return Total
end

const function select(Prop: Prop)
    Selected[Prop.Key] = Prop
    PropObject.setHome(Prop, selectionModel())
    const Marker = Markers[Prop.Key]
    if Marker then
        Marker.Picked(true)
    end
end

const function unselect(Prop: Prop)
    Selected[Prop.Key] = nil
    if not Prop.Destroyed then
        PropObject.setHome(Prop, World.folder())
    end
    const Marker = Markers[Prop.Key]
    if Marker then
        Marker.Picked(false)
    end
end

function EditMode.toggleSelect(Prop: Prop)
    if not Active or Editing or Prop.Destroyed then
        return
    end
    if Selected[Prop.Key] then
        unselect(Prop)
        Sounds.play("Unselect")
    else
        select(Prop)
        Sounds.play("Select")
    end
    PropPlacer.setSelected(count())
end

function EditMode.clearSelection()
    for _, Prop in Selected do
        unselect(Prop)
    end
    PropPlacer.setSelected(0)
end

const function marker(Prop: Prop, Anchor: Attachment): { [any]: any }
    return {
        ClassName = "BillboardGui",
        Name = Prop.Key,
        Adornee = Anchor,
        Size = UDim2.fromOffset(EditMode.MarkerSize, EditMode.MarkerSize),
        AlwaysOnTop = true,
        Active = true,
        ResetOnSpawn = false,
        MaxDistance = Config.EditRange,
        vision.mount(markerFolder()),

        {
            ClassName = "TextButton",
            Name = "Marker",
            Size = UDim2.fromScale(1, 1),
            Text = "",
            AutoButtonColor = true,
            BackgroundColor3 = Common["CardColor"],
            BackgroundTransparency = 0.1,
            BorderSizePixel = 0,
            Activated = function()
                EditMode.toggleSelect(Prop)
            end,

            vision.event("Picked", Selected[Prop.Key] ~= nil, function(Button: Instance, _, Value: boolean)
                (Button :: TextButton).BackgroundColor3 = if Value then CommonStyle.AccentColor else CommonStyle.CardColor
            end)
        }
    }
end

const function dropMarker(Key: string)
    const Marker = Markers[Key]
    if Marker then
        Markers[Key] = nil
        Marker:Cleanup()
    end
    const Anchor = Anchors[Key]
    if Anchor then
        Anchors[Key] = nil
        Anchor:Destroy()
    end
end

const function candidates(): { [string]: Prop }
    const Found: { [string]: Prop } = {}
    const Character = Players.LocalPlayer.Character
    const Root = if Character then Character:FindFirstChild("HumanoidRootPart") else nil
    if not Active or Editing or not Root or not Root:IsA("BasePart") then
        return Found
    end
    for Key, Prop in World.all() do
        if Prop.Mounted and Prop.Model and not Prop.Hidden and Prop:isOwner() and (Prop.Pivot.Position - Root.Position).Magnitude <= Config.EditRange then
            Found[Key] = Prop
        end
    end
    return Found
end

const function refresh()
    const Wanted = candidates()
    for Key in Markers do
        if not Wanted[Key] then
            dropMarker(Key)
        end
    end
    for Key, Prop in Wanted do
        if not Prop.Model then
            continue
        end
        const Center = Prop.RestBox.Position
        const Existing = Anchors[Key]
        if Existing then
            if (Existing.WorldPosition - Center).Magnitude > 0.05 then
                Existing.WorldPosition = Center
            end
            continue
        end
        const Anchor = Instance.new("Attachment")
        Anchor.Name = "PropMarker"
        Anchor.Parent = Workspace.Terrain
        Anchor.WorldPosition = Center
        Anchors[Key] = Anchor
        const Made = Scope:Capture(marker(Prop, Anchor))
        Made:Mount()
        Markers[Key] = Made
    end
end

const function dragBox(): vision.Vision
    const Existing = DragBox
    if Existing then
        return Existing
    end
    const Made = Scope:Capture({
        ClassName = "ScreenGui",
        Name = "PropDragSelect",
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 10,
        vision.mount(Players.LocalPlayer:WaitForChild("PlayerGui")),

        {
            ClassName = "Frame",
            Name = "Box",
            Visible = false,
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.85,
            BorderSizePixel = 0,

            vision.event("Box", false, function(Frame: Instance, _, Value: any)
                const Box = Frame :: Frame
                if type(Value) ~= "table" then
                    Box.Visible = false
                    return
                end
                const Corner = (Value.From :: Vector2):Min(Value.To)
                const Far = (Value.From :: Vector2):Max(Value.To)
                Box.Position = UDim2.fromOffset(Corner.X, Corner.Y)
                Box.Size = UDim2.fromOffset(Far.X - Corner.X, Far.Y - Corner.Y)
                Box.Visible = true
            end),

            {
                ClassName = "UIStroke",
                Color = Color3.new(1, 1, 1),
                Thickness = 1.5,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            }
        }
    }::ScreenGui & any)
    Made:Mount()
    DragBox = Made
    return Made
end

const function adding(): boolean
    return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
        or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
        or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
        or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
end

const function boxSelect(From: Vector2, To: Vector2)
    const Camera = Workspace.CurrentCamera
    if not Camera then
        return
    end
    const Corner = From:Min(To)
    const Far = From:Max(To)
    if not adding() then
        for _, Prop in Selected do
            unselect(Prop)
        end
    end
    for _, Prop in candidates() do
        if not Prop.Model then
            continue
        end
        const Point, OnScreen = Camera:WorldToViewportPoint(Prop.RestBox.Position)
        if OnScreen and Point.X >= Corner.X and Point.X <= Far.X and Point.Y >= Corner.Y and Point.Y <= Far.Y then
            select(Prop)
        end
    end
    Sounds.play("BoxSelect")
    PropPlacer.setSelected(count())
end

const function endDrag()
    DragStart = nil
    if Dragging then
        Dragging = false
        dragBox().Box(false)
    end
end

const function onBegan(Input: InputObject, Processed: boolean)
    if Processed or not Active or Editing or Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
        return
    end
    DragStart = UserInputService:GetMouseLocation()
    Dragging = false
end

const function onChanged(Input: InputObject)
    const Start = DragStart
    if not Start or Input.UserInputType ~= Enum.UserInputType.MouseMovement then
        return
    end
    const Now = UserInputService:GetMouseLocation()
    if not Dragging and (Now - Start).Magnitude < EditMode.DragThreshold then
        return
    end
    Dragging = true
    dragBox().Box({ From = Start, To = Now })
end

const function onEnded(Input: InputObject)
    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
        return
    end
    const Start = DragStart
    const Was = Dragging
    endDrag()
    if Start and Was and Active and not Editing then
        boxSelect(Start, UserInputService:GetMouseLocation())
    end
end

const function restore(Chosen: { Prop })
    Editing = false
    for _, Prop in Chosen do
        PropObject.setHidden(Prop, false)
    end
    EditMode.clearSelection()
    refresh()
end

const function sendMoves(Holder: Container.Container): (boolean, string?)
    const Moves: { Move } = {}
    for _, Move in Container.transforms(Holder) do
        const Key = Move.Item.Key
        if Key then
            table.insert(Moves, { Key = Key, Pivot = Move.Pivot, Scale = Move.Scale })
        end
    end
    if #Moves == 0 then
        return false, "There is nothing to move"
    end
    const Reply = NetWatch.PropPlacer:Call("@Props/Move", Moves)
    if type(Reply) ~= "table" then
        return false, "The server did not answer, try again"
    end
    if not Reply.Ok then
        return false, if type(Reply.Error) == "string" then Reply.Error else "Those props could not move"
    end
    for _, Move in Moves do
        const Prop = World.get(Move.Key)
        if Prop then
            PropObject.applyTransform(Prop, Move.Pivot, Move.Scale)
        end
    end
    Sounds.play("MoveConfirm")
    return true, nil
end

function EditMode.editSelected()
    if not Active or Editing then
        return
    end
    const Chosen: { Prop } = {}
    for _, Prop in Selected do
        if not Prop.Destroyed and Prop.Model then
            table.insert(Chosen, Prop)
        end
    end
    if #Chosen == 0 then
        PropPlacer.toast("Select some of your props first")
        return
    end

    Editing = true
    endDrag()
    refresh()
    const Target = Container.new()
    for _, Prop in Chosen do
        const Model = Prop.Model
        const Copy = if Model then Model:Clone() else nil
        if Copy then
            Container.add(Target, Prop.Id, Copy, Prop.Key, nil)
        end
        PropObject.setHidden(Prop, true)
    end
    Container.fit(Target)
    Placement.begin(Target, {
        commit = sendMoves,
        finished = function()
            restore(Chosen)
            EditMode.exit()
        end,
        cancelled = function()
            restore(Chosen)
            EditMode.exit()
        end,
    })
end

function EditMode.deleteSelected()
    if not Active or Editing then
        return
    end
    const Keys: { string } = {}
    for Key, Prop in Selected do
        if not Prop.Destroyed then
            table.insert(Keys, Key)
        end
    end
    if #Keys == 0 then
        PropPlacer.toast("Select some of your props first")
        return
    end
    const Reply = NetWatch.PropPlacer:Call("@Props/Delete", Keys)
    if type(Reply) ~= "table" then
        PropPlacer.toast("The server did not answer, try again")
    elseif not Reply.Ok then
        PropPlacer.toast(if type(Reply.Error) == "string" then Reply.Error else "Those props could not be deleted")
    else
        Sounds.play("DeleteConfirm")
        EditMode.exit()
    end
end

function EditMode.selectedKeys(): { string }
    const Keys: { string } = {}
    for Key, Prop in Selected do
        if not Prop.Destroyed then
            table.insert(Keys, Key)
        end
    end
    return Keys
end

function EditMode.active(): boolean
    return Active
end

function EditMode.editing(): boolean
    return Editing
end

function EditMode.enter()
    if Active then
        return
    end
    Placement.cancel()
    Active = true
    Sounds.play("EditEnter")
    PropPlacer.setVisible(true)
    PropPlacer.setMode("Edit")
    PropPlacer.setSelected(0)
    Loop = task.spawn(function()
        while Active do
            refresh()
            task.wait(EditMode.RefreshInterval)
        end
    end)
end

function EditMode.exit()
    if not Active then
        return
    end
    if Editing then
        Placement.cancel()
    end
    Active = false
    Editing = false
    endDrag()
    EditMode.clearSelection()
    const Running = Loop
    Loop = nil
    if Running and coroutine.status(Running) == "suspended" then
        task.cancel(Running)
    end
    refresh()
    Sounds.play("EditExit")
    PropPlacer.setMode("Browse")
end

function EditMode.toggle()
    if Active then
        EditMode.exit()
    else
        EditMode.enter()
    end
end

function EditMode.start()
    if Started then
        return
    end
    Started = true
    World.Removed:Connect(function(Prop: Prop)
        if Selected[Prop.Key] == Prop then
            Selected[Prop.Key] = nil
            PropPlacer.setSelected(count())
        end
        dropMarker(Prop.Key)
    end)
    UserInputService.InputBegan:Connect(onBegan)
    UserInputService.InputChanged:Connect(onChanged)
    UserInputService.InputEnded:Connect(onEnded)
end

return EditMode
