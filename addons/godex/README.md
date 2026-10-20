# Godex

Godex adds a native chat panel to the Godot editor and connects it to the
local Codex App Server over a JSONL stdio pipe.

> **Unofficial integration:** Godex is an independent community plugin.
> It is not affiliated with or endorsed by OpenAI or the Godot Engine project.
> Codex, OpenAI, Godot, and their respective marks belong to their owners.

## Requirements

- Godot 4.7.1 (tested). Older Godot 4 releases may not expose all editor APIs
  used by the plugin.
- A local Codex installation that supports `codex app-server`.
- A working login in that local Codex installation.

No API key is bundled or stored by the plugin.

## First-time setup

1. Install Codex by following the
   [official Codex CLI guide](https://developers.openai.com/codex/cli/).
2. Open a terminal and verify the local installation:

   ```text
   codex --version
   codex login
   codex login status
   codex app-server --help
   ```

   `codex login` completes authentication in Codex. Godex reuses that local
   login and does not need a separate API key. You normally do not need to
   start `codex app-server` yourself; Godex starts it over JSONL stdio.
3. Install and enable Godex using the steps below. Open
   **Tools > Settings and connection status** to review the Codex path, project permission,
   model, reasoning effort, and connection diagnostics.
4. If Codex is not found automatically, enter the absolute executable path in
   **Codex path** and choose **Save and reconnect**, or set `CODEX_PATH` before starting
   Godot.
5. Start with a version-controlled project and make a commit or other backup
   before allowing edits. Git is optional for chat, but required by Godex's
   safe Diff revert action.

Detailed setup and first-use instructions are available in [SETUP.md](SETUP.md).
See the
[official authentication guide](https://developers.openai.com/codex/auth/) if
the login check fails.

## Installation

1. Copy the `godex` folder into your project as `res://addons/godex`.
2. Open **Project > Project Settings > Plugins**.
3. Enable **Godex**.
4. If automatic discovery does not find Codex, set the `CODEX_PATH`
   environment variable to the executable's absolute path before starting
   Godot.

To update, replace the plugin folder while it is disabled, then enable it
again. To remove it, disable the plugin and delete `addons/godex`.

## Usage

1. Enable **Godex** in **Project > Project Settings > Plugins**.
2. The dock tries to locate the local Codex executable automatically.
3. If discovery fails, set `CODEX_PATH` to `codex.exe` (or `codex`), restart
   Godot, then use **Tools > Reconnect Codex** if needed.
4. Type a request and press **Enter** or **Send**. Use **Shift+Enter** or
   **Ctrl+Enter** to insert a newline.
5. Use the conversation dropdown to reopen this project's recent chats.
   **New conversation** starts another chat without discarding the previous one.
6. **Delete** permanently removes the selected chat after a confirmation prompt.
7. A compact icon toolbar beneath the composer contains project permission,
   model, reasoning effort, Skill, tools, scene run/stop, Diff, and send/stop
   controls. Hover an icon to see its current state.
8. Choose **Follow Codex configuration** to inherit Codex's current default, or select an
   explicit model. The reasoning-effort dropdown follows the selected model's
   current capability list.
9. Open the Skill icon and select a Skill to use its `$skill` marker and native
   Skill metadata in the next message.
10. When Godex needs extra command, file-system, or network permission, review
    the request in Godot and allow it once, for the current session, or reject
    it. Structured follow-up questions also appear inside the dock.
11. After Godex edits files, use **Diff** to browse changes grouped by file and
    hunk. Added, modified, deleted, and renamed files are labeled separately.
    Select an entry to copy its patch, open the target file and line, mark the
    change accepted, or safely revert it after confirmation. Revert first runs
    a reverse-patch check and leaves the project untouched if the check fails.
12. Use **Run current scene** in the Diff window, or the compact **▶/■** action
    beneath the composer, to test the edited scene.
13. Use **Conversation actions** beside the conversation selector to rename, fork,
    archive, restore, or open the archived-conversation list.
14. Use **Tools** to review uncommitted changes, compact a long conversation,
    inspect MCP servers and tools, reconnect the local Codex process, or open
    **Settings and connection status**.
15. Account usage is shown beside the connection status when the current Codex
    login exposes rate-limit data.
16. Markdown is rendered while Godex streams. Code blocks expose copy and
    project-file navigation actions when a path can be detected.
17. Commands, file changes, MCP calls, dynamic tools, and web searches appear
    as collapsible status cards.
18. **Settings and connection status** exposes the Codex executable, project permission,
    synchronized model and reasoning effort, automatic reconnect controls,
    live diagnostics, recent connection events, and JSON import/export.
19. The right-side **Round History** rail maps each user/Godex round to a
    compact horizontal marker. Hover a marker to preview the request, response,
    and tool-step count; click it to jump to that round. The active marker
    follows transcript scrolling.
20. While reading earlier messages, new streamed content no longer forces the
    transcript to the bottom. Leaving the bottom shows **Jump to latest**; if a reply
    then arrives, it changes to **New content**. Use the button to return to the
    latest response. The reading position and indicator remain intact when the
    completed turn is synchronized back from Codex history.
21. Godex plans appear above the transcript as a collapsible task panel with
    pending, in-progress, and completed states. Plan-mode text is also handled
    when the App Server does not provide structured task states.
22. Press **Ctrl+F** inside the dock to search the current conversation.
    **Enter** and **Shift+Enter** move between matching rounds; Round History
    marks every matching round.
23. While Godex is working, **Enter**, the send button,
    **Ctrl+Shift+Enter**, and the queue icon save a follow-up for the next
    turn. Queued prompts appear above the composer and can be reordered,
    edited, deleted, or explicitly sent immediately to steer the active turn.
24. Unsent drafts are saved separately for each conversation. Use
    **Alt+Up/Alt+Down** or the history icon to recall prompts previously sent in
    the current conversation.
25. Ask Godex to generate an image, or include **$imagegen** explicitly.
    Image-generation tools show a live status card and render the finished
    result directly in the conversation. Click a thumbnail for a large preview;
    use the compact actions to copy the image, save it, reveal a local file, or
    copy its path.
    Generated images remain available when the conversation is reopened;
    historical images use **Load preview** so large conversations never decode every
    image while the editor is starting.

If the local Codex process exits unexpectedly, the dock reconnects with
exponential backoff and restores the active conversation after synchronization.
Large App Server responses, including conversations with embedded generated
images, are read incrementally across editor frames. Raw Base64 image results
are handled only by the image-generation path and are never searched as
ordinary text for file links.

If the dock is closed or hidden, click the **Godex** button in the main editor
toolbar. You can also reopen it from **Editor > Editor Docks > Godex**.

The default mode allows writes only inside this Godot project. Turn off
**Allow changes** beneath the composer and create a new conversation for read-only
mode.

The executable path, permission preference, model, reasoning effort, reconnect
preferences, conversation drafts, local follow-up queues, and prompt history
are stored under `user://` and are not committed with the project. Exported
JSON settings are written only to the location selected by the user.

## Sharing and licensing

The plugin is licensed under the [MIT License](LICENSE). You may share,
modify, and redistribute it as long as the copyright and license notice remain
included. A distributable archive should contain the top-level `addons` folder
so users can merge it directly into a Godot project.

See [PRIVACY.md](PRIVACY.md) before distributing the plugin to a team. It
explains which selected project context can be sent through the user's local
Codex installation and how permission prompts work.

## Troubleshooting

- **The dock does not appear:** disable and re-enable **Godex**, or restart the
  Godot editor. Reopen it with the top toolbar **Godex** button or
  **Editor > Editor Docks > Godex**.
- **Codex cannot be found:** run `codex --version` in a terminal, set
  `CODEX_PATH` to the resolved executable, and restart Godot. Automatic path
  discovery is best-effort on Windows, macOS, and Linux.
- **Connection or protocol error:** update the local Codex installation and
  use **Tools > Reconnect Codex**. The App Server protocol is still evolving.
- **Model or Skill list looks stale:** reconnect Codex; both lists are
  resynchronized automatically.
- **Usage shows `--`:** the current login mode or App Server build did not
  expose ChatGPT rate-limit data; chat and other features still work.
- **A restored archive briefly reports an error:** some App Server builds move
  the file successfully but fail their immediate reread. The dock automatically
  resynchronizes and retries the restored conversation.

## Current limitations

- Codex App Server is experimental and its protocol may change.
- Clickable file links are restricted to resources inside the current Godot
  project.
- Approval dialogs expose the App Server's requested scope. Session grants last
  until this plugin's Codex process is reconnected or stopped.
- Diff reverts require a local `git` executable. The safety check rejects a
  patch when the selected file or hunk no longer matches the working tree.
- Archiving a parent conversation can also archive its forked descendants,
  following Codex App Server behavior.
- Some login modes or App Server builds do not return account rate-limit data;
  the usage indicator remains `--` without blocking chat.
- The dock starts a fresh Codex process when the plugin loads or reconnects.
- Base64 and local PNG, JPEG, WebP, SVG, BMP, and TGA image results are previewed
  inside the dock. Remote image URLs use an external-open fallback instead of
  being downloaded silently by the plugin.
- **Copy image** writes a loaded preview to the Windows image clipboard without
  blocking the Godot editor. Other desktop platforms currently show an
  unsupported-platform toast.
