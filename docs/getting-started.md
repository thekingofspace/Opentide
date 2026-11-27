# Getting started

::: info About these docs
Docs were written with AI. All code is written by me, however these docs were written with AI with heavy control from me to make sure the API is as accurate as possible.
:::

OpenTide is a Roblox roleplay template. This guide shows how each part works and how to add your own.

## Setup

1. Install the tools with [Rokit](https://github.com/rojo-rbx/rokit).

   ```sh
   rokit install
   ```

2. Sync the project into Studio with RoFlux using `default.project.json`.
3. Make sure your place has the tool models in `ServerStorage.ToolAssets` and the dice models in `ReplicatedStorage.DiceModels`.
4. Add your user id to `OmniUsers` and `Moderators` in `src/Server/Admin/Config.luau` to use the staff tools.

## Swapping screens

Every screen loads through `src/Shared/UI`. Point a screen name at your own module in `src/Shared/UI/Config.luau` and the systems plug into it.
