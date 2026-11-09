# Identity constants shared across modules, roles, lib/mk*.nix, and the dns
# app. Import directly by path (`import ../../lib/constants.nix`) — no
# specialArgs plumbing needed.
{
  # Primary (and only) user; mkHost/mkDarwin wire Home Manager to this name.
  username = "alex";
  # Cloudflare zone every public hostname lives under (see dns/cloudflare.nix).
  domain = "example.com";
  # Tailnet MagicDNS suffix; `<host>.${tailnetSuffix}` resolves over Tailscale.
  tailnetSuffix = "tailnet-name.ts.net";
  # ACME registration / expiry notices (Caddy on alexvps).
  acmeEmail = "admin@example.com";
}
