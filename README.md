# AdminV4 - Enterprise Roblox Administration System

AdminV4 is an advanced, production-grade Roblox administration system designed for maximum security, modularity, visual polish, and native engine compliance.

---

## 1. Architecture & Hierarchy

The codebase is engineered to run seamlessly across all Roblox Studio development environments, whether imported manually or synchronized via **Rojo**:

```text
AdminV4/
├── default.project.json                    # Rojo project specification
├── Json2Schemas/                           # Normative authoring schemas
│   ├── AdminUiAssets.json                  # Master Json2GUI generation suite (11 UI templates)
│   ├── Admin3DAssets.json                  # Master Json23D generation suite (6 3D models)
│   ├── AdminAnimations.json               # Master Json2Anim generation suite (R15 & R6 swings)
│   ├── JSON23D_SCHEMA_GUIDE.md
│   ├── JSON2ANIM_SCHEMA_GUIDE.md
│   ├── JSON2GUI_SCHEMA_GUIDE.md
│   ├── 3D/                                 # Modular Json23D asset schemas
│   │   ├── Bomb.json
│   │   ├── Halo.json
│   │   ├── Horns.json
│   │   ├── Jail.json
│   │   ├── MetalPipe.json
│   │   └── Wings.json
│   ├── Anim/                               # Modular Json2Anim animation sequences
│   │   ├── MetalPipeSwing_R15.json
│   │   └── MetalPipeSwing_R6.json
│   └── UI/                                 # Modular Json2GUI component schemas
│       ├── Banner.json
│       ├── Blind.json
│       ├── CmdBar.json
│       ├── Flashbang.json
│       ├── List.json
│       ├── Modal.json
│       ├── Notification.json
│       ├── Pm.json
│       ├── Shutdown.json
│       ├── TeamCreator.json
│       └── Title.json
├── ReplicatedStorage/
│   ├── AdminAssets/                        # Curated 3D models and accessories folder
│   ├── AdminSettings.lua                   # Central configuration & command registry (263 commands)
│   ├── AdminUiAssets/                      # Replicated UI assets folder (populated via Json2GUI)
│   ├── AdminUiAssets.json                  # Master Json2GUI generation document
│   └── Remotes/                            # Network remote container (managed by server)
│       ├── ClientAction (RemoteEvent)
│       ├── ExecuteCommand (RemoteEvent)
│       └── TeamRequest (RemoteFunction)
├── ServerScriptService/
│   └── AdminLoader/
│       ├── init.legacy.lua                 # Server bootstrap & command execution pipeline
│       ├── Commands.lua                    # Hardened, filtered server command handlers
│       └── Util.lua                        # Target resolution, permission checks & math helpers
├── ServerStorage/
│   └── AdminTools/                         # Server-only curated tools container (anti-exploit)
└── StarterPlayerScripts/
    └── AdminClient.local.lua               # Client command bar, list UI, and visual effect controller
```

---

## 2. Generating UI with Json2GUI

In accordance with strict design principles, **no UI elements are generated via code or rely on runtime code fallbacks**. All user interfaces are declarative templates generated into `ReplicatedStorage.AdminUiAssets` using **Json2GUI** (Schema v2 / Plugin v2.2.0):

### One-Click Generation:
1. Open Roblox Studio with the **Json2GUI** plugin installed.
2. Select `ReplicatedStorage.AdminUiAssets` in the Explorer window.
3. Open `ReplicatedStorage/AdminUiAssets.json` (or `Json2Schemas/AdminUiAssets.json`).
4. Generate the UI into the target.

