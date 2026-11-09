# sops-nix still builds sops-install-secrets with `buildGo125Module`, which
# nixpkgs removed on 2026-09-15 ("Go 1.25 is end-of-life, and
# 'buildGo125Module' has been removed"). Point it at the current Go builder so
# every host that evaluates `sops.package` keeps working. Drop this once
# sops-nix bumps its builder.
final: _prev: {
  buildGo125Module = final.buildGo126Module;
}
