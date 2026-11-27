# Toasts

Short messages that pop up and fade away, like "Put your tool away to emote". Every system sends them through one function.

- Function: `PropPlacer.toast` in `src/Shared/PropPlacer/init.luau`
- Built in screen: `src/Shared/GUI_Elements/Toast.luau`

## API

### `PropPlacer.toast(Text: string, Kind: ToastKind?)`

Shows a toast and plays a sound. `Kind` defaults to `"Error"`.

```luau
export type ToastKind = "Error" | "Info"
```

```luau
const PropPlacer = require(ReplicatedStorage.Shared.PropPlacer)

PropPlacer.toast("Saved your outfit", "Info")
PropPlacer.toast("That slot is empty")
```

`"Info"` plays the `Notify` sound and `"Error"` plays the `Error` sound.

The built in screen shows up to 4 toasts at once and each one stays for 3.5 seconds.

## Your own UI

Screen name: **`Toast`**

The toast screen only shows messages. It has no bridge and sends nothing back.

### Updates

| Update | Value | When |
| --- | --- | --- |
| `Push` | `Message` | A system calls `PropPlacer.toast` |

```luau
export type Message = {
    Text: string,
    Kind: ("Error" | "Info")?,
}
```

### Example

```luau
return {
    mount = function(Parent: Instance): Instance
        Stack.Parent = Parent
        return Stack
    end,
    Push = function(Message)
        const Label = Template:Clone()
        Label.Text = Message.Text
        Label.TextColor3 = if Message.Kind == "Info" then Color3.fromRGB(120, 200, 255) else Color3.fromRGB(255, 170, 90)
        Label.Parent = Stack
        task.delay(3.5, function()
            Label:Destroy()
        end)
    end,
}
```
