include:
  - appliance.ssl

nginx:
  pkg.installed:
    - name: nginx
  service.running:
    - enable: true
    - require:
      - pkg: nginx
      - sls: appliance.ssl
      - file: /etc/nginx/nginx.conf
      - file: /etc/appliance/server.identity
    - watch:
      - file: /etc/nginx/nginx.conf
      - file: /etc/appliance/server.identity

{% for a in ['app-template.html', 'snakeoil.identity', 'template.identity'] %}
/etc/appliance/{{ a }}:
  file.managed:
    - source: salt://appliance/nginx/{{ a }}
    - makedirs: true
{% endfor %}

/etc/nginx/nginx.conf:
  file.managed:
    - source: salt://appliance/nginx/nginx.conf

/etc/appliance/server.identity:
  file.copy:
    - source: /etc/appliance/snakeoil.identity
    - force: true
    - require:
      - file: /etc/appliance/ssl-cert-snakeoil.key
      - file: /etc/appliance/ssl-cert-snakeoil.pem
      - file: /etc/appliance/snakeoil.identity
