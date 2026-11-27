---
layout: home

hero:
  eyebrow: Roblox roleplay template
  name: OpenTide
  tagline: Build mode, avatar customize, tools and guns, radio, dice and staff tools. Every system can be changed and every screen can be swapped for your own.
  actions:
    - theme: brand
      text: Get started
      link: getting-started
    - theme: alt
      text: Use your own UI
      link: ui
  code: |
    const UI = require(ReplicatedStorage.Shared.UI)

    UI.use("Radio", ReplicatedStorage.MyUI.Radio)

    return {
        RadioNow = function(Info)
            Title.Text = Info.Channel
        end,
    }
  codeCaption: Point any screen at your own module. The system keeps working.

sections:
  - title: Start
    links:
      - text: Getting started
        link: getting-started
      - text: Your own UI
        link: ui
      - text: Keybinds
        link: keybinds
  - title: Player systems
    links:
      - text: Movement
        link: systems/movement
      - text: Meta vision
        link: systems/meta-vision
      - text: Radio
        link: systems/radio
      - text: Dice
        link: systems/dice
      - text: Action log
        link: systems/action-log
      - text: Emotes
        link: systems/emotes
      - text: Side bar
        link: systems/sidebar
      - text: Settings
        link: systems/settings
      - text: Ruler
        link: systems/ruler
      - text: Toasts
        link: systems/toasts
  - title: Building
    links:
      - text: Build mode
        link: building/build-mode
      - text: Customize
        link: building/customize
  - title: Tools
    links:
      - text: Tools
        link: tools/tools
      - text: Guns
        link: tools/guns
      - text: Throwables
        link: tools/throwables
  - title: Staff
    links:
      - text: Omni tool
        link: staff/omni
  - title: Engine
    links:
      - text: Animations
        link: engine/animations
      - text: Sounds
        link: engine/sounds
      - text: Footsteps
        link: engine/footsteps
      - text: Head turning
        link: engine/head-turning
      - text: Weather and time
        link: engine/weather
---

## Setup

1. Install the tools with [Rokit](https://github.com/rojo-rbx/rokit).

   ```sh
   rokit install
   ```

2. Sync the project into Studio with RoFlux using `default.project.json`.
3. Make sure your place has the tool models in `ServerStorage.ToolAssets` and the dice models in `ReplicatedStorage.DiceModels`.
4. Add your user id to `OmniUsers` and `Moderators` in `src/Server/Admin/Config.luau` to use the staff tools.
