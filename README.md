# Docker Tunneling Service

Docker image based on Alpine with a SSH service usable for tunneling. It's sending an alert through Slack for every connect/disconnect event.

![screenshots.jpg](screenshots.jpg)

--------------------------------------------------------------------------------

### Description

The purpose is to use it as a single entry point in a LAN network and then connect through its tunnel to whatever you need. This means that it should be the only SSH port forwarded through the LAN router.

The built image has 7.67MB so it's pretty lightweight.

--------------------------------------------------------------------------------

### Security

 - an alert is sent to a Slack Incoming WebHook on connect/disconnect
 - the SSH service doesn't provide a TTY
 - any TTY attempt will automatically exit
 - the root password is randomly generated @ build time
 - the `su` binary is removed
 - the username, password & slack endpoint are entered manually @ build time

You could obviously change the image to use a key instead of a password. That would be better but it's not my use case.

--------------------------------------------------------------------------------

### Config

In ```config.sh``` you'll be able to customize a few things. Just follow the comments.

If you wish you can hardcode the username, password and endpoint but I don't recommend it.

```shell
# The name of the docker image
PROJECT_NAME="docker-tunneling-service"

# The hostname of the created image
HOSTNAME="my-tunneling-service"

# The port to which SSH will be mapped on the host machine
SSH_PORT=4321

# Make this available only when buliding
if [ "$1" == "build" ]; then

    # The user you'll use to login
    read -p 'SSH Username: ' SSH_USERNAME
    # SSH_USERNAME="MY-USER"

    # The password you'll use to login
    read -p 'SSH Password: ' -s SSH_PASSWORD;echo
    # SSH_PASSWORD="MY-PASSWORD"

    # The Slack endpoint which will receive the alerts
    read -p 'Slack Endpoint: ' SLACK_ENDPOINT
    # SLACK_ENDPOINT="MY-SLACK-ENDPOINT"
fi
```

--------------------------------------------------------------------------------

### Build

This will require the username, password & slack endpoint and then it will build the docker image:

```shell
bash docker.sh build
```

--------------------------------------------------------------------------------

### Launch

Launch the image:

```shell
bash docker.sh launch
```

--------------------------------------------------------------------------------

### Kill

Kill the currently running docker image:

```shell
bash docker.sh kill
```

--------------------------------------------------------------------------------

### Remove

Remove the already built docker image. It will ask for confirmation.

```shell
bash docker.sh remove
```

--------------------------------------------------------------------------------

### Customize Slack alert

If you want to customize the alert you can simply edit ```notifier.sh```.

Here's its current content:

```shell
curl -X POST --data-urlencode "payload={\"text\": \"SSH $PAM_TYPE: *$PAM_USER* from *$PAM_RHOST* on *`hostname`*\"}" "$SLACK_ENDPOINT"
```
