{ pkgs, lib }:

let hashes = builtins.fromJSON (builtins.readFile ./hashes.json);

in pkgs.buildGoModule {
	name = "catnip";

	src = pkgs.fetchFromGitHub {
		owner  = "noriah";
		repo   = "catnip";
		rev    = "main";
		sha256 = hashes.srcSha256;
	};

	vendorSha256 = hashes.vendorSha256;

	CGO_ENABLED = "0";
}
