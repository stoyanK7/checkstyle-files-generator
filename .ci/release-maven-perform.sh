#!/usr/bin/env bash

set -euo pipefail

source ./.ci/util.sh

if [[ -z $1 ]]; then
  echo "version is not set"
  echo "Usage: $0 <version>"
  exit 1
fi

checkForVariable "GITHUB_REPOSITORY"

TARGET_VERSION=$1
ARTIFACT_ID=$(getMavenProperty project.artifactId)
TAG="${ARTIFACT_ID}-${TARGET_VERSION}"

echo TARGET_VERSION="$TARGET_VERSION"
echo TAG="$TAG"

git checkout "$TAG"

echo "Publishing $TAG to Maven Central ..."

./mvnw \
  -e \
  --no-transfer-progress \
  --batch-mode \
  release:perform \
  -DconnectionUrl="scm:git:https://github.com/${GITHUB_REPOSITORY}.git" \
  -Dtag="$TAG"
