--!strict
const MainColor = Color3.new(0.784314, 0.67451, 0.580392)
const ButtonColor = Color3.fromRGB(214, 226, 245)
const AccentColor = Color3.fromRGB(38, 110, 235)

const CommonStyle = {
    name = "Common",
    BackdropColor = MainColor,
    OutlineColor = MainColor:Lerp(Color3.new(0, 0, 0), 0.6),
    BevelLight = MainColor:Lerp(Color3.new(1, 1, 1), 0.35),
    BevelDark = MainColor:Lerp(Color3.new(0, 0, 0), 0.35),
    InkColor = Color3.fromRGB(42, 38, 36),
    CardColor = Color3.fromRGB(246, 244, 241),
    ShadowColor = MainColor:Lerp(Color3.new(0, 0, 0), 0.55),
    MutedColor = Color3.fromRGB(150, 146, 142),
    ButtonColor = ButtonColor,
    AccentColor = AccentColor,
    AccentText = Color3.fromRGB(255, 255, 255),
    IconColor = Color3.fromRGB(188, 192, 199),
    PlateColor = MainColor:Lerp(Color3.new(1, 1, 1), 0.55),
    DividerColor = ButtonColor:Lerp(Color3.new(0, 0, 0), 0.45),
    PackColor = ButtonColor:Lerp(Color3.new(0, 0, 0), 0.5),
    HeaderColor = MainColor:Lerp(Color3.new(0, 0, 0), 0.15),
    HeaderShine = MainColor:Lerp(Color3.new(0, 0, 0), 0.15):Lerp(Color3.new(1, 1, 1), 0.3),
    HeaderShade = MainColor:Lerp(Color3.new(0, 0, 0), 0.15):Lerp(Color3.new(0, 0, 0), 0.35),
    WellColor = MainColor:Lerp(Color3.new(0, 0, 0), 0.12),
    WellShade = MainColor:Lerp(Color3.new(0, 0, 0), 0.38),
    WellLight = MainColor:Lerp(Color3.new(1, 1, 1), 0.3),
    CloseColor = Color3.fromRGB(214, 84, 72),
    CloseText = Color3.fromRGB(255, 255, 255),
    SuccessColor = Color3.fromRGB(78, 160, 96),
    SuccessText = Color3.fromRGB(255, 255, 255),
    WidgetColor = Color3.fromRGB(212, 192, 122),
}

return CommonStyle
