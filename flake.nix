{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    haskell-flake.url = "github:srid/haskell-flake";
  };
  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [inputs.haskell-flake.flakeModule];

      perSystem = {
        self',
        pkgs,
        ...
      }: {
        # Typically, you just want a single project named "default". But
        # multiple projects are also possible, each using different GHC version.
        haskellProjects.default = {
          # The base package set representing a specific GHC version.
          # By default, this is pkgs.haskellPackages.
          # You may also create your own. See https://haskell.nixos.asia/package-set
          # basePackages = pkgs.haskellPackages;

          # Extra package information. See https://haskell.nixos.asia/dependency
          #
          # Note that local packages are automatically included in `packages`
          # (defined by `defaults.packages` option).
          #
          projectRoot = builtins.toString (self + /ssg);
          packages = {};
          settings = {
            #  aeson = {
            #    check = false;
            #  };
            #  relude = {
            #    haddock = false;
            #    broken = false;
            #  };
          };

          devShell = {
            # Enabled by default
            # enable = true;

            # Programs you want to make available in the shell.
            # Default programs can be disabled by setting to 'null'
            tools = hp: {
              inherit (hp) fourmolu hakyll;
            };

            # Check that haskell-language-server works
            # hlsCheck.enable = true; # Requires sandbox to be disabled
          };
        };

        packages.default = pkgs.stdenv.mkDerivation {
          name = "website";
          src = pkgs.nix-gitignore.gitignoreSourcePure [
            ./.gitignore
            ".git"
            ".github"
          ] ./.;

          LANG = "en_US.UTF-8";
          LOCALE_ARCHIVE = pkgs.lib.optionalString
            (pkgs.buildPlatform.libc == "glibc")
            "${pkgs.glibcLocales}/lib/locale/locale-archive";

          buildPhase = ''
            ${self'.packages.ssg}/bin/site build --verbose
          '';

          installPhase = ''
            mkdir -p "$out/dist"
            cp -a _site/. "$out/dist"
          '';
        };

        packages.hakyll-site = self'.packages.ssg;

        apps.default = {
          type = "app";
          program = "${self'.packages.ssg}/bin/site";
        };
      };
    };
}
