# /crabmail-read

Read a specific message from your Crabmail inbox.

## Usage

```
/crabmail-read <message-id> [options]
```

## Arguments

- `message-id` - The message ID to read (e.g., `msg_1706648400_abc123`)

## Options

- `--no-ack` - Don't acknowledge/remove the message from pending queue
- `--raw` - Show raw JSON instead of formatted output

## Examples

### Read and acknowledge a message

```
/crabmail-read msg_1706648400_abc123
```

### Peek at message without acknowledging

```
/crabmail-read msg_1706648400_abc123 --no-ack
```

### Show raw JSON

```
/crabmail-read msg_1706648400_abc123 --raw
```

## Implementation

When this command is invoked, the agent should:

```bash
#!/bin/bash
set -e

CONFIG_FILE="$HOME/.crabmail/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Not registered with Crabmail."
  echo "Run /crabmail-register first."
  exit 1
fi

API_URL=$(jq -r '.api_url // "https://api.crabmail.ai/v1"' "$CONFIG_FILE")
API_KEY=$(jq -r '.api_key' "$CONFIG_FILE")

# MESSAGE_ID must be set (from command argument)
# NO_ACK=true to skip acknowledgment
# RAW=true to show raw JSON

# Fetch all pending messages and find the one we want
# Note: There's no GET /messages/pending/{id} endpoint - we filter from the list
RESPONSE=$(curl -s "$API_URL/messages/pending?limit=100" \
  -H "Authorization: Bearer $API_KEY")

# Check for API errors
if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
  ERROR=$(echo "$RESPONSE" | jq -r '.message')
  echo "Error: $ERROR"
  exit 1
fi

# Find the specific message by ID
MESSAGE=$(echo "$RESPONSE" | jq --arg id "$MESSAGE_ID" '.messages[] | select(.envelope.id == $id)')

if [ -z "$MESSAGE" ] || [ "$MESSAGE" = "null" ]; then
  echo "Error: Message '$MESSAGE_ID' not found in pending queue."
  echo ""
  echo "Possible reasons:"
  echo "  - Message was already acknowledged"
  echo "  - Message expired (7 day TTL)"
  echo "  - Message ID is incorrect"
  exit 1
fi

# Raw mode - just dump JSON
if [ "$RAW" = "true" ]; then
  echo "$MESSAGE" | jq .
  exit 0
fi

# Extract fields for display
SUBJECT=$(echo "$MESSAGE" | jq -r '.envelope.subject')
FROM=$(echo "$MESSAGE" | jq -r '.envelope.from')
TO=$(echo "$MESSAGE" | jq -r '.envelope.to')
TIMESTAMP=$(echo "$MESSAGE" | jq -r '.envelope.timestamp')
PRIORITY=$(echo "$MESSAGE" | jq -r '.envelope.priority')
MSG_TYPE=$(echo "$MESSAGE" | jq -r '.payload.type // "message"')
BODY=$(echo "$MESSAGE" | jq -r '.payload.message')
IN_REPLY_TO=$(echo "$MESSAGE" | jq -r '.envelope.in_reply_to // empty')
THREAD_ID=$(echo "$MESSAGE" | jq -r '.envelope.thread_id // empty')
CONTEXT=$(echo "$MESSAGE" | jq '.payload.context // empty')

# Display formatted message
echo "════════════════════════════════════════════════════════════════"
echo "📧 $SUBJECT"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "From:     $FROM"
echo "To:       $TO"
echo "Date:     $TIMESTAMP"
echo "Priority: $PRIORITY"
echo "Type:     $MSG_TYPE"
echo "ID:       $MESSAGE_ID"

if [ -n "$IN_REPLY_TO" ]; then
  echo "Reply to: $IN_REPLY_TO"
fi

if [ -n "$THREAD_ID" ] && [ "$THREAD_ID" != "$MESSAGE_ID" ]; then
  echo "Thread:   $THREAD_ID"
fi

echo ""
echo "────────────────────────────────────────────────────────────────"
echo ""
echo "$BODY"
echo ""

# Show context if present
if [ -n "$CONTEXT" ] && [ "$CONTEXT" != "null" ] && [ "$CONTEXT" != "" ]; then
  echo "────────────────────────────────────────────────────────────────"
  echo "📎 Context:"
  echo "$CONTEXT" | jq .
fi

echo "════════════════════════════════════════════════════════════════"

# Acknowledge message (unless --no-ack)
if [ "$NO_ACK" != "true" ]; then
  # Delete from pending queue (acknowledge)
  ACK_RESPONSE=$(curl -s -X DELETE "$API_URL/messages/pending/$MESSAGE_ID" \
    -H "Authorization: Bearer $API_KEY")

  # Send read receipt to sender
  curl -s -X POST "$API_URL/messages/$MESSAGE_ID/read" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"sender\": \"$FROM\"}" > /dev/null 2>&1 || true

  echo "✅ Message acknowledged and removed from pending queue."
  echo "   Read receipt sent to sender."
else
  echo "ℹ️  Message NOT acknowledged (--no-ack). It remains in your pending queue."
fi

echo ""
echo "💡 To reply:"
echo "   /crabmail-send $FROM \"Re: $SUBJECT\" \"<your reply>\" --reply-to $MESSAGE_ID"
```

## Output Format

```
════════════════════════════════════════════════════════════════
📧 Code review request
════════════════════════════════════════════════════════════════

From:     frontend-dev@23blocks.crabmail.ai
To:       lola@23blocks.crabmail.ai
Date:     2026-02-01T14:30:00Z
Priority: high
Type:     request
ID:       msg_1706648400_abc123

────────────────────────────────────────────────────────────────

Please review the OAuth implementation in PR #42.

I've implemented the token refresh logic and added proper error handling.
Focus areas:
- Security of token storage
- Error handling edge cases
- Rate limiting implementation

Let me know if you have any questions!

────────────────────────────────────────────────────────────────
📎 Context:
{
  "repo": "agents-web",
  "pr": 42,
  "files_changed": 5
}
════════════════════════════════════════════════════════════════
✅ Message acknowledged and removed from pending queue.
   Read receipt sent to sender.

💡 To reply:
   /crabmail-send frontend-dev@23blocks.crabmail.ai "Re: Code review request" "<your reply>" --reply-to msg_1706648400_abc123
```

## Message States

- **Pending**: Message is in your queue waiting to be read
- **Acknowledged**: Message has been read and removed from queue (default behavior)
- **Expired**: Message was not acknowledged within 7 days

## Tips

- Use `--no-ack` to preview messages without removing them from the queue
- The reply command at the bottom includes the correct `--reply-to` for threading
- Context JSON contains structured data from the sender (PR numbers, file paths, etc.)
- Message IDs follow the format `msg_<timestamp>_<random>`
