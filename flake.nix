# flake.nix
{
  description = "My Git repo tools wrapped in a Nix Flake";

  inputs = {
    nixpkgs.url = "github:nixOS/nixpkgs/nixos-unstable";

    systems.url = "github:vpayno/nix-systems-default";

    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

    treefmt-conf = {
      url = "github:vpayno/nix-treefmt-conf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      treefmt-conf,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pname = "nix-repo-tools";
        version = "20260824.0.0";
        name = "${pname}-${version}";

        flake_repo_url = "github:vpayno/nix-repo-tools";

        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            self.overlays.gitWrappers
          ];
        };

        metadata = {
          homepage = "https://github.com/vpayno/nix-repo-tools";
          description = "My Git repo tools wrapped in a Nix Flake";
          license = with pkgs.lib.licenses; [ mit ];
          # maintainers = with pkgs.lib.maintainers; [vpayno];
          maintainers = [
            {
              email = "vpayno@users.noreply.github.com";
              github = "vpayno";
              githubId = 3181575;
              name = "Victor Payno";
            }
          ];
          mainProgram = "showUsage";
        };

        usageMessage = ''
          Available ${name} flake commands:

            nix run .#usage | .#default

            nix develop .#default
        '';

        # very odd, this doesn't work with pkgs.writeShellApplication
        # odd quoting error when the string usagemessage as new lines
        showUsage = pkgs.writeShellScriptBin "showUsage" ''
          printf "%s" "${usageMessage}"
        '';

        toolConfigs = [
        ];

        toolScripts = [
        ];

        ciBundle = pkgs.buildEnv {
          name = "${name}-bundle";
          paths =
            with pkgs;
            [
              tig
            ]
            ++ [
              self.packages.${system}.gitWrapped
            ];
          nativeBuildInputs = with pkgs; [
            makeWrapper
          ];
          pathsToLink = [
            "/bin"
            "/etc"
          ];
          postBuild = ''
            :
          '';
        };
      in
      {
        formatter = treefmt-conf.formatter.${system};

        packages = {
          default = ciBundle;
          gitWrapped = pkgs.git-wrapped;
        };

        apps = {
          default = self.apps.${system}.usage;

          usage = {
            type = "app";
            pname = "usage";
            inherit version;
            name = "${pname}-${version}";
            program = "${pkgs.lib.getExe showUsage}";
            meta = metadata;
          };
        };

        devShells = {
          default = pkgs.mkShell {
            packages =
              with pkgs;
              [
                bashInteractive
              ]
              ++ [
                ciBundle
              ];

            SHELLMOTD = ''
              Starting ${name}

              nix develop .#default shell...
            '';

            shellHook = ''
              ${pkgs.lib.getExe pkgs.cowsay} "''${SHELLMOTD}"
              printf "\n"

              echo $PATH | tr ':' '\n' | grep -i -e nix-repo-tools -e devShell
              printf "\n"

              ${pkgs.lib.getExe pkgs.tree} "${ciBundle}"
              printf "\n"
            '';
          };
        };
      }
    )
    // {
      overlays = {
        gitWrappers = final: prev: {
          git-wrapped = prev.symlinkJoin {
            name = "git-wrapped";
            pname = "${final.git-wrapped.name}-${prev.git.version}";
            version = prev.git.version;
            paths = [
              prev.git
            ];
            nativeBuildInputs = [
              prev.makeWrapper
            ];
            postBuild = ''
              printf "Running postBuild for git-wrapped package.\n"
              extra_bin_paths="${
                prev.lib.makeBinPath (
                  with prev;
                  [
                    bash
                    coreutils
                    curl
                    diffutils
                    less
                    openssh
                    openssl_3_5
                    patchutils
                  ]
                )
              }"
              for prog in $out/bin/*; do
                if [[ ! -x $prog ]]; then
                  continue
                fi
                echo Running: wrapProgram "$prog" --prefix PATH : "$extra_bin_paths"
                wrapProgram "$prog" --prefix PATH : "$extra_bin_paths" || exit
              done
            '';
          };
        };
      };
    };
}
