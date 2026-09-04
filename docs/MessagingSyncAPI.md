# Messaging sync API proposal

The app now treats foreground APNs notifications as the primary refresh trigger and only uses a 60-second active fallback. To remove the remaining fallback full-history download, add cursor-based message sync to both direct and group-chat endpoints.

## Contract

`GET /messages/conversations/:userId/messages?after=<opaqueCursor>&limit=50`

`GET /group-chats/:chatId/messages?after=<opaqueCursor>&limit=50`

For an initial load, omit `after` and return the newest page. Each response returns a stable opaque `next_cursor` that advances past the newest returned change.

```json
{
  "messages": [{ "id": "…" }],
  "next_cursor": "opaque-change-token",
  "has_more_before": true
}
```

When `after` is supplied, return only messages created, edited, or deleted after that token. Include tombstones for deletions so the app can remove a message without fetching history again. Tokens must be monotonic for a single conversation and valid across reconnects.

Also return `ETag` and honour `If-None-Match` with `304 Not Modified`; this is a useful no-payload fallback while cursor sync rolls out.

## Push payloads

Send a silent/background-capable APNs notification for both new direct and group messages:

```json
{
  "type": "direct_message",
  "conversation_user_id": "…",
  "cursor": "opaque-change-token"
}
```

Use `type: "group_chat_message"` with `group_chat_id` for groups. The client refreshes with its locally stored cursor; the push cursor is advisory and lets future clients detect stale or skipped notifications. The user-visible alert remains a separate presentation decision.

## Replies and reaction identities

The message creation endpoints accept an optional `reply_to_id` multipart field:

- `POST /messages`
- `POST /group-chats/:chatId/messages`

The referenced message must belong to that same direct conversation or group
chat. When present, the returned message and future conversation payloads
include a `reply_to` preview with the original message's `id`, `sender_id`,
`sender_display_name`, body, and optional attachment metadata. Deleting an
original message clears the reference instead of preventing deletion.

Reaction summaries should continue to include `emoji`, `count`, and
`reacted_by_current_user`. To let members see who reacted, include the reacting
members under `users` (or `reaction_users`) with `id` and `display_name`:

```json
{
  "emoji": "👍",
  "count": 2,
  "reacted_by_current_user": true,
  "users": [
    { "id": "…", "display_name": "Jordan Lee" },
    { "id": "…", "display_name": "Maya Patel" }
  ]
}
```

## Rollout

1. Ship the server response envelope and ETags while preserving the existing array response for older app versions.
2. The app now stores each open conversation’s cursor and ETag, merges incremental changes by message ID, and removes `is_deleted` tombstones or `deleted_message_ids`.
3. Observe sync payload size, request rate, and missed-message recovery before removing the 60-second fallback.
