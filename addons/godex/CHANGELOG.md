# Changelog

## 1.0.0

- First stable Godex release.
- Standardized all plugin UI, messages, diagnostics, and bundled documentation
  on English for the global release.
- Renamed the plugin from Codex Dock to Godex, including its add-on directory,
  dock labels, internal identifiers, settings file, and distributable archive.
- Preserved compatibility with the previous `user://codex_dock.cfg` settings
  file and `codex-dock-settings` JSON imports.
- Added a comprehensive setup guide covering Codex installation,
  login, executable-path configuration, project permissions, privacy, first
  use, and troubleshooting.

## 0.15.5

- Added a compact **Copy image** action below every loaded generated-image
  preview.
- Copied the original decoded image to the Windows system image clipboard
  through a non-blocking STA helper, with retry handling for temporarily locked
  clipboards and a short success/failure toast.

## 0.15.4

- Changed Enter and the send button while Codex is working to add a visibly
  separate next-turn item instead of immediately steering the active turn and
  rendering it as a normal user message.
- Kept Ctrl+Shift+Enter and the queue icon as explicit queue shortcuts.
- Kept steering available through the queued item's immediate-send action,
  whose tooltip now explains that it appends to the active turn.
- Preserved Shift+Enter and Ctrl+Enter as newline shortcuts while a turn is
  running.

## 0.15.3

- Fixed the remaining editor freeze when restored `imageGeneration` items
  contain multi-megabyte raw Base64 in `result` without a `data:image` prefix.
- Prevented generic image-path regex searches from scanning strings larger
  than 64 KB, removed duplicate recursive traversal, and reused one compiled
  regex per dock instance.
- Recognized raw PNG, JPEG, and WebP results from their short decoded
  signatures, while preferring an existing `savedPath` so history does not
  retain or hash Base64 unnecessarily.
- Sanitized top-level string tool results and command output before storing
  tool-card details.
- Used the full history already returned by `thread/resume` instead of
  immediately downloading and parsing the same history again with
  `thread/read`.
- Kept only compact thread-list summaries in the conversation selector cache.
- Throttled the scene-run button state poll and stopped assigning identical
  icon, text, and tooltip properties on every editor frame.
- Made optional account rate-limit objects type-safe when a login returns
  `null` for the secondary window or credits.

## 0.15.2

- Fixed a second editor stall when enabling the plugin or restoring a
  conversation whose App Server response contains a multi-megabyte image.
- Changed JSONL buffering to scan only newly received bytes instead of
  rescanning an incomplete message from the beginning after every pipe read.
- Limited stdout intake to 512 KB per editor frame and time-budgeted complete
  message processing so large responses do not monopolize the editor loop.
- Avoided an additional full-string whitespace copy for large protocol lines.

## 0.15.1

- Fixed editor startup stalls caused by synchronously decoding large Base64
  images while restoring conversation history.
- Limited tool-result previews to actual image-generation tools and generated
  image items; `imageView`, screenshots, and inspected reference images remain
  ordinary tool results.
- Changed restored images to an explicit **Load preview** action, while newly
  generated images continue to load automatically one at a time after the
  transcript has rendered.
- Bounded the thumbnail cache, reduced oversized thumbnails before upload, and
  replaced large Base64 strings in RichText metadata with compact image tokens.

## 0.15.0

- Added live image-generation cards for image tools, including an in-progress
  state and automatic result extraction from dynamic and MCP tool content.
- Added responsive inline previews for Base64, local-file, `res://`, and
  Markdown images in both live replies and restored conversation history.
- Added click-to-open large previews with save, reveal-in-file-manager, and
  copy-path actions.
- Added compact retry and external-open fallbacks when an image cannot be
  decoded locally.
- Replaced large embedded image payloads in expanded tool details with a small
  size placeholder so Base64 results do not overwhelm the transcript.

## 0.14.0

- Added a local next-turn follow-up queue while Codex is working. Use the queue
  icon or Ctrl+Shift+Enter; Enter continues to steer the active turn.
- Added a compact queue panel with reorder, edit, send-now, and delete actions.
  One queued prompt is started automatically after each completed turn.
- Added per-conversation draft persistence across conversation switches and
  editor restarts.
- Added per-conversation prompt history through the history icon and
  Alt+Up/Alt+Down navigation.
- Persisted drafts, follow-up queues, and prompt history only in Godot's local
  `user://codex_dock.cfg`.

## 0.13.3

- Made the bottom-jump control visible whenever the reader leaves the latest
  transcript position, using the idle label “Jump to latest”.
- Changed the same control to “New content” as soon as a reply arrives while the
  reader remains above the bottom.
- Kept both states centered above the composer and cleared them only after the
  reader returns to the latest position.

## 0.13.2

- Preserved the reader's exact transcript position when a completed turn is
  reloaded from Codex history.
- Kept the “New content” indicator visible across the post-turn history refresh
  instead of resetting the transcript to bottom-following mode.
- Batched history reconstruction into one render to avoid intermediate scroll
  changes while messages and tool cards are restored.

## 0.13.1

- Rebuilt code-block headers as responsive cells so the language label, copy
  action, and file action retain explicit gaps without wrapping into the code.
- Aligned the compact action backgrounds to the neighboring 12 px language
  label instead of filling the full header-row height.
