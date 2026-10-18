# Toolbox

Toolbox is an in-game developer utility addon intended for both **World of Warcraft Retail** and **World of Warcraft: Forever**. It collects a Lua console, common debugging controls, texture-atlas browsing, SoundKit exploration, and an API browser in a single movable window.

Both clients share the same Lua implementation and assets, with a separate TOC manifest for each client.

## Current features

### Console

- Run Lua code from a multiline editor with the **Run** button or `F5`.
- View captured `print` output, returned values, compilation errors, and runtime errors.
- Select text directly from the output pane or export the complete output to a copyable text dialog.
- Clear both the input and output panes.
- Find text with `Ctrl+F` or open Find & Replace with `Ctrl+H`. Navigate matches, toggle case-sensitive matching, replace one match, or use Replace All.
- Undo with `Ctrl+Z` and redo with `Ctrl+Y` or `Ctrl+Shift+Z`, with up to 20 undo steps per UI session.
- Insert four spaces with `Tab` and use the editor's shortcut hints for quick reference.

### Developer tools

- Enable or disable Lua error reporting through the `scriptErrors` CVar.
- Toggle Blizzard's frame stack inspector, loading `Blizzard_DebugTools` when needed.
- Reload the user interface from the Toolbox window.
- Display the current client's Interface number in a copyable dialog with **Interface Version**.

### Atlas browser

- Browse the texture atlases exposed by `C_Texture.GetAtlasElements()`.
- Filter atlas names with a case-insensitive search.
- Preview the selected atlas, scaled to fit, with its dimensions displayed.
- Move through the filtered list with the up and down arrow keys.
- Export the selected atlas name to a copyable text dialog.

### Sound browser

- Browse the SoundKits exposed through Blizzard's `SOUNDKIT` table.
- Filter SoundKit names with a case-insensitive search.
- Move through the filtered list with the up and down arrow keys.
- View the selected SoundKit name and numeric SoundKit ID.
- Play the selected SoundKit directly in-game.
- Stop the currently playing SoundKit.
- Automatically stop playback when changing selection, filtering out the selected SoundKit, leaving the Sounds page, or closing Toolbox.
- Track natural sound completion through `SOUNDKIT_FINISHED`.
- Export the selected SoundKit ID to a copyable text dialog.

### API browser

- Browse documented API namespaces, functions, events, structures, enumerations, and constants.
- Search the API catalog and open detailed entries with available arguments, returns, payloads, fields, values, properties, metadata, and documentation.
- Return to the catalog with the current search and scroll position preserved.

### Settings

- Show or hide the minimap button.
- Customize fonts and sizes independently for Console Editor, Console Output & Export, API Documentation, API Browser, Atlas Browser, and Sound Browser.
- Choose Friz Quadrata, Arial Narrow, Morpheus, or Skurri, with selectable font sizes from 10 to 24. Related text retains its relative sizes.
- Preview font changes and apply them immediately without a UI reload.
- Reset individual content areas or restore all font defaults.
- Font preferences and the minimap button's visibility and position are saved between sessions.

### Interface

- Open or close Toolbox from the game's addon compartment.
- Left-click the minimap button to open or close Toolbox, right-click for a Reload UI menu, or drag it around the minimap to reposition it.
- Navigate between the Console, Tools, Atlas, Sounds, API, and Settings pages in a movable window.
- Use reusable window, navigation, checkbox, page, and text-export components.

## Project structure

```text
Toolbox/
|-- Assets/
|   `-- toolbox_icon_128.png     Addon icon
|-- Core/
|   |-- Namespace.lua            Shared addon namespace
|   |-- Database.lua             Saved minimap and typography preferences
|   |-- Typography.lua           Shared font settings and live updates
|   `-- Init.lua                 Addon loading and compartment entry point
|-- UI/
|   |-- Components/              Reusable window and control components
|   |-- Pages/                   Console, tools, atlas, sound, API, and settings pages
|   |-- MainWindow.lua           Main window layout and navigation
|   `-- MinimapButton.lua        Minimap access and positioning
|-- .vscode/
|   `-- settings.json            Lua 5.1 and WoW API editor settings
|-- Toolbox_Mainline.toc         Retail metadata and shared file load order
`-- Toolbox_Forever.toc          Forever metadata and shared file load order
```

## Installation

1. Download or clone this repository.
2. Place the project directory in the desired Retail or Forever client's `Interface/AddOns` directory.
3. Ensure the installed directory is named `Toolbox` and contains both `Toolbox_Mainline.toc` and `Toolbox_Forever.toc` directly inside it. The client selects the appropriate manifest.
4. Start or reload World of Warcraft and enable **Toolbox** in the AddOns list if necessary.
5. Open Toolbox from the addon compartment in the game interface or by left-clicking the minimap button.

## Development notes

- The manifests declare interface versions `120105` for Retail and `16001` for Forever. Both declare addon version `0.2.0`.
- Source files use the World of Warcraft Lua 5.1 environment and Blizzard UI APIs.
- Both TOC manifests list the same source files in the same load order; keep them synchronized when adding source files that must load at startup.
- The API Browser loads Blizzard API documentation from the running client, the Atlas Browser uses `C_Texture.GetAtlasElements()`, and the Sound Browser reads the client's `SOUNDKIT` table. No client-specific catalogs are bundled.
- The project has no bundled third-party libraries. Both manifests declare the account-wide `ToolboxDB` saved variable for minimap and typography preferences.
- The console executes Lua in the live game environment. Run only code you understand, because it can read and modify game-accessible state.
- The included VS Code settings target Lua 5.1 and reference annotations from the Ketho WoW API extension.

## Packaging and releases

Retail and Forever use one CurseForge project and one distributable archive containing both TOC manifests and the shared addon files. The existing GitHub-to-CurseForge integration generates the archive automatically when a release Git tag is pushed.

Packaging remains configured by `.pkgmeta`, including the manual Markdown changelog from `CHANGELOG.md`. Tests remain in the repository and are excluded from the distributed addon. No local packaging or separate client builds are required. Manual in-game verification for v0.2.0 is complete.
