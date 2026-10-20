# Privacy and permissions

Godex starts the user's local Codex App Server and uses the Codex account
already configured on that machine. It does not bundle an API key or a separate
analytics service.

Messages and explicitly selected Skill metadata can be sent by Codex to the
service configured by the local Codex installation. Codex can also inspect or
modify files in the current project when the active permission mode allows it.
The dock does not automatically attach editor selections, screenshots, or
runtime logs to messages.

The default writable sandbox is limited to the current Godot project. Requests
for additional command, file-system, or network access are shown in a Godot
confirmation dialog. A session grant lasts until Godex reconnects or the
plugin stops.

Conversation history is persisted by the local Codex installation. Deleting a
conversation uses the App Server's permanent delete operation and cannot be
undone. Archiving is reversible.

Unsent drafts, next-turn follow-up queues, and local prompt history are stored
in Godot's local `user://godex.cfg`. They are not sent merely because they
are saved locally. A queued follow-up is sent automatically after the current
turn finishes unless the user edits or deletes it first.

Generated-image previews are decoded and displayed locally from content already
returned by Codex. The plugin does not silently download remote image URLs.
Saving an inline image writes it only to the location explicitly selected by
the user.
