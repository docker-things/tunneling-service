#!/bin/bash

# Load the config
. config.sh

# Output functions
function showNormal() { echo -e "\033[00m$@"; }
function showGreen() { echo -e "\033[01;32m$@\033[00m"; }
function showYellow() { echo -e "\033[01;33m$@\033[00m"; }
function showRed() { echo -e "\033[01;31m$@\033[00m"; }

# Launch the required action
function scriptRun() {
    case "$1" in
    "build")     scriptBuild    ;;
    "launch")    scriptLaunch   ;;
    "kill")      scriptKill     ;;
    "remove")    scriptRemove   ;;
    *)           showUsage      ;;
    esac
}

# Show script usage
function showUsage() {
    showNormal "\nUsage: bash $0 [build|launch|kill|remove]\n"
    exit 1
}

# Build the docker image, pull the GIT repository and pull the DB from master
function scriptBuild() {

    # Check if DOCKER is installed
    command -v docker >/dev/null 2>&1 || {
        showRed "\n[ERROR] You need docker installed to run this. Here's how to install it:" \
                "\n        https://docs.docker.com/install/\n"
        exit 1
    }

    # Mark start time
    startTime="`date +"%Y-%m-%d %H:%M:%S"`"

    # Build the image
    showGreen "\n > Building image..."
    sudo docker build \
        --build-arg SSH_HOSTNAME="$SSH_HOSTNAME" \
        --build-arg SSH_USERNAME="$SSH_USERNAME" \
        --build-arg SSH_PASSWORD="$SSH_PASSWORD" \
        --build-arg SLACK_ENDPOINT="$SLACK_ENDPOINT" \
        -t "$PROJECT_NAME" .

    # Exit if the bulid failed
    if [ $? -eq 1 ]; then
        showRed "\n[ERROR] Build failed!\n"
        exit 1
    fi

    # Get the images list
    imagesList="`sudo docker images`"

    # Exit if the image doesn't exist
    if [ "`echo -e "$imagesList" | grep "$PROJECT_NAME"`" == "" ]; then
        showRed "\n[ERROR] Build failed! Available images:\n"
        showNormal "$imagesList"
        exit 1
    fi

    # Remove unused parts
    showGreen "\n > Removing unused parts..."
    sudo docker system prune -f

    # Show result
    showGreen "\n > Built image:"
    showNormal "$imagesList" | grep "REPOSITORY"
    showNormal "$imagesList" | grep "$PROJECT_NAME"

    # Show duration
    showGreen "\n > Build time:"
    showNormal "Start: $startTime"
    showNormal "End:   `date +"%Y-%m-%d %H:%M:%S"`"

    # Done
    showGreen "\n > Done. Run the following command to launch the image:\n"
    showNormal "bash $0 launch\n"
    exit 0
}

# Launch the docker image
function scriptLaunch() {
    showGreen "\nLaunching $PROJECT_NAME..."
    sudo docker run \
        -h "$SSH_HOSTNAME" \
        -p $SSH_PORT:22 \
        -it \
        --rm "$PROJECT_NAME"
    exit $?
}

# Remove the docker image
function scriptRemove() {

    # Remove docker image
    showRed "\n[WARN] Remove the \"$PROJECT_NAME\" docker image from your system?\n"
    read -p "[y/n] " -n 1 -r
    echo

    # Remove the image
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        showYellow "\n > Removing existing image..."
        sudo docker rmi "$PROJECT_NAME"

        showYellow "\n > Removing unused parts..."
        sudo docker system prune -f

        showGreen "\n > DONE"
    fi

    echo
    exit 0
}

# Kill the running docker image
function scriptKill() {
    showYellow "\nKill $PROJECT_NAME image..."
    sudo docker kill "`sudo docker ps | grep "$PROJECT_NAME" | awk -F'/' '{print $5}' | awk '{print $2}'`"
    exit $?
}

scriptRun "$1"
