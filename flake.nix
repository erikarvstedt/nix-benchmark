{
  # unstable (2022-03-17)
  inputs.nixpkgs_2022.url = "github:NixOS/nixpkgs/3eb07eeafb52bcbf02ce800f032f18d666a9498d";

  # unstable (2023-11-23)
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/51a01a7e5515b469886c120e38db325c96694c2f";

  outputs = { self, nixpkgs, nixpkgs_2022 }: let
    system = "x86_64-linux";
    pkgs_2022 = nixpkgs_2022.legacyPackages.${system};
    pkgs = nixpkgs.legacyPackages.${system};

    shellEnvVars = {
      inherit nixpkgs;

      nix_2_3 = "${pkgs_2022.nix_2_3}/bin";
      nix_2_7 = "${pkgs_2022.nix}/bin";
      nix_2_18 = "${pkgs.nixVersions.nix_2_18}/bin";

      IN_BENCHMARK_SHELL = true;
    };

    shellPkgs = with pkgs; [
      hyperfine
      bash
      coreutils
      strace
    ];

    shellHook = ''
      . ./benchmark.sh
    '';
  in {
    devShell.${system} = derivation ({
      inherit system shellHook;
      name = "shell-env";
      outputs = [ "out" ];
      builder = pkgs.stdenv.shell;
      PATH = pkgs.lib.makeBinPath shellPkgs;
    } // shellEnvVars);
  };
}
