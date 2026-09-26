{
  description = "thekkid's NixOS configurations";

  inputs = {
    # VERIFY before locking: pin this to whichever nixpkgs branch actually
    # corresponds to the release you want `nixos-rebuild switch` to converge
    # to. `nixos-version` currently reports 26.05 (Yarara); confirm the
    # matching nixpkgs branch name (e.g. run `nix-channel --list` and/or
    # check nixos.org for the current stable branch) before running
    # `nix flake lock` — getting this wrong risks an unexpected
    # upgrade/downgrade on the very first flake-based switch.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, ... }@inputs:
    let
      # Replaces the old `let unstable = import <nixos-unstable> {...};`
      # channel pattern. Adds `pkgs.unstable.<name>` everywhere, so existing
      # references like `unstable.opam` / `unstable.awatcher` in
      # modules/users/thekkid.nix keep working unchanged.
      unstableOverlay = final: prev: {
        unstable = import nixpkgs-unstable {
          system = final.stdenv.hostPlatform.system;
          config.allowUnfree = true;
        };
      };
    in
    {
      # No `system` argument here — it's set via `nixpkgs.hostPlatform` in
      # hardware-configuration.nix (the modern replacement for passing
      # `system` directly to nixosSystem, which trips a deprecation warning).
      nixosConfigurations.thekkid-desktop = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.overlays = [ unstableOverlay ]; }
          ./hosts/thekkid-desktop/configuration.nix
          ./hosts/thekkid-desktop/hardware-configuration.nix
        ];
      };

      # Adding a second machine later:
      #   nixosConfigurations.<new-host> = nixpkgs.lib.nixosSystem {
      #     specialArgs = { inherit inputs; };
      #     modules = [
      #       { nixpkgs.overlays = [ unstableOverlay ]; }
      #       ./hosts/<new-host>/configuration.nix
      #       ./hosts/<new-host>/hardware-configuration.nix
      #     ];
      #   };
    };
}
