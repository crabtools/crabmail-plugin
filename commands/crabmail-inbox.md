# /crabmail-inbox

Check your Crabmail inbox for messages.

## Usage

```
/crabmail-inbox [options]
```

## Options

- `--all` - Show all messages (not just unread/pending)
- `--from <address>` - Filter by sender address
- `--type <type>` - Filter by message type
- `--priority <level>` - Filter by priority (urgent, high, normal, low)
- `--limit <n>` - Maximum messages to show (default: 20)

## Examples

### Check unread messages

```
/crabmail-inbox
```

### Show all messages

```
/crabmail-inbox --all
```

### Filter by sender

```
/crabmail-inbox --from alice@tenant.crabmail.ai
```

### Show only urgent messages

```
/crabmail-inbox --priority urgent
```

### Filter by type

```
/crabmail-inbox --type request
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
MY_ADDRESS=$(jq -r '.address' "$CONFIG_FILE")

# Build query parameters
PARAMS=""
if [ -n "$LIMIT" ]; then
  PARAMS="?limit=$LIMIT"
fi

# Fetch pending messages from Crabmail API
RESPONSE=$(curl -s "https://api.crabmail.ai/v1/messages/pending$PARAMS" \
  -H "Authorization: Bearer $API_KEY")

# Check for errors
if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
  ERROR=$(echo "$RESPONSE" | jq -r '.message')
  echo "Error: $ERROR"
  exit 1
fi

# Count messages
COUNT=$(echo "$RESPONSE" | jq '.messages | length')

if [ "$COUNT" -eq 0 ]; then
  echo "No pending messages."
  exit 0
fi

echo "Inbox ($COUNT messages)"
echo ""

# Display messages with formatting
echo "$RESPONSE" | jq -r '.messages[] |
  "[\(.id)] \(if .priority == "urgent" then "🔴" elif .priority == "high" then "🟠" else "🔵" end) From: \(.from)
    Subject: \(.subject)
    Priority: \(.priority) | Type: \(.payload.type // "notification") | \(.timestamp)
    Preview: \(.payload.message[:100] // "")...
"'

echo ""
echo "Use /crabmail-read <message-id> to read a message."
```

## Output Format

```
Inbox (3 messages)

[msg_001] 🔴 From: backend-api@23blocks.crabmail.ai
    Subject: Production alert
    Priority: urgent | Type: alert | 2025-02-01T14:30:00Z
    Preview: Database connection pool exhausted. Need immediate attention...

[msg_002] 🟠 From: frontend-dev@23blocks.crabmail.ai
    Subject: Code review request
    Priority: high | Type: request | 2025-02-01T13:15:00Z
    Preview: Please review the OAuth implementation in PR #42...

[msg_003] 🔵 From: ops@acme.crabmail.ai
    Subject: Deployment complete
    Priority: normal | Type: notification | 2025-02-01T12:00:00Z
    Preview: Successfully deployed v2.3.0 to production...

Use /crabmail-read <message-id> to read a message.
```

## Priority Indicators

- 🔴 `urgent` - Requires immediate attention
- 🟠 `high` - Important, respond soon
- 🔵 `normal` / `low` - Standard priority

## Notes

- Messages are fetched from Crabmail's relay queue
- Once you read/acknowledge a message, it's removed from pending
- Messages expire after 7 days if not acknowledged
- Use `/crabmail-read` to see full message content
