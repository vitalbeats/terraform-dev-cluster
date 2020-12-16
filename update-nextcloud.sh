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
git checkout -b update-nextcloud-${VERSION} ${REMOTE}/master
git reset --hard ${REMOTE}/master
sed -i "s#nextcloud:.*#nextcloud:${VERSION}#" nextcloud/deployments.yaml
terraform apply -auto-approve
git add nextcloud/deployments.yaml
git commit -m "Update to NEXTCloud ${VERSION}"
git push ${REMOTE} master
git checkout ${CURRENT_BRANCH}
git branch -d update-nextcloud-${VERSION}
git stash apply