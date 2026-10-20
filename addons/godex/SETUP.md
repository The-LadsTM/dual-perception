# Godex setup and first use

This guide covers the one-time Codex configuration, Godex installation, first
connection, project permissions, and basic usage.

## 1. Prerequisites

- Godot 4.7.1 or later. Godex is tested with Godot 4.7.1.
- A local Codex installation that supports `codex app-server`.
- A completed Codex login on the same operating-system account that runs
  Godot.
- Git is recommended for checkpoints and is required only for Godex's safe
  Diff revert action.

Godex does not bundle Codex, an OpenAI API key, or a user account.

## 2. Install and authenticate Codex

Install or update Codex using the
[official Codex CLI guide](https://developers.openai.com/codex/cli/). Then run
these checks in a terminal:

```text
codex --version
codex login
codex login status
codex app-server --help
```

Use `codex login` to complete the ChatGPT browser sign-in flow or another
authentication method offered by Codex. If Codex is already signed in,
`codex login status` confirms the active method.

Godex launches `codex app-server --listen stdio://` automatically. The final
command above checks that the installed Codex build provides App Server
support; it is not a server that you must leave running.

Codex credentials belong to Codex and are sensitive. Never add
`~/.codex/auth.json`, an API key, or a copied credential to a Godot project,
repository, issue, screenshot, or Godex settings export.

## 3. Let Godex find the Codex executable

Godex checks `CODEX_PATH`, known installation locations, and the process
`PATH`. If automatic discovery succeeds, no path configuration is needed.

The preferred manual method is:

1. Enable Godex and open **Tools > Settings and connection status**.
2. Paste the absolute `codex.exe` or `codex` path into **Codex path**.
3. Choose **Save and reconnect**.

Alternatively, set `CODEX_PATH` before starting Godot. For the current
PowerShell session on Windows:

```powershell
$env:CODEX_PATH = "C:\full\path\to\codex.exe"
```

For the current shell on macOS or Linux:

```sh
export CODEX_PATH="/full/path/to/codex"
```

Start Godot from that environment, or configure the variable persistently in
your operating system before launching the editor. The path must point to the
executable itself, not only its containing directory.

## 4. Install and enable Godex

1. Extract the release archive at the root of the Godot project. The result
   must be `res://addons/godex/plugin.cfg`.
2. Open **Project > Project Settings > Plugins**.
3. Enable **Godex**.
4. Open the **Godex** dock. If it is hidden, use the **Godex** button in the
   main editor toolbar or **Editor > Editor Docks > Godex**.
5. Wait for the status to show **Connected**. If it does not, open
   **Tools > Settings and connection status**, review the diagnostic text,
   correct the Codex path if necessary, and choose **Save and reconnect**.

For an update, disable Godex, replace `addons/godex`, and enable it again. To
uninstall, disable Godex and remove `addons/godex`.

## 5. Choose project permissions safely

- **Allow changes to this project** lets Codex write only inside the current Godot
  project by default.
- Turn the permission control off for read-only work. Create a new conversation
  after changing this setting because the sandbox choice applies to newly
  created conversations.
- Extra command, file-system, or network access can still produce an approval
  request in the Godex dock. Review the requested scope before allowing it.
- Commit or back up important work before enabling edits. The Diff view helps
  review changes, but it is not a substitute for version control.

## 6. First conversation

1. Confirm that the connection status is **Connected**.
2. Optionally choose a model, reasoning effort, Skill, and project permission
   from the compact toolbar below the composer.
3. Describe the task and include useful project paths or acceptance criteria.
4. Press **Enter** or **Send**. Use **Shift+Enter** or **Ctrl+Enter** for a
   newline.
5. Review permission prompts before approval and inspect edited files with
   **Diff**.
6. Run the current scene with **Run current scene** when the change needs a runtime
   check.
7. Use **New conversation** for an unrelated task. Existing conversations remain
   available in the conversation selector.

Example requests:

```text
Explain how res://player/player.gd handles movement. Do not edit files.

Add coyote time to res://player/player.gd, preserve the current input actions,
and show me the diff before I run the scene.
```

## 7. Local data and privacy

Godex stores its executable path, preferences, drafts, prompt history, and
local queues in Godot's `user://godex.cfg`. They are outside the project and
are not committed with it. A legacy `user://codex_dock.cfg` is read only for
migration.

Requests, selected project context, and approved tool activity are processed
through the user's local Codex installation. Review [PRIVACY.md](PRIVACY.md)
before using Godex with confidential code or sharing it with a team.

## 8. Quick troubleshooting

- `codex --version` fails: install Codex or fix the terminal `PATH`.
- `codex login status` reports no login: run `codex login`.
- `codex app-server --help` fails: update Codex to a build with App Server
  support.
- Godex reports **Codex not found**: set the absolute path in
  **Tools > Settings and connection status** or `CODEX_PATH`, then restart/reconnect.
- The process starts but does not connect: read **Connection and diagnostics**, update Codex,
  and reconnect. App Server is evolving and a newer Godex or Codex release may
  be required.

For authentication details, see the
[official Codex authentication guide](https://developers.openai.com/codex/auth/).
For the transport used by Godex, see the
[official App Server guide](https://developers.openai.com/codex/app-server/).
