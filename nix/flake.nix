{
  description = "fiziko.typ development and reproducible source comparisons";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fiziko-upstream = {
      url = "github:jemmybutton/fiziko/54a63dba8e6700a5e70d3508838edebcbf0f45fe";
      flake = false;
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.devshell.flakeModule ];

      perSystem =
        { pkgs, lib, ... }:
        {
          devshells.default = {
            packages = with pkgs; [
              typst
              tinymist
              python3
              imagemagick
              texliveSmall
              ghostscript
            ];
            env = [
              {
                name = "TYPST_FONT_PATHS";
                prefix = lib.makeSearchPath "share/fonts" (with pkgs; [ liberation_ttf ]);
              }
              {
                name = "FIZIKO_TEST_FONT_PATH";
                value = lib.makeSearchPath "share/fonts" [ pkgs.dejavu_fonts ];
              }
              {
                name = "FIZIKO_UPSTREAM_PATH";
                value = toString inputs.fiziko-upstream;
              }
            ];
          };
        };

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
    };
}
