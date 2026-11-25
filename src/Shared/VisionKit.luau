--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Workspace = game:GetService("Workspace")

const Vision = require(ReplicatedStorage.MainPackages.vision)

export type Declaration = Vision.Declaration

const VisionKit = {
	Screen = Vector2.new(1920, 1080),
}

const function merge(Base: Declaration, Extra: Declaration?): Declaration
	if not Extra then
		return Base
	end
	for Key, Value in Extra do
		if type(Key) ~= "number" then
			Base[Key] = Value
		end
	end
	for _, Entry in ipairs(Extra) do
		table.insert(Base, Entry)
	end
	return Base
end

const function pixels(Size: UDim2 | Vector2): Vector2
	if typeof(Size) == "Vector2" then
		return Size
	end
	const Screen = VisionKit.Screen
	return Vector2.new(Size.X.Scale * Screen.X + Size.X.Offset, Size.Y.Scale * Screen.Y + Size.Y.Offset)
end

const function viewport(): Vector2
	const Camera = Workspace.CurrentCamera
	return if Camera then Camera.ViewportSize else Vector2.zero
end

function VisionKit.screenScale(Viewport: Vector2?): number
	const Size = Viewport or viewport()
	const Screen = VisionKit.Screen
	if Size.X <= 0 or Size.Y <= 0 then
		return 1
	end
	return math.min(Size.X / Screen.X, Size.Y / Screen.Y)
end

function VisionKit.ratio(
	Size: UDim2 | Vector2,
	ScaleSize: boolean?,
	Properties: Declaration?,
	ScaleProperties: Declaration?
): (Declaration, Declaration?)
	const Pixels = pixels(Size)
	assert(Pixels.X > 0 and Pixels.Y > 0, "VisionKit.ratio needs a size with a width and height above 0")

	const Ratio = merge({
		ClassName = "UIAspectRatioConstraint",
		AspectRatio = Pixels.X / Pixels.Y,
	}, Properties)

	if not ScaleSize then
		return Ratio, nil
	end

	const Scale = merge({
		ClassName = "UIScale",
		Scale = VisionKit.screenScale(),
	}, ScaleProperties)

	const Margin = Scale.Margin
	Scale.Margin = nil
	if Margin ~= nil then
		assert(typeof(Margin) == "UDim", "VisionKit.ratio Margin needs a UDim, like UDim.new(0.1, 0) or UDim.new(0, 40)")
		const Along = if Ratio.DominantAxis == Enum.DominantAxis.Height then Pixels.Y else Pixels.X
		Scale.Scale = math.max(Scale.Scale * (1 + Margin.Scale + Margin.Offset / Along), 0)
	end

	return Ratio, Scale
end

function VisionKit.fit(Frame: GuiObject, Later: (() -> ()) -> (), Minimum: number?)
	const Scale = Frame:FindFirstChildOfClass("UIScale")
	if not Scale then
		return
	end
	local Watch: RBXScriptConnection? = nil

	const function refit()
		const Parent = Frame.Parent
		if not (Parent and Parent:IsA("GuiBase2d")) then
			return
		end
		const Size = Parent.AbsoluteSize
		if Size.X <= 0 or Size.Y <= 0 then
			return
		end
		const Next = math.max(VisionKit.screenScale(Size), Minimum or 0)
		if math.abs(Scale.Scale - Next) > 0.001 then
			Scale.Scale = Next
		end
	end

	const function bind()
		const Old = Watch
		if Old then
			Old:Disconnect()
			Watch = nil
		end
		const Parent = Frame.Parent
		if Parent and Parent:IsA("GuiBase2d") then
			Watch = Parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
		end
		refit()
	end

	const Moved = Frame.AncestryChanged:Connect(bind)
	bind()

	Later(function()
		Moved:Disconnect()
		const Old = Watch
		if Old then
			Old:Disconnect()
			Watch = nil
		end
	end)
end

return VisionKit
