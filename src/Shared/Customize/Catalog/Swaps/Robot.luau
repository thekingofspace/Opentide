--!strict
const Catalog = require(script.Parent.Parent)

const Build = Catalog.Build
const Steel = Color3.fromRGB(96, 102, 112)
const DarkSteel = Color3.fromRGB(58, 62, 70)
const Glow = Color3.fromRGB(80, 220, 255)

const function robotArm(Piece: BasePart, PieceName: string): Catalog.Built?
    const Size = Piece.Size
    if string.find(PieceName, "UpperArm") then
        return Build.model("RobotUpperArm", Build.part("Shell", Size + Vector3.new(0.1, 0.04, 0.1), Steel, Enum.Material.Metal), {
            Build.piece(Build.part("Stripe", Vector3.new(Size.X * 0.25, Size.Y * 0.7, 0.06), Glow, Enum.Material.Neon), CFrame.new(0, 0, -(Size.Z / 2 + 0.07))),
            Build.piece(Build.ball("Shoulder", Size.X * 0.95, DarkSteel, Enum.Material.Metal), CFrame.new(0, Size.Y / 2 - 0.05, 0)),
        })
    elseif string.find(PieceName, "LowerArm") then
        return Build.model("RobotLowerArm", Build.part("Shell", Size + Vector3.new(0.06, 0, 0.06), DarkSteel, Enum.Material.DiamondPlate), {
            Build.piece(Build.ball("Elbow", Size.X * 0.8, Steel, Enum.Material.Metal), CFrame.new(0, Size.Y / 2, 0)),
            Build.piece(Build.part("Ring", Vector3.new(Size.X + 0.16, 0.08, Size.Z + 0.16), Glow, Enum.Material.Neon), CFrame.new(0, -Size.Y / 2 + 0.14, 0)),
        })
    elseif string.find(PieceName, "Hand") then
        const Finger = Vector3.new(Size.X * 0.28, 0.42, Size.Z * 0.34)
        return Build.model("RobotHand", Build.part("Palm", Size + Vector3.new(0.04, 0.02, 0.04), Steel, Enum.Material.Metal), {
            Build.piece(Build.part("FingerFront", Finger, DarkSteel, Enum.Material.Metal), CFrame.new(0, -0.28, -Size.Z * 0.22) * CFrame.Angles(math.rad(-10), 0, 0)),
            Build.piece(Build.part("FingerBack", Finger, DarkSteel, Enum.Material.Metal), CFrame.new(0, -0.28, Size.Z * 0.22) * CFrame.Angles(math.rad(10), 0, 0)),
            Build.piece(Build.part("Light", Vector3.new(Size.X * 0.3, 0.06, 0.06), Glow, Enum.Material.Neon), CFrame.new(0, 0.02, -(Size.Z / 2 + 0.04))),
        })
    end
    return nil
end

const Swaps: Catalog.Swaps = {
    RobotArm = {
        Name = "Robot Arm",
        Limbs = { "LeftArm", "RightArm" },
        build = robotArm,
    },
}

return Swaps
