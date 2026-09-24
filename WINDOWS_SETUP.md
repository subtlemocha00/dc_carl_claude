# WINDOWS SETUP

## Required

### 1. Godot
Install/extract:
- Godot 4.7.2 stable
- Standard build, not .NET, because this project uses GDScript

It is convenient to place it somewhere stable, for example:
`C:\Tools\Godot\`

Optionally rename the executable to:
`godot.exe`

Adding that folder to Windows PATH makes it easier for coding agents to launch/check the project from a terminal.

After changing PATH, restart VS Code/terminal windows.

Verify in PowerShell:
```powershell
godot --version
```

If you do not add Godot to PATH, the project still works, but the coding model may need the full path to the executable to run validation.

### 2. Visual Studio Code
Use VS Code as the main filesystem/editor/agent workspace.

Install the official Godot/GDScript VS Code extension if desired.

Godot can also be configured to open scripts in VS Code:
Editor -> Editor Settings -> Text Editor -> External

Keep the Godot editor open on the same project while working. This gives you the scene editor, inspector, debugger, game runner, and import pipeline while the coding agent edits the repository.

### 3. Git
Install Git for Windows if it is not already installed.

Verify:
```powershell
git --version
```

Configure your identity if needed:
```powershell
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

Do not use the example email literally.

## Recommended local layout

For example:

```text
C:\Users\<you>\Desktop\code\
    carl-donut-codex\
    carl-donut-claude\
    carl-donut-qwen\
```

Each folder is a completely independent repository.

## Initialize each implementation

Inside each project folder:

```powershell
git init
git add .
git commit -m "chore: add shared game specification"
```

Then open only that project's folder in its own VS Code window.

## Fair comparison rule

Give each coding model the same initial files and the same phase prompt.

Do not let one model inspect another model's repository.

After every phase:
- run the game yourself;
- record anything broken or awkward;
- let that model fix its own implementation;
- commit the corrected phase;
- only then start the next phase.
