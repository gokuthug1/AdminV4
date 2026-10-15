# ServerStorage.AdminTools

This folder contains curated `Tool` instances managed exclusively on the server.

## Why ServerStorage?
1. **Exploit Protection**: Assets in `ServerStorage` do not replicate to clients until explicitly granted by the server into a player's `Backpack`. Client exploiters cannot view, decompile, or steal tools while they reside in `ServerStorage`.
2. **Dynamic Tool Discovery**: Any `Tool` placed inside this folder is automatically detected at runtime by AdminV4.

## Supported Curated Tools
The following standard tools map to built-in commands:
- **`sword`** (`Tool`): Granted via the `:sword [targets]` command.
- **`MetalPipe`** (`Tool`): Granted via the `:pipe [targets]` or `:metalpipe [targets]` command. Features custom swing animations, metal pipe clang sound, 85-stud launch knockback, and 2.5s ragdoll physics.
- **`rpg`** (`Tool`): Granted via the `:rpg [targets]` command.
- **`BuildingTools`** (`Tool`): Granted via the `:btools [targets]` command.
- **`tptool`** (`Tool`): Granted via the `:tptool [targets]` command.

## Custom Game Tools
Any additional custom `Tool` placed in this folder is immediately supported:
- **`:toolsui` / `:tools`**: Opens a Json2GUI list displaying all tools in this folder.
- **`:give <target> <toolName>`**: Case-insensitive fuzzy search grants the tool to the target's backpack.
- **`:toolrain <target> <toolName>`**: Rains copies of the tool over the target.

## Setup Instructions
1. In Roblox Studio, place your `Tool` objects inside `ServerStorage.AdminTools`.
2. When syncing via Rojo, place `.rbxmx` or Tool folders into `ServerStorage/AdminTools`.
