# Toolbox

Toolbox is an in-game developer utility addon for **World of Warcraft: Forever**. It collects a Lua console, common debugging controls, and a texture-atlas browser in a single movable window.

This repository is specifically maintained for the World of Warcraft: Forever version of the addon.

## Current features

### Console

- Run Lua code from a multiline editor with the **Run** button or `F5`.
- View captured `print` output, returned values, compilation errors, and runtime errors.
- Select text directly from the output pane or export the complete output to a copyable text dialog.
- Clear both the input and output panes.

### Developer tools

- Enable or disable Lua error reporting through the `scriptErrors` CVar.
- Toggle Blizzard's frame stack inspector, loading `Blizzard_DebugTools` when needed.
- Reload the user interface from the Toolbox window.

### Atlas browser

- Browse the texture atlases exposed by `C_Texture.GetAtlasElements()`.
- Filter atlas names with a case-insensitive search.
- Preview the selected atlas, scaled to fit, with its dimensions displayed.
- Move through the filtered list with the up and down arrow keys.
- Export the selected atlas name to a copyable text dialog.

### Interface

- Open or close Toolbox from the game's addon compartment.
- Navigate between the Console, Tools, and Atlas pages in a movable window.
- Use reusable window, navigation, checkbox, page, and text-export components.

## Project structure

```text
Toolbox/
|-- Assets/
|   `-- toolbox_icon_128.png     Addon icon
|-- Core/
|   |-- Namespace.lua           Shared addon namespace
|   `-- Init.lua                Addon loading and compartment entry point
|-- UI/
|   |-- Components/             Reusable window and control components
|   |-- Pages/                  Console, tools, and atlas pages
|   `-- MainWindow.lua          Main window layout and navigation
|-- .vscode/
|   `-- settings.json           Lua 5.1 and WoW API editor settings
`-- Toolbox.toc                 Addon metadata and file load order
```

## Installation

1. Download or clone this repository.
2. Place the project directory in the World of Warcraft: Forever client's `Interface/AddOns` directory.
3. Ensure the installed directory is named `Toolbox` and contains `Toolbox.toc` directly inside it.
4. Start or reload World of Warcraft and enable **Toolbox** in the AddOns list if necessary.
5. Open Toolbox from the addon compartment in the game interface.

## Development notes

- The addon metadata currently declares interface version `16001` and addon version `0.1.0`.
- Source files use the World of Warcraft Lua 5.1 environment and Blizzard UI APIs.
- File load order is defined in `Toolbox.toc`; update it when adding source files that must load at startup.
- The project has no bundled third-party libraries and does not declare saved variables.
- The console executes Lua in the live game environment. Run only code you understand, because it can read and modify game-accessible global state.
- The included VS Code settings target Lua 5.1 and reference annotations from the Ketho WoW API extension.
