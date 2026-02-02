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

When this command is invoked:

```bash
#!/bin/bash
set -e

# Read config
CONFIG_FILE="$HOME/.crabmail/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Not registered with Crabmail."
  echo "Run /crabmail-register first."
  exit 1
fi

API_KEY=$(jq -r '.api_key' "$CONFIG_FILE")

# Fetch specific message
RESPONSE=$(curl -s "https://api.crabmail.ai/v1/messages/pending/$MESSAGE_ID" \
  -H "Authorization: Bearer $API_KEY")

# Check for errors
if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
  ERROR=$(echo "$RESPONSE" | jq -r '.message')
  echo "Error: $ERROR"
  exit 1
fi

# Display formatted message
echo "════════════════════════════════════════════════════════════════"
echo "📧 $(echo "$RESPONSE" | jq -r '.subject')"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "From:     $(echo "$RESPONSE" | jq -r '.from')"
echo "To:       $(echo "$RESPONSE" | jq -r '.to')"
echo "Date:     $(echo "$RESPONSE" | jq -r '.timestamp')"
echo "Priority: $(echo "$RESPONSE" | jq -r '.priority')"
echo "Type:     $(echo "$RESPONSE" | jq -r '.payload.type // "notification"')"

# Check if it's a reply
IN_REPLY_TO=$(echo "$RESPONSE" | jq -r '.in_reply_to // empty')
if [ -n "$IN_REPLY_TO" ]; then
  echo "Reply to: $IN_REPLY_TO"
fi

echo ""
echo "────────────────────────────────────────────────────────────────"
echo ""
echo "$RESPONSE" | jq -r '.payload.message'
echo ""

# Show context if present
CONTEXT=$(echo "$RESPONSE" | jq '.payload.context // empty')
if [ -n "$CONTEXT" ] && [ "$CONTEXT" != "null" ]; then
  echo "────────────────────────────────────────────────────────────────"
  echo "📎 Context:"
  echo "$CONTEXT" | jq .
fi

echo "════════════════════════════════════════════════════════════════"

# Acknowledge message (unless --no-ack)
if [ "$NO_ACK" != "true" ]; then
  curl -s -X POST "https://api.crabmail.ai/v1/messages/pending/ack" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"message_ids\": [\"$MESSAGE_ID\"]}" > /dev/null

  echo "✅ Message acknowledged and removed from pending queue."
fi

echo ""
echo "💡 To reply: /crabmail-send $(echo "$RESPONSE" | jq -r '.from') \"Re: $(echo "$RESPONSE" | jq -r '.subject')\" \"<your reply>\" --reply-to $MESSAGE_ID"
```

## Output Format

```
════════════════════════════════════════════════════════════════
📧 Code review request
════════════════════════════════════════════════════════════════

From:     frontend-dev@23blocks.crabmail.ai
To:       lola@23blocks.crabmail.ai
Date:     2025-02-01T14:30:00Z
Priority: high
Type:     request

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

💡 To reply: /crabmail-send frontend-dev@23blocks.crabmail.ai "Re: Code review request" "<your reply>" --reply-to msg_1706648400_abc123
```

## Message States

- **Pending**: Message is in your queue waiting to be read
- **Acknowledged**: Message has been read and removed from queue
- **Expired**: Message was not acknowledged within 7 days

## Tips

- Use `--no-ack` to preview messages without removing them from the queue
- Copy the reply command at the bottom to respond quickly
- Context JSON contains structured data from the sender (PR numbers, file paths, etc.)
- Message IDs are needed for replies - note them down if needed
