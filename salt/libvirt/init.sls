include:
  - .kernel

default_kvm_settings:
  file.managed:
    - name: /etc/default/qemu-kvm
    - contents: |
        # To disable qemu-kvm's page merging feature, set KSM_ENABLED=0 and
        # sudo restart qemu-kvm
        KSM_ENABLED=1
        SLEEP_MILLISECS=200
        # To load the vhost_net module, which in some cases can speed up
        # network performance, set VHOST_NET_ENABLED to 1.
        VHOST_NET_ENABLED=1
        # Set this to 1 if you want hugepages to be available to kvm under
        # /run/hugepages/kvm
        KVM_HUGEPAGES=1
    - require:
      - pkg: libvirt

libvirt:
  pkg.installed:
    - pkgs:
      - libvirt-bin
      - qemu-kvm
      - cgroup-bin
      - bridge-utils
  service.running:
    - name: libvirt-bin
    - enable: True
    - require:
      - pkg: libvirt
      - sls: .kernel
