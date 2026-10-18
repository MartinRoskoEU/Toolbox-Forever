# Changelog

## Toolbox v0.2.0

### Added

- Added World of Warcraft Retail installation support alongside WoW Forever in a single addon.
- Added a Settings page with saved preferences, including an option to show or hide the minimap button.
- Added a draggable minimap button with a saved position. Left-click opens or closes Toolbox; right-click opens a menu with a Reload UI action.
- Added independent font and size settings for Console Editor, Console Output & Export, API Documentation, API Browser, Atlas Browser, and Sound Browser.
- Added four selectable Blizzard font families: Friz Quadrata, Arial Narrow, Morpheus, and Skurri. Choose font sizes from 10 to 24, preview changes, and reset individual areas or restore all font defaults.
- Added Find & Replace in the Lua Console editor. Use Ctrl+F to find or Ctrl+H to find and replace, navigate matches, enable case-sensitive matching, and replace individual matches or all matches at once.
- Added Undo & Redo in the Lua Console editor, with up to 20 undo steps per UI session. Use Ctrl+Z to undo and Ctrl+Y or Ctrl+Shift+Z to redo.
- Added an Interface Version utility in Developer Tools to display the current client's Interface number in a copyable dialog for addon development.

### Improved

- Improved Console editing with four-space Tab indentation and visible shortcut hints for find, replace, undo, and redo.
- Font changes apply immediately without a UI reload, with related text retaining its relative sizes.
- Improved readability of API documentation, atlas names, and SoundKit details as font sizes change, including wrapping for long atlas names and SoundKit details.
- The API catalog now preserves its scroll position when the window is resized.

## Toolbox v0.1.2

### Added

- Added an API Browser for exploring the WoW API directly inside Toolbox.
- Added browsing of API namespaces, functions, events, structures, enumerations, and constants.
- Added detailed API views with function arguments and return values, event payloads, structure fields, values, properties, metadata, and available documentation.

### Improved

- Added a compact searchable API catalog with clear Function / Returns and Event / Payload listings.
- Improved handling of long API names, types, signatures, and documentation with responsive wrapping and safe truncation where appropriate.
- Improved Structure field presentation with clearly separated Name, Type, Properties, and field documentation.
- Improved Event payload presentation for faster scanning and clearer type information.
- Polished API detail layouts, spacing, scrolling, alignment, and readability across different API entry types.
