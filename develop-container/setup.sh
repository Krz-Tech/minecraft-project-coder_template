#!/bin/bash

NAME="mc-develop-container"

# Optional
DISPLAY_NAME="Tech::Playground | 開発環境"
DESCRIPTION="https://github.com/Krz-Tech/minecraft-project"
ICON="/icon/docker.svg"
TAGS="[docker, containers]"

#= = = = = = = = = =
# Scripts
#= = = = = = = = = =

PREFIX="Coder | ${NAME} >>"

PushTemplate () {
    echo "${PREFIX} Pushing template"
    coder templates push -d coder -y $NAME
}

UpdateTemplateMetadata () {
    echo "*" * 10
    echo "${PREFIX} Updating template metadata"
    coder templates edit --display-name "$DISPLAY_NAME" --description "$DESCRIPTION" --icon "$ICON" "$NAME" 
}

PushTemplate
UpdateTemplateMetadata