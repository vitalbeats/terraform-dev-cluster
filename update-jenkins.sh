#!/bin/sh

VERSION=$1
REMOTE=${2:-origin}

if [ "${VERSION}x" = "x" ]; then
    >&2 echo "No version specified, exiting."
    exit 1
fi

CURRENT_BRANCH=$(git branch --show-current)
git fetch --all
git stash
git checkout -b update-jenkins-${VERSION} ${REMOTE}/master
git reset --hard ${REMOTE}/master
sed -i "s#jenkins/jenkins:.*#jenkins/jenkins:${VERSION}#" jenkins/deployments.yaml
terraform apply -auto-approve
git add jenkins/deployments.yaml
git commit -m "Update to Jenkins ${VERSION}"
git push ${REMOTE} master
git checkout ${CURRENT_BRANCH}
git stash apply