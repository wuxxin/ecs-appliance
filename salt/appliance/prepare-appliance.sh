#!/bin/bash

. /usr/local/etc/env.include
. /usr/local/etc/appliance.include

appliance_status_starting
# enable and start nginx (may be disabled by devupate.sh if on the same machine)
systemctl enable nginx
systemctl start nginx

# read userdata
userdata_yaml=$(get_userdata)
if test $? -ne 0; then
    appliance_exit "Appliance Error" "$(printf "Error reading userdata: %s" `echo "$userdata_yaml"| grep USERDATA_ERR`)"
fi
echo -n "found user-data type: "
printf '%s' "$userdata_yaml" | grep USERDATA_TYPE
echo "write userdata to /app/active-env.yml"
printf "%s" "$userdata_yaml" > /app/active-env.yml

# export active yaml into environment
ENV_YML=/app/active-env.yml update_env_from_userdata ecs,appliance
if test $? -ne 0; then
    appliance_exit "Appliance Error" "Could not activate userdata environment"
fi

# check if standby is true
if is_truestr "$APPLIANCE_STANDBY"; then
    appliance_exit_standby
fi

# storage setup
need_storage_setup=false
if test ! -d "/volatile/ecs-cache"; then
    echo "warning: cloud not find directory ecs-cache on /volatile"
    need_storage_setup=true
fi
if test ! -d "/data/ecs-storage-vault"; then
    echo "warning: could not find directory ecs-storage-vault on /data"
    need_storage_setup=true
fi
if test "$(findmnt -S "LABEL=ecs-volatile" -f -l -n -o "TARGET")" = ""; then
    if is_falsestr "$APPLIANCE_STORAGE_IGNORE_VOLATILE"; then
        echo "warning: could not find mount for ecs-volatile filesystem"
        need_storage_setup=true
    fi
fi
if test "$(findmnt -S "LABEL=ecs-data" -f -l -n -o "TARGET")" = ""; then
    if is_falsestr "$APPLIANCE_STORAGE_IGNORE_DATA"; then
        echo "warning: could not find mount for ecs-data filesystem"
        need_storage_setup=true
    fi
fi
if $need_storage_setup; then
    echo "calling appliance.storage setup"
    salt-call state.sls appliance.storage
    err=$?
    if test "$err" -ne 0; then
        appliance_exit "Appliance Error" "Storage Setup: Error, appliance.storage setup failed with error: $err"
    fi
fi

# postgres database check
gosu postgres psql -lqt | cut -d \| -f 1 | grep -qw ecs
if test $? -ne 0; then
    appliance_exit "Appliance Standby" "Appliance is in standby, no postgresql database named ecs"
fi

# https certificate setup
if is_truestr "${APPLIANCE_SSL_LETSENCRYPT_ENABLED:-true}"; then
    # generate certificates using letsencrypt (dehydrated client)
    domains_file=/etc/appliance/dehydrated/domains.txt
    if test -e $domains_file; then rm $domains_file; fi
    for domain in $APPLIANCE_HOST_NAMES; do
        printf "%s" "$domain" >> $domains_file
    done
    dehydrated -c
    echo "FIXME: currently > 1 domains overwrites other domains, last wins"
    for domain in $APPLIANCE_HOST_NAMES; do
        ln -sf /etc/appliance/server.key.pem /etc/appliance/dehydrated/certs/$domain/privkey.pem
        ln -sf /etc/appliance/server.cert.pem /etc/appliance/dehydrated/certs/$domain/fullchain.pem
    done
else
    echo "warning: letsencrypt disabled, symlink snakeoil.* to appliance/server*"
    ln -sf /etc/appliance/server.cert.pem /etc/ssl/certs/ssl-cert-snakeoil.pem
    ln -sf /etc/appliance/server.key.pem /etc/ssl/private/ssl-cert-snakeoil.key
fi

# export vault keys
printf "%s" "$APPLIANCE_VAULT_ENCRYPT" > /etc/appliance/storagevault_encrypt.sec
printf "%s" "$APPLIANCE_VAULT_SIGN" > /etc/appliance/storagevault_sign.sec

# create ready to use /root/.gpg for duply
if test -d /root/.gpg; then rm -r /root/.gpg; fi
mkdir -p /root/.gpg
printf "%s" "$APPLIANCE_BACKUP_ENCRYPT" > /root/.gpg/backup_encrypt.sec
chmod -R 0600 /root/.gpg/
gpg --homedir /root/.gpg --batch --yes --import /root/.gpg/backup_encrypt.sec

# reload postfix with keys
echo "fixme: postfix: rewrite authorative_domain, ssl certs, restart postfix"

# re-generate dhparam.pem if not found or less than 2048 bit
recreate_dhparam=$(test ! -e /etc/appliance/dhparam.pem && echo "true" || echo "false")
if ! $recreate_dhparam; then
    recreate_dhparam=$(test "$(stat -L -c %s /etc/appliance/dhparam.pem)" -lt 224 && echo "true" || echo "false")
fi
if $recreate_dhparam; then
    echo "no or to small dh.param found, regenerating with 2048 bit (takes a few minutes)"
    mkdir -p /etc/appliance
    openssl dhparam 2048 -out /etc/appliance/dhparam.pem
fi

# reload nginx with new identity
cat /etc/appliance/template.identity |
    sed -re "s/##domains##/$APPLIANCE_HOST_NAMES/g" > /etc/appliance/server.identity
systemctl reload-or-restart nginx

# update all packages
appliance_status "Appliance Update" "Update system packages"
echo "fixme: update all packages"
appliance_status_starting
