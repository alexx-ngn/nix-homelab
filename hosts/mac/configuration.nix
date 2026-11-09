{ self, ... }:

{
  imports = [ ../../roles/darwin.nix ];

  networking.hostName = "alexmac";

  system.stateVersion = 6;
  system.configurationRevision = self.rev or self.dirtyRev or null;
}
