{ pkgs, ... }:
{
  users.users.qemu-libvirtd = {
    isSystemUser = true;
    extraGroups = [
      "audio"
      "pipewire"
    ];
  };

  virtualisation.spiceUSBRedirection.enable = true;
  virtualisation.libvirtd = {
    enable = true;
    qemu.runAsRoot = true;
    onBoot = "ignore";
    onShutdown = "shutdown";
    qemu = {
      package = pkgs.qemu_kvm;
      verbatimConfig = ''
        namespaces = []
        user = "alex"
        group = "users"

        # Security settings
        security_driver = "none"
        clear_emulator_capabilities = 1
        relaxed_acs_check = 1

        # Memory locking for GPU passthrough (unlimited)
        max_processes = 4194303
        max_files = 32768

        # Device access control list
        cgroup_device_acl = [
            "/dev/null", "/dev/full", "/dev/zero",
            "/dev/random", "/dev/urandom",
            "/dev/ptmx", "/dev/kvm", "/dev/kqemu",
            "/dev/rtc", "/dev/hpet",
            "/dev/vfio/vfio",
            "/dev/vfio/1", "/dev/vfio/2", "/dev/vfio/3",
            "/dev/vfio/4", "/dev/vfio/5", "/dev/vfio/6",
            "/dev/vfio/7", "/dev/vfio/8", "/dev/vfio/9",
            "/dev/vfio/10", "/dev/vfio/11", "/dev/vfio/12",
            "/dev/input/by-id/usb-Logitech_Gaming_Mouse_G502_SERIAL-event-mouse",
            "/dev/input/by-id/usb-Keychron_Keychron_K2_Max-event-kbd"
        ]
      '';
    };
  };

  # PAM limits for VM memory locking
  security.pam.loginLimits = [
    {
      domain = "alex";
      type = "-";
      item = "memlock";
      value = "unlimited";
    }
    {
      domain = "@users";
      type = "-";
      item = "memlock";
      value = "unlimited";
    }
  ];

  # Allow QEMU access to PipeWire
  security.wrappers.qemu-system-x86_64 = {
    source = "${pkgs.qemu}/bin/qemu-system-x86_64";
    capabilities = "cap_net_admin+ep";
    owner = "alex";
    group = "users";
  };
}
