# Rust codegen plugins for `buf generate`, built from crates.io.
#
# This file provides VALUES — the derivations themselves — and takes `pkgs` as
# its only argument, so the same definitions serve three consumers unchanged:
#
#   flake.nix `perSystem.packages`   built against this flake's pinned nixpkgs
#   flake.nix `overlays.default`     built against the consumer's pkgs
#   flake.nix `lib.plugins`          the four as one list, for a `packages` list
#
# Deliberately not a module. A module contributes option DEFINITIONS, and every
# top-level attribute it returns is read as one — put this in an `imports` list
# and you get `error: The option 'protoc-gen-buffa' does not exist`.
{pkgs}: let
  # These versions move together or not at all. `connectrpc` and
  # `connectrpc-codegen` pin a compatible `buffa`, so bumping one alone leaves
  # the generated stubs compiling against the wrong API. Change them together,
  # regenerate, and commit the output in the same commit as the bump.
  connect-version = "0.9.0";
  protoc-version = "0.9.1";

  # Deliberately not `protoc-version`: the protovalidate plugin has its own
  # release line (0.10.x), which is not buffa's. It still moves WITH buffa —
  # the validators it emits reference buffa's field layout and view types
  # directly, and buffa treats a minor bump as breaking — so bumping
  # `protoc-version` means checking this one too, even though the numbers
  # never match.
  #
  # There is a third version line: `protovalidate-buffa` (0.7.x) is the RUNTIME
  # half that the emitted code calls into. It is a plain Cargo.toml dependency
  # of the consuming project, not a plugin, so it is not here — but it has to
  # agree with this plugin.
  protovalidate-version = "0.10.0";

  # None of these are in nixpkgs. To bump: change the version above, set
  # `hash`/`cargoHash` to `pkgs.lib.fakeHash`, and read the correct values off
  # the build error.
  #
  # `version` and the two hashes are one unit — a version passed in from
  # outside would just mismatch the hash below, so they stay pinned together.
  crate = {
    pname,
    version,
    hash,
    cargoHash,
    mainProgram ? pname,
  }:
    pkgs.rustPlatform.buildRustPackage {
      inherit pname version cargoHash;
      src = pkgs.fetchCrate {inherit pname version hash;};
      doCheck = false;
      meta.mainProgram = mainProgram;
    };
in {
  # https://github.com/connectrpc/connect-rust — the crate is
  # `connectrpc-codegen`, the binary it ships is `protoc-gen-connect-rust`,
  # which is what `buf generate` looks for. Generates the service stubs.
  protoc-gen-connect-rust = crate {
    pname = "connectrpc-codegen";
    version = connect-version;
    hash = "sha256-f9MW/JbPW5bbHcJ3l5J3YFiFQdnkg3N8NTpiWH8d7LU=";
    cargoHash = "sha256-eyWjHSUF0ZPtU/nrRXGQSmkhLOA+yHDDKfmfeu51ZMQ=";
    mainProgram = "protoc-gen-connect-rust";
  };

  # buffa generates the message types the connect stubs reference.
  protoc-gen-buffa = crate {
    pname = "protoc-gen-buffa";
    version = protoc-version;
    hash = "sha256-uogD137KtnMcUEYlF2Jj0/PsO2NAOmm2ZzzKf9FovtM=";
    cargoHash = "sha256-kN+bjbQevcv3MWwOjOCBP/f+9J2kTMv7506AAtx7fEg=";
  };

  # Assembles the `mod.rs` tree per output dir.
  protoc-gen-buffa-packaging = crate {
    pname = "protoc-gen-buffa-packaging";
    version = protoc-version;
    hash = "sha256-xp/Zq38Rzs52XyEOyxX5CbZ2KwTSrNG47oHv+k4wKnY=";
    cargoHash = "sha256-ZxVyXSMAwdHwTuIcVdgKkegF6N1DSRjzhbWQDFUA0W0=";
  };

  # Static `Validate` impls generated from the `buf.validate` annotations. CEL
  # is transpiled to Rust at codegen time, so there is no runtime interpreter,
  # and the impls cover buffa's view types too — which is what lets a request
  # be validated without allocating an owned message first.
  #
  # This one must see `buf.validate`, so its entry in the consumer's
  # buf.gen.yaml carries no `exclude_types`. An exclusion on
  # `protoc-gen-buffa` is only needed because `reflect_mode=bridge` would
  # embed the whole descriptor set in every package; this plugin does not
  # embed descriptors and has no such problem.
  protoc-gen-protovalidate-buffa = crate {
    pname = "protoc-gen-protovalidate-buffa";
    version = protovalidate-version;
    hash = "sha256-/pwEhC4gsom0DQslXWVKyy9PIrAYxWuU26QdIL6Juxk=";
    cargoHash = "sha256-aKzwRhcR+DFeFe6D6wwZT8xWOkSFqegTexx+rVdkVlE=";
  };
}
