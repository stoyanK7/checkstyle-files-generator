#!/bin/bash
set -e

source ./.ci/util.sh

case $1 in

# Gets PR information (branch, commit_sha) and saves to .ci-temp
get-pr-info)
  checkForVariable "GITHUB_TOKEN"
  checkForVariable "PR_NUMBER"
  mkdir -p .ci-temp

  URL="${GITHUB_API_URL}/repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}"

  curl --fail-with-body -X GET "$URL" \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: token $GITHUB_TOKEN" \
      -o .ci-temp/info.json

  jq .head.ref .ci-temp/info.json > .ci-temp/branch
  jq .head.sha .ci-temp/info.json > .ci-temp/commit_sha

  BRANCH=$(xargs < .ci-temp/branch)
  COMMIT_SHA=$(xargs < .ci-temp/commit_sha | cut -c 1-7)

  ./.ci/append-to-github-output.sh "branch" "$BRANCH"
  ./.ci/append-to-github-output.sh "commit_sha" "$COMMIT_SHA"
  ;;

# Generates the site using Maven
generate-site)
  cd .ci-temp/checkstyle

  CHECKSTYLE_FILES_GENERATOR_VERSION=$(
    ./mvnw --no-transfer-progress --quiet help:evaluate \
      -Dexpression=checkstyle-files-generator.version \
      -DforceStdout
  )

  CHECKSTYLE_FILES_GENERATOR_GROUP_ID=$(
    grep -B 1 '<artifactId>checkstyle-files-generator</artifactId>' pom.xml \
      | head -1 \
      | sed 's/.*<groupId>\(.*\)<\/groupId>.*/\1/'
  )

  cd ../checkstyle-files-generator

  cp pom.xml pom-site.xml

  sed -i \
    "0,/<groupId>.*<\/groupId>/s//<groupId>${CHECKSTYLE_FILES_GENERATOR_GROUP_ID}<\/groupId>/" \
    pom-site.xml

  sed -i \
    "0,/<version>.*<\/version>/s//<version>${CHECKSTYLE_FILES_GENERATOR_VERSION}<\/version>/" \
    pom-site.xml

  ./mvnw -e --no-transfer-progress -f pom-site.xml clean install -DskipTests

  rm pom-site.xml

  cd ../checkstyle
  ./mvnw -e --no-transfer-progress clean site -Pno-validations \
    -Dmaven.javadoc.skip=false -Djdepend.skip=false
  ;;

# Copies the site to AWS S3 bucket and generates the message
publish-site)
  checkForVariable "GITHUB_TOKEN"
  checkForVariable "COMMIT_SHA"
  checkForVariable "PR_NUMBER"
  checkForVariable "AWS_BUCKET_NAME"
  checkForVariable "AWS_REGION"

  TIME=$(date +%Y%m%d%H%M%S)
  FOLDER="${COMMIT_SHA}_$TIME"
  SITE=".ci-temp/checkstyle/target/site"
  LINK="https://${AWS_BUCKET_NAME}.s3.${AWS_REGION}.amazonaws.com"

  aws s3 cp "$SITE" "s3://${AWS_BUCKET_NAME}/$FOLDER/" --recursive
  echo "$LINK/$FOLDER/index.html" > .ci-temp/message

  ./.ci/append-to-github-output.sh "message" "$(cat .ci-temp/message)"
  ;;

*)
  echo "Unexpected argument: $1"
  sleep 5s
  false
  ;;

esac
