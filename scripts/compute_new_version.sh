#!/bin/env bash

BLUE="\e[34m"
ENDCOLOR="\e[0m"

git fetch origin
LATEST_MAIN_HASH="$(git log origin/main -n 1 --pretty=format:"%H")"
LATEST_MAIN_VERSION="$(git show "$LATEST_MAIN_HASH":dockerfiles/grist/Dockerfile | grep 'ARG GRIST_VERSION=' | sed 's/.*=//' | sed 's/v//')"
LATEST_TAG="$(git tag --sort v:refname | tail -n 1)"
NEW_TAG="$(./scripts/compute_new_version.py "$LATEST_MAIN_VERSION" "$LATEST_TAG")"

echo -e "${BLUE}Dernier commit sur origin/main :${ENDCOLOR} $LATEST_MAIN_HASH"
git log -n 1 "$LATEST_MAIN_HASH"
echo -e "${BLUE}Dernier tag :${ENDCOLOR} $LATEST_TAG"
git log -n 1 "$LATEST_TAG"
echo -e "${BLUE}Version de Grist dans le Dockerfile :${ENDCOLOR} $LATEST_MAIN_VERSION"
echo -e "${BLUE}Tag à créer :${ENDCOLOR} $NEW_TAG"
echo
echo -e "${BLUE}Commandes pour créer le nouveau tag :${ENDCOLOR}"
echo "git tag $NEW_TAG -m '' $LATEST_MAIN_HASH"
echo "git push --tags"
