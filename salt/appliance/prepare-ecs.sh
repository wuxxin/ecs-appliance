#!/bin/bash

update=false
if test "$1" = "--update"; then update=true; fi
target="invalid"
ECS_GIT_BRANCH=${ECS_GIT_BRANCH:-master}
ECS_GIT_SOURCE=${ECS_GIT_SOURCE:-https://github.com/ethikkom/ecs.git}
ECS_DATABASE=ecs

. /usr/local/etc/appliance.include
. /usr/local/etc/env.include

noupdate_status()
{
    if $update; then
        appliance_status "$1" "$2"
    else
        echo "INFO: muted (did not update) appliance status: $1 : $2"
    fi
}
noupdate_exit()
{
    if $update; then appliance_exit "$1" "$2"; else exit 1; fi
}
noupdate_exit_standby()
{
    if $update; then appliance_exit_standby; else exit 1; fi
}

if $update; then
    noupdate_status "Appliance Update" "Starting ecs update"
else
    noupdate_status "Appliance Startup" "Starting ecs"
fi

# export active yaml into environment
if test ! -e /app/active-env.yml; then
    noupdate_exit "Appliance Error" "No /app/active-env.yml, did you run prepare_appliance ?"
fi
ENV_YML=/app/active-env.yml update_env_from_userdata ecs,appliance
if test $? -ne 0; then
    noupdate_exit "Appliance Error" "Could not activate userdata environment"
fi

# check if standby is true
if is_truestr "$APPLIANCE_STANDBY"; then
    noupdate_exit_standby
fi

# get target commit hash
if test -e /app/bin/devupdate.sh; then
    target="devserver"
elif test "$ECS_GIT_COMMITID" != ""; then
    target="$ECS_GIT_COMMITID"
fi

# clone source if currently not existing
if test ! -e /app/ecs/ecs/settings.py; then
    gosu app git clone --branch $ECS_GIT_BRANCH $ECS_GIT_SOURCE /app/ecs
fi

# fetch all updates from origin, except if devserver
if test "$target" != "devserver"; then
    gosu app git -C /app/ecs fetch -a -p
fi

# if target still invalid, set target to latest branch commit
if test "$target" = "invalid"; then
    target=$(gosu app git -C /app/ecs rev-parse origin/$ECS_GIT_BRANCH)
fi

# get last_running commit hash
if test -e /etc/appliance/last_running_commitid; then
    last_running=$(cat /etc/appliance/last_running_commitid || echo "invalid")
else
    last_running="invalid"
fi

if test $target = "devserver"; then
    need_migration=false
else
    if test "$last_running" = "invalid"; then
        need_migration=true
    else
        need_migration=$(gosu app git -C /app/ecs diff --name-status $last_running..origin/$target |
            grep -q "^A.*/migrations/" && echo true || echo false)
    fi
fi

cd /etc/appliance/compose
appliance_status "Appliance Update" "Building ecs"
docker-compose pull --ignore-pull-failures
docker-compose build --pull

appliance_status "Appliance Update" "Updating ecs"
docker-compose stop

if $need_migration; then

    dbdump=/data/ecs-pgdump/${ECS_DATABASE}-migrate.pgdump
    if gosu app pg_dump --encoding="utf-8" --format=custom -Z6 -f ${dbdump}.new -d $ECS_DATABASE; then
        mv ${dbdump}.new ${dbdump}
    else
        appliance_exit "Appliance Error" "Could not pgdump database $ECS_DATABASE before starting migration"
    fi
    appliance_status "Appliance Update" "Migrating ecs database"
    docker-compose run ecs.web --name ecs.migration --no-deps migrate
    err=$?
    if test $err -ne 0; then
        appliance_exit "Appliance Error" "Migration Error"
    fi
fi

# save next about to be executed commitid
printf "%s" "$target" > /etc/appliance/last_running_commitid
