include:
  - appliance.directories
  - systemd.reload

backup:
  pkg.installed:
    - pkgs:
      - duply
      - duplicity
      - lftp
      - gnupg
      - cifs-utils
      # https://sourceforge.net/projects/pgbarman/

rpcbind_deny:
  file.replace:
    - name: /etc/hosts.deny
    - pattern: |
        ^rpcbind[ \t]*:
    - repl: |
        rpcbind : ALL
    - append_if_not_found: true

rpcbind_allow:
  file.replace:
    - name: /etc/hosts.deny
    - pattern: |
        ^rpcbind[ \t]*:
    - repl: |
        rpcbind : 127.0.0.1/8, {{ salt['pillar.get']('docker:net') }}
    - append_if_not_found: true

nfs_transport:
  pkg.installed:
    - pkgs:
      - nfs-common
    - require:
      - file: rpcbind_deny
      - file: rpcbind_allow

/usr/local/share/appliance/prepare-backup.sh:
  file.managed:
    - source: salt://appliance/backup/prepare-backup.sh
    - require:
      - sls: appliance.directories

/usr/local/share/appliance/appliance-backup.sh:
  file.managed:
    - source: salt://appliance/backup/appliance-backup.sh
    - mode: "0755"

/usr/local/sbin/recover-from-backup.sh:
  file.managed:
    - source: salt://appliance/backup/recover-from-backup.sh
    - mode: "0755"

/root/.duply/appliance-backup/conf.template:
  file.managed:
    - source: salt://appliance/backup/duply.conf.template
    - makedirs: true

/root/.duply/appliance-backup/exclude:
  file.managed:
    - source: salt://appliance/backup/duply.files

/etc/systemd/system/appliance-backup.timer:
  file.managed:
    - source: salt://appliance/backup/appliance-backup.timer
    - watch_in:
      - cmd: systemd_reload

/etc/systemd/system/appliance-backup.service:
  file.managed:
    - source: salt://appliance/backup/appliance-backup.service
    - watch_in:
      - cmd: systemd_reload

enable-appliance-backup-service:
  service.running:
    - name: appliance-backup.timer
    - enable: true
    - require:
      - pkg: backup
      - file: /etc/systemd/system/appliance-backup.service
      - file: /etc/systemd/system/appliance-backup.timer
      - file: /usr/local/share/appliance/appliance-backup.sh
      - file: /root/.duply/appliance-backup/conf.template
      - file: /root/.duply/appliance-backup/exclude
    - watch:
      - file: /etc/systemd/system/appliance-backup.service
      - file: /etc/systemd/system/appliance-backup.timer
