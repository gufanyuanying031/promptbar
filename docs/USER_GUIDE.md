# PromptBar user guide

## Install

Download the arm64 ZIP from Releases, extract it, and place the app in Applications. Quit older copies before launching. Requires Apple Silicon; deployment target is macOS 14. Downloads are ad-hoc signed, not notarized, so macOS may block them. Building from reviewed source is an alternative. No automatic update is included.

## Language and API setup

Right-click the capsule → Settings (设置…), or right-click the menu-bar sparkles → Settings. Use the language picker at the top: English / 简体中文. The setting applies immediately and is remembered. The initial language follows the system. Interface language does not translate your prompt.

In Models & API, select a provider, verify its HTTPS base URL, select the protocol, enter the exact model ID and key, then Save. Keys are independent per provider. Save before switching providers. Test connection sends a small potentially billable request. Model availability depends on your provider account.

For DeepSeek, Flash uses `deepseek-flash`; Pro uses `deepseek-v4-pro`. Keep the API ID, not the model's marketing/version display name. Custom endpoints must match one of the three supported protocols.

## Capsule controls

| Area | Action |
| --- | --- |
| Left six dots | Drag to move. Dragging closes the editor; releasing does not reopen it. |
| Middle sparkles | Hover to open; click to enter editing. |
| Right pin | Toggle always-on-top. This does not lock the editor open. |
| Right-click | Settings, library, quit. More actions are available on the editor's context menu. |

The capsule remains a fixed-size independent window. The editor fits above or below it. Only the editor adjusts to screen boundaries.

## Editor controls, left to right

- **Style**: pick a rewriting style. Choosing a different style with nonempty input starts a new request. If an original snapshot exists, it is reused; otherwise the current draft is used. Current-style clicks do not request again.
- **Text**: paste or write the prompt. Hover over an icon to see its small label.
- **Expand text**: open or close the scrollable long-text editor.
- **Clear**: clear current text, snapshots and refinement instructions; history is retained.
- **Paste**: immediately replace the current draft with clipboard text, without a confirmation dialog. A brief checkmark confirms success.
- **Copy**: copy current text; a brief checkmark confirms success.
- **Keep open**: lock the editor open until unlocked.
- **Rightmost sparkles**: optimize. A rotating ring indicates progress; click it to cancel. After success this control restores the original; click again to show the optimized version without a request.

Manual edits start a new draft and clear the original/result toggle snapshots. For another round, right-click → Optimize current text again, or Refine with instructions. Requests can take up to 90 seconds. Failure or cancellation keeps current text.

When the pointer leaves the middle sparkles and editor for about 650 ms, the editor closes with an animation. Locked, optimizing, open-menu and settings states have exceptions. Long-text mode does not force the editor to remain open. Reduce motion disables animated transitions.

**Control + Option + P** opens/closes the editor. **Command + Return** runs the editor action. Shortcuts may conflict with other apps; menu-bar controls remain available.

## Library, privacy and removal

History can be disabled in General. Up to 150 unpinned entries are kept; pinned entries remain. The library supports search, pin/unpin, load, delete, JSON import/export, and clearing unpinned history. Loading another entry asks before replacing the draft. Imports use PromptBar's own format.

History and preferences: `~/Library/Application Support/PromptBar/`. Prompt history is unencrypted local text. Keys: macOS Keychain service `app.promptbar.native.v1`. Export does not include keys. This app has no telemetry or private relay; text and authorization go to your configured API.

To remove: quit the app, remove the app bundle, optionally remove its Application Support directory, and remove its Keychain entries. Removing the app does not revoke a provider's key.

## Troubleshooting

- **Old UI still visible**: quit every old copy before opening the new release.
- **No Dock icon**: expected; this is a menu-bar utility.
- **No API response**: check key, balance, protocol, exact model ID and base URL. Proxy or account availability may affect requests.
- **Style does not run**: empty drafts only change style. Custom style needs instructions. Failed requests preserve the old text.
- **Prompt changed meaning**: restore the original and review the selected style. Model outputs are not guaranteed improvements.
- **Unsaved draft disappeared after quitting**: drafts are session-only; copy important content before quitting.

When filing an issue, include version, macOS version, display setup and reproduction steps. Remove credentials and private prompt text.
