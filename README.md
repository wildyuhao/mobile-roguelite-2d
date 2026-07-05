# Fuji Xingzhe

Mobile 2D survivor roguelite built with Godot 4 and GDScript.

## Local Setup

Set a Godot executable path before running commands:

```powershell
$env:GODOT_BIN = "C:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe"
& $env:GODOT_BIN --version
```

Run all headless tests:

```powershell
& $env:GODOT_BIN --headless --path . -s res://tests/run_all_tests.gd
```
