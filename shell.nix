{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
	name = "nix-hash-fuzzer";
	buildInputs = with pkgs; [
		jq
		bash
		coreutils
	];
}
