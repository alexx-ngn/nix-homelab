# CLI baseline + what a remotely-managed host needs: the deploy-rs push user
# (ci-deploy) and tailnet membership (deploy SSH rides the tailnet). Used by
# the headless roles (server, vps, exit-node). Deliberately does NOT import
# sops — the exit node has no secrets; roles that need it add it themselves.
{
  imports = [
    ./cli.nix
    ../../modules/security/ci-deploy.nix
    ../../modules/services/tailscale.nix
  ];
}