- Verified the header at both 424 px and the dock's 304 px minimum content
  width.

## 0.13.0

- Added smart transcript following: streamed replies only stay pinned when the
  reader is already near the bottom.
- Added a compact “New content” button that preserves the current reading position
  and jumps to the latest response on demand.
- Added a collapsible Codex Plan / Tasks panel backed by
  `turn/plan/updated`, `item/plan/delta`, and authoritative completed plan
  items.
- Added current-conversation search with **Ctrl+F**, Enter/Shift+Enter result
  navigation, and matching-round markers in Round History.

## 0.12.3

- Reduced code-block action labels to 12 px and removed extra pill padding.
- Shortened “Open file” to “Open” and compacted line targets to `L<number>`.
- Reduced spacing between the language label and code actions while retaining
  icon, color, hover tooltip, and nonbreaking behavior.

## 0.12.2

- Added a compact “Copied” toast near the pointer after copying a code block.
- The toast fades automatically after one second and remains independent from
  transcript content, rendering, and scroll state.

## 0.12.1

- Made code-block copy actions silent so they no longer append transcript
  messages, rerender the conversation, or jump to the bottom.
- Deferred project-file opening until after the RichTextLabel click event,
  explicitly selected the target in Godot's FileSystem dock, and switched
  scripts to the Script main screen before focusing the requested line.
- Replaced transcript errors from file-navigation actions with editor warnings
  so failed navigation cannot disturb the current chat scroll position.

## 0.12.0

- Added a compact right-side Round History rail with one marker per
  user/Codex round.
- Added Codex-style hover preview cards containing the request, response
  summary, round number, and tool-step count.
- Added click-to-jump navigation and active-round tracking while scrolling.
- Positioned markers according to each round's relative location in the full
  transcript and kept the rail synchronized during streamed responses.

## 0.11.2

- Replaced per-text code backgrounds with a full-width RichTextLabel table
  cell, eliminating ragged stair-step backgrounds on multiline code blocks.
- Disabled single-column table shrinking so the code card follows the dock
  width responsively.
- Added consistent cell padding and a subtle card border around code blocks.

## 0.11.1

- Compacted code-block action pills with a slightly smaller label size and
  reduced horizontal padding.
- Made each action label nonbreaking so narrow docks wrap between whole
  actions instead of splitting the icon, text, or colored background.

## 0.11.0

- Restyled code-block actions as high-contrast icon-and-text pills so copying
  code and opening file references no longer blend into the block header.
- Rebuilt Diff as a file-and-hunk browser with added, modified, deleted, and
  renamed statuses, target-file navigation, patch copying, and scene testing.
- Added file-level and hunk-level accept tracking.
- Added confirmed safe revert using `git apply --reverse --check` before any
  working-tree change.
- Added a settings and connection-status panel for the Codex executable,
  project permission, synchronized model and reasoning effort, automatic
  reconnect controls, live diagnostics, and recent connection events.
- Added JSON settings import and export.

## 0.10.0

- Added automatic Codex process reconnection with exponential backoff and
  restoration of the active conversation.
- Added clearer protocol diagnostics for unsupported methods, changed
  parameters, malformed JSON, and App Server startup failures.
- Replaced raw streaming text with a live structured Markdown renderer.
- Added code-block actions for copying code and opening or jumping to detected
  project-file references.
- Added collapsible cards for commands, file changes, MCP calls, dynamic tools,
  and web searches.
- Removed the legacy editor-context, image, screenshot, and runtime-log sending
  implementation while retaining old-history display compatibility.
- Reduced the dock minimum width and converted conversation actions to compact
  theme-aware icons with symbol fallbacks.

## 0.9.3

- Replaced the composer controls with a single compact icon toolbar.
- Model, reasoning effort, and Skill now open full option menus from icons;
  current selections are shown in tooltips instead of button text.
- Selecting a Skill now applies it directly to the next message.
- Converted project permission, tools, scene run/stop, Diff, interrupt, and
  send actions to icon-only controls.

## 0.9.2

- Moved the conversation-actions menu into the main conversation row.
- Removed the conversation-title search row.
- Moved archived-conversation browsing into the conversation-actions menu.

## 0.9.1

- Moved project permission, model, reasoning effort, and Skill controls beneath
  the composer to match the Codex interaction pattern.
- Removed the visible editor-context and executable-path/reconnect rows.
- Added manual reconnect to the compact Tools menu while retaining automatic
  Codex discovery and saved-path compatibility.
- Compacted scene run/stop and send/interrupt actions in the composer footer.

## 0.9.0

- Native Codex chat dock and main-toolbar button.
- Live model and reasoning-effort synchronization.
- Persistent conversation history with search, rename, fork, archive, restore,
  and confirmed permanent deletion.
- Scene, node, script, file, image, screenshot, Skill, and runtime-log context.
- Markdown rendering and clickable project-file links.
- Streaming responses, steering, interruption, Diff viewer, and added/deleted
  line counts.
- Command, file-change, and permission approval dialogs.
- Structured user-input forms.
- Current-scene run/stop controls.
- Code review and context-compaction actions.
- Dynamic Skills, MCP inventory, and account-usage display when available.
- Windows, macOS, and Linux executable discovery candidates.
