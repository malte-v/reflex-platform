this: f:

let
  inherit (this) nixpkgs;

  definitions = { pkgs, config, options, lib, ... }: {
    options = with lib.options; with lib.types; {
      name = mkOption {
        description = ''
          An optional name for your project. This is only used for the
          name of the untargeted `nix-build`.
        '';
        type = str;
        default = "reflex-project";
      };

      packages = mkOption {
        description = ''
          An attribute set for defining packages easily. Keys are the
          cabal package name and values are the path to the source
          directory, or derivations returning sources.
        '';
        example = literalExample ''
          {
            frontend = ./frontend;
            backend = ./backend;
            common = ./common;
  
            free = pkgs.fetchFromGitHub {
              owner = "ekmett";
              repo = "free";
              rev = "<...>";
              sha256 = "<...>";
            };
          }
        '';
        type = attrsOf (either package path);
        default = {};
      };

      shells = mkOption {
        description = ''
          The `shells` field defines which platforms we'd like to
          develop for, and which packages' dependencies we want
          available in the development sandbox for that platform. Note
          in the example that specifying `common` is important;
          otherwise it will be treated as a dependency that needs to
          be built by Nix for the sandbox. You can use these shells
          with `cabal.project` files to build all three packages in a
          shared incremental environment, for both GHC and GHCJS.
        '';
        type = attrsOf (uniq (listOf str));
        example = {
          ghc = ["frontend" "backend" "common"];
          ghcjs = ["frontend" "common"];
        };
        default = {};
      };

      overrides = mkOption {
        description = ''
          A function for overriding Haskell packages. You can use
          `callHackage` and `callCabal2nix` to bump package versions
          or build them from GitHub. e.g.
        '';
        type = mkOptionType {
          name = "overrides";
          description = ''
            Haskell overrides, in the form of:

              self: super: {
                <pkgname> = <derivation>;
              }
          '';
          merge = locs: defs: lib.foldr (f: g: lib.composeExtensions f.value g) (_: _: {}) defs;
        };
        example = literalExample ''
          self: super: {
            lens = self.callHackage "lens" "4.15.4" {};
            free = self.callCabal2nix "free" (pkgs.fetchFromGitHub {
              owner = "ekmett";
              repo = "free";
              rev = "a0c5bef18b9609377f20ac6a153a20b7b94578c9";
              sha256 = "0vh3hj5rj98d448l647jc6b6q1km4nd4k01s9rajgkc2igigfp6s";
            }) {};
          }
        '';
        default = _: _: {};
      };

      shellToolOverrides = mkOption {
        description = ''
          A function returning a record of tools to provide in the
          nix-shells.  Some tools, like `ghc-mod`, have to be built
          with the same GHC as your project. The argument to the
          `tools` function is the haskell package set of the platform
          we are developing for, allowing you to build tools with the
          correct Haskell package set.

          Some tools, like `ghc-mod`, have to be built with the same GHC as
          your project. The argument to the `tools` function is the haskell
          package set of the platform we are developing for, allowing you to
          build tools with the correct Haskell package set.
  
          The second argument, `super`, is the record of tools provided by
          default. You can override these defaults by returning values with
          the same name in your record. They can be disabled by setting them
          to null.
        '';
        type = unspecified;
        example = literalExample ''
          ghc: super: {
            inherit (ghc) hpack;
            inherit (pkgs) chromium;
            ghc-mod = null;
            cabal-install = ghc.callHackage "cabal-install" "2.0.0.1" {};
            ghcid = pkgs.haskell.lib.justStaticExecutables super.ghcid;
          };
        '';
        default = _: _: {};
      };

      tools = mkOption {
        description = ''
          A function returning the list of tools to provide in the
          nix-shells.  Some tools, like `ghc-mod`, have to be built
          with the same GHC as your project. The argument to the
          `tools` function is the haskell package set of the platform
          we are developing for, allowing you to build tools with the
          correct Haskell package set.
        '';
        type = unspecified;
        example = literalExample ''
          ghc: with ghc; [
            hpack
            pkgs.chromium
          ]
        '';
        default = _: [];
      };

      withHoogle = mkOption {
        description = ''
          Set to false to disable building the hoogle database when
          entering the nix-shell.
        '';
        type = bool;
        default = true;
      };

      useWarp = mkOption {
        description = ''
          Configure `reflex-dom` to use `jsaddle-warp`.
        '';
        type = bool;
        default = false;
      };

      android = mkOption {
        description = ''
          Use this argument to configure android apps. The returned
          derivations will be in `android.<app name>`.
        '';
        type = attrsOf (attrs);
        example = {
          frontend = {
            executableName = "frontend";
            applicationId = "org.example.frontend";
            displayName = "Example Android App";
          };
        };
        default = {};
      };

      ios = mkOption {
        description = ''
          Use this argument to configure ios apps. The returned
          derivations will be in `ios.<app name>`.
        '';
        type = attrsOf (attrs);
        example = {
          frontend = {
            executableName = "frontend";
            bundleIdentifier = "org.example.frontend";
            bundleName = "Example iOS App";
          };
        };
        default = {};
      };
      passthru = mkOption {
        description = ''
          Specify arbitrary nix expressions.
        '';
        type = unspecified;
        example = literalExample ''
        '';
        default = {};
      };
    };
    imports = [(import ./impl.nix this) ./doc.nix f];
  };

  module = nixpkgs.lib.evalModules { modules = [definitions]; };
in module.config.project
