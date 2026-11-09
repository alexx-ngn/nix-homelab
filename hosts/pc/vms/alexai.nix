# alexai — headless inference guest. Holds the RTX 4070 Super (01:00.0/.1)
# while it runs, so it and win11 are mutually exclusive.
#
# Unlike win11.nix, no PCI topology is pinned: this is a fresh domain with no
# Windows activation to keep stable, so libvirt assigns controllers and
# addresses itself on define.
#
# There is no install media: the disk image is built from the guest's own NixOS
# config (hosts/alexai/) via disko — see hosts/alexai/disk-config.nix.
{ qemu }:
{
  type = "kvm";
  name = "alexai";
  uuid = "6760acb1-6420-4a54-a652-9f97d3d68dec";

  memory = {
    count = 8;
    unit = "GiB";
  };
  currentMemory = {
    count = 8;
    unit = "GiB";
  };
  vcpu = {
    placement = "static";
    count = 4;
  };

  # Same host/guest split the qemu hook uses for win11: host keeps threads
  # 0,1,6,7. Inference is GPU-bound, so 2 cores is plenty.
  cputune = {
    vcpupin = [
      {
        vcpu = 0;
        cpuset = "2";
      }
      {
        vcpu = 1;
        cpuset = "8";
      }
      {
        vcpu = 2;
        cpuset = "3";
      }
      {
        vcpu = 3;
        cpuset = "9";
      }
    ];
    emulatorpin = {
      cpuset = "0,6";
    };
  };

  os = {
    type = "hvm";
    arch = "x86_64";
    machine = "pc-q35-10.0";
    # Plain UEFI — no secure boot, so the non-secure edk2 build.
    loader = {
      readonly = true;
      type = "pflash";
      path = "${qemu}/share/qemu/edk2-x86_64-code.fd";
    };
    nvram = {
      template = "${qemu}/share/qemu/edk2-i386-vars.fd";
      templateFormat = "raw";
      format = "raw";
      path = "/var/lib/libvirt/qemu/nvram/alexai_VARS.fd";
    };
    boot = [ { dev = "hd"; } ];
  };

  features = {
    acpi = { };
    apic = { };
  };

  cpu = {
    mode = "host-passthrough";
    check = "none";
    migratable = true;
    topology = {
      sockets = 1;
      dies = 1;
      cores = 2;
      threads = 2;
    };
    feature = [
      {
        policy = "require";
        name = "topoext";
      }
    ];
  };

  clock = {
    offset = "utc";
    timer = [
      {
        name = "rtc";
        tickpolicy = "catchup";
      }
      {
        name = "pit";
        tickpolicy = "delay";
      }
      {
        name = "hpet";
        present = false;
      }
    ];
  };

  on_poweroff = "destroy";
  on_reboot = "restart";
  on_crash = "destroy";

  devices = {
    emulator = "/run/libvirt/nix-emulators/qemu-system-x86_64";

    disk = [
      {
        type = "file";
        device = "disk";
        driver = {
          name = "qemu";
          type = "qcow2";
          discard = "unmap";
        };
        source = {
          file = "/var/lib/libvirt/images/alexai.qcow2";
        };
        target = {
          dev = "vda";
          bus = "virtio";
        };
      }
    ];

    # Bridged onto br0 (modules/network/br0.nix enslaves enp5s0) so the guest
    # is a first-class LAN host and tailscale comes up without NAT games.
    interface = {
      type = "bridge";
      source = {
        bridge = "br0";
      };
      model = {
        type = "virtio";
      };
    };

    # The GPU and its HDA function. NOT the NVMe at 02:00.0 — that is win11's
    # boot disk.
    hostdev = [
      {
        mode = "subsystem";
        type = "pci";
        managed = true;
        source = {
          address = {
            domain = 0;
            bus = 1;
            slot = 0;
            function = 0;
          };
        };
      }
      {
        mode = "subsystem";
        type = "pci";
        managed = true;
        source = {
          address = {
            domain = 0;
            bus = 1;
            slot = 0;
            function = 1;
          };
        };
      }
    ];

    # A virtual display for the installer and for recovery — the passed-through
    # GPU has no monitor attached and the guest is headless in normal use.
    graphics = {
      type = "spice";
      autoport = true;
      listen = {
        type = "none";
      };
    };
    video = {
      model = {
        type = "virtio";
        heads = 1;
        primary = true;
      };
    };

    input = [
      {
        type = "tablet";
        bus = "usb";
      }
      {
        type = "keyboard";
        bus = "ps2";
      }
    ];

    channel = [
      {
        type = "unix";
        target = {
          type = "virtio";
          name = "org.qemu.guest_agent.0";
        };
      }
    ];

    rng = {
      model = "virtio";
      backend = {
        model = "random";
        source = "/dev/urandom";
      };
    };

    memballoon = {
      model = "virtio";
    };
  };
}
