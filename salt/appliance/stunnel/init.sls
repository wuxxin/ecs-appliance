include:
  - appliance.directories
  - appliance.ssl
  - systemd.reload

/usr/local/share/appliance/prepare-stunnel.sh:
  file.managed:
    - source: salt://appliance/stunnel/prepare-stunnel.sh
    - require:
      - sls: appliance.directories

/app/etc/stunnel.conf:
  file.managed:
    - source: salt://appliance/stunnel/stunnel.conf
    - template: jinja
    - defaults:
        main_ip: {{ salt['network.get_route'](salt['network.default_route']('inet')[0].gateway).source }}
    - require:
      - pkg: stunnel
      - sls: appliance.directories

/etc/systemd/system/stunnel.service:
  file.managed:
    - source: salt://appliance/stunnel/stunnel.service
    - watch_in:
      - cmd: systemd_reload
    - require:
      - pkg: stunnel

stunnel:
  pkg.installed:
    - name: stunnel4
  cmd.run:
    - name: setcap CAP_NET_BIND_SERVICE=+eip /usr/bin/stunnel4
    - unless: setcap -v CAP_NET_BIND_SERVICE=+eip /usr/bin/stunnel4
    - require:
      - pkg: stunnel
  service.running:
    - enable: true
    - require:
      - cmd: stunnel
      - sls: appliance.ssl
      - file: /app/etc/stunnel.conf
      - file: /etc/systemd/system/stunnel.service
    - watch:
      - file: /app/etc/stunnel.conf
      - file: /app/etc/server.cert.dhparam.pem