### Included UI Templates:
| Template | Class | Target Container | Purpose |
|---|---|---|---|
| `CmdBar` | `ScreenGui` | `PlayerGui.CmdBar` | Autocomplete admin command bar with keyboard shortcuts |
| `List` | `ScreenGui` | `PlayerGui.<ListName>` | Filterable list viewer for `cmds`, `logs`, `bans`, `info` |
| `Banner` | `ScreenGui` | `PlayerGui.<BannerId>` | Timed broadcast announcements and warning banners |
| `Modal` | `ScreenGui` | `PlayerGui.<ModalId>` | Confirmation modals, prompts, and server dialogs |
| `TeamCreator`| `ScreenGui` | `PlayerGui.TeamCreator` | Full team management & color selection GUI |
| `Blind` | `ScreenGui` | `PlayerGui.Blind` | Fullscreen black sensory blocker |
| `Flashbang` | `ScreenGui` | `PlayerGui.Flashbang` | Smooth fading white blinding screen effect |
| `Notification`| `ScreenGui` | `PlayerGui.Notification`| Bottom-right non-intrusive toast notifications |
| `Pm` | `ScreenGui` | `PlayerGui.Pm` | Two-way private messaging modal with reply box |
| `Title` | `BillboardGui`| `Character.Head.TitleGui` | Overhead floating titles with custom colors |
| `Shutdown` | `ScreenGui` | `PlayerGui.Shutdown` | Fullscreen graceful server shutdown overlay |

---

## 3. System Highlights & Robustness

- **Hierarchy-Agnostic Module Resolution:** `init.legacy.lua` and `Commands.lua` use dynamic resolution (`resolveModule` / `resolveSiblingModule`). The system functions identically whether `AdminLoader` is a Script with children, a Folder containing siblings, or a Rojo model.
- **Zero Race Conditions:** Client UI asset fetching utilizes safe replication timeouts (`WaitForChild(name, 5)`), ensuring smooth join times even on slower network connections.
- **Strict Text Filtering:** All user-facing broadcast and private messages (`pm`, `m`, `title`, `countdown`, `team`) pass through `TextService:FilterStringAsync` before delivery.
- **Exploitation & Type Hardening:** Remote events and functions enforce strict instance and type validation, preventing malicious payloads.
- **Zero Command Drift:** All 263 commands registered in `AdminSettings.lua` have 1:1 corresponding hardened handlers in `Commands.lua`, with 0 duplicates and 0 dead stubs.
- **State Recovery & Undo Support:** Commands such as `color`, `material`, and `aura` snapshot previous appearances, enabling accurate rollback.

---

## 4. AdminAssets & AdminTools Architecture

### `ReplicatedStorage.AdminAssets` (3D Models & Accessories)
This folder holds visual 3D models and character accessories that must replicate to all clients:
- **`Jail`** (`Model`): Spawned around jailed players (`:jail`). Includes a `JailSpawn` part and primary floor.
- **`Halo`** (`Model`): Ring attached above target's head (`:halo`).
- **`Horns`** (`Model`): Horns attached to target's head (`:horns`).
- **`Wings`** (`Model`): Wings attached to target's torso (`:wings`).
- **`Bomb`** (`Model`): Explosive dropped from the sky during explosive rain (`:erain`).
- **`Player`** (`Model`): Character rig spawned as an NPC dummy (`:npc`).
- **`TimeBomb`** (`Tool`): Time bomb tool granted to targets (`:tbomb`).

> **JSON23D Generation:** Ready-to-generate declarative schemas for these 3D models are provided in [`Json2Schemas/3D/`](file:///c:/Users/jb/Documents/AdminV4/Json2Schemas/3D) and bundled in [`Json2Schemas/Admin3DAssets.json`](file:///c:/Users/jb/Documents/AdminV4/Json2Schemas/Admin3DAssets.json).

### `ServerStorage.AdminTools` (Server-Side Curated Tools)
This folder holds server-only `Tool` instances:
- **Exploit Immunity:** Because tools reside in `ServerStorage`, clients cannot decompile, view, or exploit tool code until an administrator explicitly gives them.
- **Dynamic Tool Discovery:** Any tool placed in `ServerStorage.AdminTools` is automatically detected by `:toolsui` / `:tools`, can be granted via `:give <target> <tool>`, and can be dropped via `:toolrain <target> <tool>`.
- **Standard Curated Tools:** Built-in commands expect `sword`, `MetalPipe` (`:pipe` / `:metalpipe`), `rpg`, `BuildingTools` (`:btools`), and `tptool`.

