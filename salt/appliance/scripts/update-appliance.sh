#!/bin/bash

APPLIANCE_GIT_BRANCH=${APPLIANCE_GIT_BRANCH:-master}

is_cleanrepo(){
    repo="${1:-.}"
    if ! git -C $repo diff-files --quiet --ignore-submodules --; then
        echo "Error: abort, your working directory is not clean."
        git  -C $repo --no-pager diff-files --name-status -r --ignore-submodules --
        return 1
    fi
    if ! git -C $repo diff-index --cached --quiet HEAD --ignore-submodules --; then
        echo "Error: abort, you have cached/staged changes"
        git -C $repo --no-pager diff-index --cached --name-status -r --ignore-submodules HEAD --
        return 1
    fi
    if test "$(git -C $repo ls-files --other --exclude-standard --directory)" != ""; then
        echo "Error: abort, working directory has extra files"
        git -C $repo --no-pager ls-files --other --exclude-standard --directory
        return 1
    fi
    if test "$(git -C $repo log --branches --not --remotes --pretty=format:'%H')" != ""; then
        echo "Error: abort, there are unpushed changes"
        git -C $repo --no-pager log --branches --not --remotes --pretty=oneline
        return 1
    fi
    return 0
}

. /usr/local/etc/appliance.include

appliance_status "Appliance Update" "Updating appliance"
cd /app/appliance

# fetch all updates from origin
gosu app git fetch -a -p

# set target to latest branch commit id
target=$(gosu app git rev-parse origin/$APPLIANCE_GIT_BRANCH)

# get current running commit id
last_running=$(gosu app git rev-parse HEAD)
appliance_status "Appliance Update" "Updating appliance from $last_running to $target"

if test is_cleanrepo -eq 0; then
    gosu app git checkout -f $APPLIANCE_GIT_BRANCH
    gosu app git reset --hard origin/$APPLIANCE_GIT_BRANCH
else
    appliance_exit "Appliance Error" "Error: /app/appliance not clean, can not update"
fi

salt-call state.highstate pillar='{"appliance": {"enabled": true}}'

appliance_status "Appliance Update" "Restarting appliance"
systemctl restart appliance
