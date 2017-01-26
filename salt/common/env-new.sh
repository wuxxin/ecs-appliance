#!/bin/bash
realpath=`dirname $(readlink -e "$0")`
appuser=$USER
template="salt://common/env-template.yml"
minion="--config-dir $(readlink -f $realpath/../minion)"
fileroot="$(readlink -f $realpath/../)"
pillarroot="$(readlink -f $realpath/../../pillar)"
extra_env=""

if test "$1" = "--template"; then
    template=$(readlink -f "$2")
    shift 2
fi
if test "$1" = "--extra"; then
    extra_env=$(readlink -f "$2")
    shift 2
fi

if test -z "$2"; then
    cat << EOF
Usage: $0 [--template custom-template]
          [--extra additional-yaml-env]
          domain targetdir [optional salt-call parameter]
EOF
    exit 1
fi

domain=$1
targetdir=$(readlink -f "$2")
shift 2

sudo -- salt-call --local --file-root $fileroot --pillar-root $pillarroot $minion state.sls common.env-gen pillar="{ \
    \"domain\": \"$domain\", \
    \"template\": \"$template\", \
    \"extra_env\": \"$extra_env\", \
    \"targetdir\": \"$targetdir\", \
    \"appuser\": \"$appuser\" }" "$@"
