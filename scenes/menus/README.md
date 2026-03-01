# scenes/menus/

Entry-point and lobby scenes.

## `MainMenu.gd`

Builds a simple centered UI (`CenterContainer → VBoxContainer`) with a title, subtitle, Play button, and Quit button. All nodes are created programmatically in `_build_ui()`.

**Play button** calls `get_tree().change_scene_to_file("res://scenes/main/Main.tscn")`, which triggers Godot's deferred scene swap — the current scene is freed and `Main` is instantiated fresh.

## `LobbyScreen.tscn` (stub)

Placeholder for a future multiplayer lobby. Not yet wired into any navigation flow. When multiplayer is implemented, `MainMenu` would add a "Multiplayer" button that navigates here, and `LobbyScreen` would call `NetworkManager.host_server()` or `NetworkManager.connect_to_server()`.
