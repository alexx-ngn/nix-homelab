# win11 — gaming guest, holds the RTX 4070 Super (and the NVMe at 02:00.0)
# while it runs. Translated from the virt-manager-authored win11.xml.
#
# PCI addresses, the UUID, and the MAC are reproduced exactly: Windows keys
# activation and driver bindings off guest hardware identity, so this is not
# the place to tidy up.
{ qemu }:
{
  type = "kvm";
  name = "win11";
  uuid = "cd8bfe5a-57ac-4ab2-960b-30f9f70b5b29";

  memory = {
    count = 16;
    unit = "GiB";
  };
  currentMemory = {
    count = 16;
    unit = "GiB";
  };
  vcpu = {
    placement = "static";
    count = 8;
  };
  iothreads = {
    count = 1;
  };

  # Host keeps threads 0,1,6,7; the guest gets cores 2-5 (threads 2-5, 8-11).
  # Matches the AllowedCPUs split the qemu hook applies in gpu-passthrough.nix.
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
      {
        vcpu = 4;
        cpuset = "4";
      }
      {
        vcpu = 5;
        cpuset = "10";
      }
      {
        vcpu = 6;
        cpuset = "5";
      }
      {
        vcpu = 7;
        cpuset = "11";
      }
    ];
    emulatorpin = {
      cpuset = "0,6";
    };
    iothreadpin = {
      iothread = 1;
      cpuset = "0,6";
    };
  };

  os = {
    type = "hvm";
    arch = "x86_64";
    machine = "pc-q35-10.0";

    # Explicit firmware rather than libvirt's `firmware='efi'` autoselection:
    # NixVirt cannot express the <firmware><feature/></firmware> block that
    # autoselection needs, and secure boot is fully specified here anyway
    # (secure loader + smm below). The nvram file already exists, so the
    # template is only a fallback if it is ever deleted.
    loader = {
      readonly = true;
      secure = true;
      type = "pflash";
      path = "${qemu}/share/qemu/edk2-x86_64-secure-code.fd";
    };
    nvram = {
      template = "${qemu}/share/qemu/edk2-i386-vars.fd";
      templateFormat = "raw";
      format = "raw";
      path = "/var/lib/libvirt/qemu/nvram/win11_VARS.fd";
    };
    bootmenu = {
      enable = true;
    };
  };

  features = {
    acpi = { };
    apic = { };
    hyperv = {
      mode = "passthrough";
    };
    vmport = {
      state = false;
    };
    smm = {
      state = true;
    };
  };

  cpu = {
    mode = "host-passthrough";
    check = "none";
    migratable = true;
    topology = {
      sockets = 1;
      dies = 1;
      cores = 4;
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
    offset = "localtime";
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
      {
        name = "hypervclock";
        present = true;
      }
    ];
  };

  on_poweroff = "destroy";
  on_reboot = "restart";
  on_crash = "destroy";

  pm = {
    "suspend-to-mem" = {
      enabled = false;
    };
    "suspend-to-disk" = {
      enabled = false;
    };
  };

  devices = {
    emulator = "/run/libvirt/nix-emulators/qemu-system-x86_64";

    disk = [
      {
        type = "file";
        device = "cdrom";
        driver = {
          name = "qemu";
          type = "raw";
        };
        source = {
          file = "/home/alex/Downloads/virtio-win-0.1.285.iso";
        };
        target = {
          dev = "sda";
          bus = "sata";
        };
        readonly = true;
        address = {
          type = "drive";
          controller = 0;
          bus = 0;
          target = 0;
          unit = 0;
        };
      }
      {
        type = "file";
        device = "cdrom";
        driver = {
          name = "qemu";
          type = "raw";
        };
        source = {
          file = "/home/alex/Downloads/en-us_windows_11_iot_enterprise_version_25h2_x64_dvd_67098cd6.iso";
        };
        target = {
          dev = "sdc";
          bus = "sata";
        };
        readonly = true;
        address = {
          type = "drive";
          controller = 0;
          bus = 0;
          target = 0;
          unit = 2;
        };
      }
      {
        type = "file";
        device = "disk";
        driver = {
          name = "qemu";
          type = "qcow2";
          discard = "unmap";
        };
        source = {
          file = "/var/lib/libvirt/images/win11.qcow2";
        };
        target = {
          dev = "vda";
          bus = "virtio";
        };
        address = {
          type = "pci";
          domain = 0;
          bus = 7;
          slot = 0;
          function = 0;
        };
      }
    ];

    controller = [
      {
        type = "usb";
        index = 0;
        model = "qemu-xhci";
        ports = 15;
        address = {
          type = "pci";
          domain = 0;
          bus = 2;
          slot = 0;
          function = 0;
        };
      }
      {
        type = "pci";
        index = 0;
        model = "pcie-root";
      }
      {
        type = "pci";
        index = 1;
        model = "pcie-root-port";
        target = {
          chassis = 1;
          port = 8;
        };
        address = {
          type = "pci";
          domain = 0;
          bus = 0;
          slot = 1;
          function = 0;
          multifunction = true;
        };
      }
      {
        type = "pci";
        index = 2;
        model = "pcie-root-port";
        target = {
          chassis = 2;
          port = 9;
        };
        address = {
          type = "pci";
          domain = 0;
          bus = 0;
          slot = 1;
          function = 1;
        };
      }
      {
        type = "pci";
        index = 3;
        model = "pcie-root-port";
        target = {
          chassis = 3;
          port = 10;
        };
        address = {
          type = "pci";
          domain = 0;
          bus = 0;
          slot = 1;
          function = 2;
        };
      }
      {
        type = "pci";
        index = 4;
        model = "pcie-root-port";
        target = {
          chassis = 4;
          port = 11;
        };
        address = {
          type = "pci";
          domain = 0;
          bus = 0;
          slot = 1;
          function = 3;
        };
      }
      {
        type = "pci";
        index = 5;
        model = "pcie-root-port";
        target = {
          chassis = 5;
          port = 12;
        };
        address = {
          type = "pci";
          domain = 0;
          bus = 0;
          slot = 1;
          function = 4;
        };
      }
      {
        type = "pci";
        index = 6;
        model = "pcie-root-port";
        target = {
          chassis = 6;
          port = 13;
        };
        address = {
          type = "pci";
          domain = 0;
          bus = 0;
          slot = 1;
          function = 5;
        };
      }
      {
        type = "pci";
        index = 7;
        model = "pcie-root-port";
        target = {
          chassis = 7;
          port = 14;
        };
        address = {
          type = "pci";
          domain = 0;
          bus = 0;
          slot = 1;
          function = 6;
        };
      }
      {
        type = "pci";
        index = 8;
        model = "pcie-root-port";
        target = {
          chassis = 8;
          port = 15;
        };
        address = {
          type = "pci";
          domain = 0;
          bus = 0;
          slot = 1;
          function = 7;
        };
      }
      {
        type = "pci";
        index = 9;
        model = "pcie-root-port";
        target = {
          chassis = 9;
          port = 16;
        };
        address = {
          type = "pci";
          domain = 0;
          bus = 0;
          slot = 2;
          function = 0;
          multifunction = true;
        };
      }
      {
        type = "pci";
        index = 10;
        model = "pcie-root-port";
        target = {
          chassis = 10;
          port = 17;
        };
        address = {
          type = "pci";
          domain = 0;
          bus = 0;
          slot = 2;
          function = 1;
        };
      }
      {
        type = "pci";
        index = 11;
        model = "pcie-root-port";
        target = {
          chassis = 11;
          port = 18;
        };
        address = {
          type = "pci";
          domain = 0;
          bus = 0;
          slot = 2;
          function = 2;
        };
      }
      {
        type = "pci";
        index = 12;
        model = "pcie-root-port";
        target = {
          chassis = 12;
          port = 19;
        };
        address = {
          type = "pci";
          domain = 0;
          bus = 0;
          slot = 2;
          function = 3;
        };
      }
      {
        type = "pci";
        index = 13;
        model = "pcie-root-port";
        target = {
          chassis = 13;
          port = 20;
        };
        address = {
          type = "pci";
          domain = 0;
          bus = 0;
          slot = 2;
          function = 4;
        };
      }
      {
        type = "pci";
        index = 14;
        model = "pcie-root-port";
        target = {
          chassis = 14;
          port = 21;
        };
        address = {
          type = "pci";
          domain = 0;
          bus = 0;
          slot = 2;
          function = 5;
        };
      }
      {
        type = "sata";
        index = 0;
        address = {
          type = "pci";
          domain = 0;
          bus = 0;
          slot = 31;
          function = 2;
        };
      }
    ];

    interface = {
      type = "network";
      mac = {
        address = "52:54:00:dc:ef:7f";
      };
      source = {
        network = "default";
      };
      model = {
        type = "virtio";
      };
      address = {
        type = "pci";
        domain = 0;
        bus = 1;
        slot = 0;
        function = 0;
      };
    };

    input = [
      {
        type = "mouse";
        bus = "ps2";
      }
      {
        type = "keyboard";
        bus = "ps2";
      }
    ];

    sound = {
      model = "ich9";
      codec = {
        type = "micro";
      };
      audio = {
        id = 1;
      };
      address = {
        type = "pci";
        domain = 0;
        bus = 0;
        slot = 27;
        function = 0;
      };
    };

    audio = {
      id = 1;
      type = "pipewire";
      runtimeDir = "/run/user/1000";
      input = {
        name = "qemuinput";
      };
      output = {
        name = "qemuoutput";
      };
    };

    # 02:00.0 = NVMe (boot disk), 01:00.0/.1 = RTX 4070 Super + its HDA function.
    hostdev = [
      {
        mode = "subsystem";
        type = "pci";
        managed = true;
        source = {
          address = {
            domain = 0;
            bus = 2;
            slot = 0;
            function = 0;
          };
        };
        boot = {
          order = 1;
        };
        address = {
          type = "pci";
          domain = 0;
          bus = 3;
          slot = 0;
          function = 0;
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
            function = 0;
          };
        };
        address = {
          type = "pci";
          domain = 0;
          bus = 4;
          slot = 0;
          function = 0;
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
        address = {
          type = "pci";
          domain = 0;
          bus = 5;
          slot = 0;
          function = 0;
        };
      }
    ];

    watchdog = {
      model = "itco";
      action = "reset";
    };

    memballoon = {
      model = "virtio";
      address = {
        type = "pci";
        domain = 0;
        bus = 6;
        slot = 0;
        function = 0;
      };
    };
  };

  # evdev passthrough for mouse + keyboard. The device nodes are also listed in
  # cgroup_device_acl in modules/services/libvirtd.nix — keep the two in sync.
  "qemu-commandline" = {
    arg = [
      { value = "-object"; }
      {
        value = "input-linux,id=mouse1,evdev=/dev/input/by-id/usb-Logitech_Gaming_Mouse_G502_SERIAL-event-mouse";
      }
      { value = "-object"; }
      {
        value = "input-linux,id=kbd1,evdev=/dev/input/by-id/usb-Keychron_Keychron_K2_Max-event-kbd,grab_all=on,repeat=on";
      }
    ];
  };
}
