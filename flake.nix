{
  description = "protoc plugins for Connect RPC and buffa codegen in Rust";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];

      perSystem = {pkgs, ...}: {
        # Exactly the four plugins and nothing else, which is what makes
        # `lib.plugins` below just `attrValues`. Anything that is not a
        # `buf generate` plugin does not belong in here.
        packages = import ./pkgs {inherit pkgs;};
      };

      flake = {
        # The reusable form: composes the plugins into any pkgs set, so a
        # consumer writes `pkgs.protoc-gen-buffa` without threading this
        # flake's outputs through by hand.
        overlays.default = final: _prev: import ./pkgs {pkgs = final;};

        # Every plugin as one list, for a consumer that wants exactly this set
        # in a `packages` list or a CI image and nothing else. Takes the
        # consumer's `pkgs` so it does not force this flake's nixpkgs on them;
        # for the pinned builds use `packages.${system}` instead.
        lib.plugins = pkgs: builtins.attrValues (import ./pkgs {inherit pkgs;});
      };
    };
}
