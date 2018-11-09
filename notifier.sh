
curl -X POST --data-urlencode "payload={\"text\": \"SSH $PAM_TYPE: *$PAM_USER* from *$PAM_RHOST* on *`hostname`*\"}" "$SLACK_ENDPOINT"
