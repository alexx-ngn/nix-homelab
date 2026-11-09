{ pkgs, lib, ... }:
let
  hostCpus = "0,1,6,7";
  allCpus = "0-11";
  vmCpuList = [
    2
    3
    4
    5
    8
    9
    10
    11
  ];
  ddcutilSetInput = code: "${pkgs.ddcutil}/bin/ddcutil setvcp 60 ${toString code}";

  qemuHook = pkgs.writeShellApplication {
    name = "qemu-hook";
    runtimeInputs = [
      pkgs.ddcutil
      pkgs.systemd
    ];
    text = ''
      GUEST_NAME="$1"
      OPERATION="$2"

      # VM CPU allocation strategy:
      # Host: cores 0-1 (threads 0,1,6,7)
      # VM:   cores 2-5 (threads 2,3,4,5,8,9,10,11)

      # Match the previous writeScript behavior: best-effort, do not abort the
      # hook if an individual command fails. writeShellApplication injects
      # `set -euo pipefail`, so each fallible command is explicitly guarded.
      if [ "$GUEST_NAME" = "win11" ]; then
        if [ "$OPERATION" = "prepare" ] || [ "$OPERATION" = "start" ]; then
          ${ddcutilSetInput 15} || true

          systemctl set-property --runtime -- user.slice   AllowedCPUs=${hostCpus} || true
          systemctl set-property --runtime -- system.slice AllowedCPUs=${hostCpus} || true
          systemctl set-property --runtime -- init.scope   AllowedCPUs=${hostCpus} || true

          for cpu in ${lib.concatStringsSep " " (map toString vmCpuList)}; do
            echo performance > /sys/devices/system/cpu/cpu"$cpu"/cpufreq/scaling_governor 2>/dev/null || true
          done

          echo 0 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true
        fi

        if [ "$OPERATION" = "release" ] || [ "$OPERATION" = "stopped" ]; then
          ${ddcutilSetInput 16} || true

          systemctl set-property --runtime -- user.slice   AllowedCPUs=${allCpus} || true
          systemctl set-property --runtime -- system.slice AllowedCPUs=${allCpus} || true
          systemctl set-property --runtime -- init.scope   AllowedCPUs=${allCpus} || true

          for cpu in 0 1 2 3 4 5 6 7 8 9 10 11; do
            echo schedutil > /sys/devices/system/cpu/cpu"$cpu"/cpufreq/scaling_governor 2>/dev/null || true
          done

          echo 1 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true
        fi
      fi
    '';
  };
in
{
  # VFIO modules in initrd so vfio-pci can claim devices before native drivers.
  boot.initrd.kernelModules = [
    "vfio_pci"
    "vfio"
    "vfio_iommu_type1"
  ];

  # Ensure vfio-pci loads before GPU drivers that would otherwise grab the device.
  boot.extraModprobeConfig = ''
    softdep nvidia pre: vfio-pci
    softdep drm pre: vfio-pci
    softdep nouveau pre: vfio-pci
  '';

  # Generic VFIO/KVM params, AMD IOMMU, hugepage backing for VM memory, and
  # the exact PCI IDs of the GPU + USB controller passed through.
  boot.kernelParams = [
    "vfio_iommu_type1.allow_unsafe_interrupts=1"
    "kvm.ignore_msrs=1"
    "default_hugepagesz=1G"
    "hugepagesz=1G"
    "hugepages=1"
    "hugepagesz=2M"
    "amd_iommu=on"
    "iommu=pt"
    "vfio-pci.ids=10de:2783,10de:22bc,15b7:5009"
    "kvm_amd.vls=0"
  ];

  # Blacklist the host's NVIDIA driver stack so vfio-pci can claim the GPU.
  boot.blacklistedKernelModules = [
    "nouveau"
    "nvidia"
    "nvidia_drm"
    "nvidia_modeset"
    "i2c_nvidia_gpu"
  ];

  # i2c-dev backs ddcutil so the qemu hook can flip the monitor input.
  boot.kernelModules = [ "i2c-dev" ];

  # Transparent hugepage handling for dynamic VM memory allocation.
  boot.kernel.sysctl."vm.nr_hugepages" = 0;
  systemd.tmpfiles.rules = [
    "w /sys/kernel/mm/transparent_hugepage/enabled - - - - always"
    "w /sys/kernel/mm/transparent_hugepage/defrag - - - - madvise"
  ];

  security.sudo-rs.extraRules = [
    {
      users = [ "root" ];
      commands = [
        {
          command = "${pkgs.ddcutil}/bin/ddcutil setvcp 60 15";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  systemd.services.libvirtd.preStart = ''
    mkdir -p /var/lib/libvirt/hooks
    chmod 755 /var/lib/libvirt/hooks
    ln -sf ${qemuHook}/bin/qemu-hook /var/lib/libvirt/hooks/qemu
  '';

  # Restore the monitor to the host input at boot in case the hook didn't run.
  systemd.services.ddcutil-switch-input = {
    description = "Set monitor input source via ddcutil";
    after = [ "basic.target" ];
    wantedBy = [ "sysinit.target" ];
    serviceConfig = {
      ExecStart = ddcutilSetInput 16;
      User = "root";
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };
}
