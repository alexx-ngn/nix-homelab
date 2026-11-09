# Declarative libvirt domains for alexpc, via NixVirt.
#
# nixpkgs' virtualisation.libvirtd only configures the daemon, so before this
# the domains were loose XML at the repo root that had to be `virsh define`d by
# hand.
#
# This list is authoritative: NixVirt undefines any domain on the connection
# that is not declared here.
{
  inputs,
  pkgs,
  ...
}:
{
  imports = [ inputs.nixvirt.nixosModules.default ];

  virtualisation.libvirt = {
    enable = true;

    connections."qemu:///system".domains = [
      {
        # Holds the RTX 4070 Super (01:00.0/.1) and the NVMe at 02:00.0 while
        # it runs; those are bound to vfio-pci in modules/desktop/gpu-passthrough.nix.
        definition = inputs.nixvirt.lib.domain.writeXML (import ./win11.nix { qemu = pkgs.qemu_kvm; });
        # Running state is left alone: this is a desktop VM started by hand
        # from virt-manager.
        active = null;
        # Never restart a running guest on rebuild. The definition embeds a
        # qemu store path, so it changes on every qemu bump — yanking a live
        # Windows session for that would be unacceptable.
        restart = false;
      }
      {
        # Takes the same GPU as win11, so libvirt refuses to start whichever
        # comes second. Stop this one to game.
        definition = inputs.nixvirt.lib.domain.writeXML (import ./alexai.nix { qemu = pkgs.qemu_kvm; });
        # Define only, don't start. The guest's disk image is built out of band
        # (hosts/alexai/disk-config.nix), and a rebuild must not fail just
        # because that image is missing, on another disk, or already claimed by
        # the win11 guest holding the GPU. Use `virsh autostart alexai` once the
        # image exists if you want it up at boot.
        active = null;
        restart = false;
      }
    ];
  };
}
