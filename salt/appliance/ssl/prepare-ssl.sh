prepare_ssl () {
    # re-generate dhparam.pem if not found or less than 2048 bit
    recreate_dhparam=$(test ! -e /app/etc/dhparam.pem && echo "true" || echo "false")
    if ! $recreate_dhparam; then
        recreate_dhparam=$(test "$(stat -L -c %s /app/etc/dhparam.pem)" -lt 224 && echo "true" || echo "false")
    fi
    if $recreate_dhparam; then
        echo "no or to small dh.param found, regenerating with 2048 bit (takes a few minutes)"
        mkdir -p /app/etc
        openssl dhparam 2048 -out /app/etc/dhparam.pem
    fi
    # certificate setup
    use_snakeoil=true
    domains_file=/app/etc/dehydrated/domains.txt
    if test "${APPLIANCE_SSL_KEY}" != "" -a "${APPLIANCE_SSL_CERT}" != ""; then
        echo "Information: using ssl key,cert supplied from environment"
        printf "%s" "${APPLIANCE_SSL_KEY}" > /app/etc/server.key.pem
        printf "%s" "${APPLIANCE_SSL_CERT}" > /app/etc/server.cert.pem
        cat /app/etc/server.cert.pem /app/etc/dhparam.pem > /app/etc/server.cert.dhparam.pem
        use_snakeoil=false
    else
        if is_truestr "${APPLIANCE_SSL_LETSENCRYPT_ENABLED:-true}"; then
            echo "Information: generate certificates using letsencrypt (dehydrated client)"
            # we need a SAN (subject alternative name) for java ssl :(
            printf "%s" "$APPLIANCE_DOMAIN $APPLIANCE_DOMAIN" > $domains_file
            gosu app dehydrated -c
            if test "$?" -eq 0; then
                use_snakeoil=false
                echo "Information: letsencrypt was successful, using letsencrypt certificate"
            else
                echo "Warning: letsencrypt client (dehydrated) returned an error"
            fi
        fi
    fi
    if is_falsestr "${APPLIANCE_SSL_LETSENCRYPT_ENABLED:-true}"; then
        # delete domains_file to keep cron from retrying to refresh certs
        if test -e $domains_file; then rm $domains_file; fi
    fi
    if $use_snakeoil; then
        echo "Warning: couldnt setup server certificate, copy snakeoil.* to appliance/server*"
        cp /app/etc/snakeoil/ssl-cert-snakeoil.pem /app/etc/server.cert.pem
        cp /app/etc/snakeoil/ssl-cert-snakeoil.key /app/etc/server.key.pem
        cat /app/etc/server.cert.pem /app/etc/dhparam.pem > /app/etc/server.cert.dhparam.pem
    fi
}
