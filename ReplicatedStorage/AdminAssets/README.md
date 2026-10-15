# ReplicatedStorage.AdminAssets

This folder contains replicated 3D models and accessory assets used by physical/visual admin commands.

## Why ReplicatedStorage?
Because these assets are spawned into the Workspace or attached to player characters, they must exist in a replicated location so both server and client can access and render them without desynchronization.

## Expected Assets
The following models and tools are referenced by `Commands.lua`:

| Asset Name | Expected Class | Referenced By | Description |
|---|---|---|---|
| **`Jail`** | `Model` | `:jail [targets]` | Spawned around the caged player. Can contain a `JailSpawn` Part where the target will be teleported. |
| **`Bomb`** | `Model` or `Part` | `:erain` | Spawned from the sky during explosive rain; contains a `BasePart` handle that detonates on impact. |
| **`Player`** | `Model` | `:npc [targets]` | NPC dummy rig spawned 10 studs in front of the target. |
| **`Halo`** | `Model` | `:halo [targets] [color]` | Golden ring or halo welded to the target's `Head`. |
| **`Horns`** | `Model` | `:horns [targets] [color]` | Horn accessory model welded to the target's `Head`. |
| **`Wings`** | `Model` | `:wings [targets]` | Wing accessory model welded to the target's `UpperTorso` (or `Torso`). |
| **`TimeBomb`** | `Tool` | `:tbomb [targets]` | Time bomb tool given to the target. |

## Authoring Options
1. **JSON23D (Recommended)**: Use the strict declarative JSON23D schemas located in `Json2Schemas/3D/` (`Jail.json`, `Halo.json`, `Horns.json`, `Wings.json`, `Bomb.json`) to generate native 3D models via the JSON23D Studio plugin.
2. **Roblox Studio / Rojo**: Place standard Roblox `Model` or `Tool` instances directly inside `ReplicatedStorage.AdminAssets`.

If an asset is not present when a command is executed, the system gracefully notifies the admin without throwing runtime errors.
