# nix-hash-fuzzer

Shell script to auto-parse mismatching SHA256 hashes from Nix derivations and
gradually replace them, just as a human would do, but automated.

## Usage

nix-hash-fuzzer needs a `hashes.json` in PWD to work. It should look something
like this:

```json
{
	"arbitrary-key": ""
}
```

Use the JSON file in a Nix derivation like so:

```nix
let hashes = builtins.fromJSON (builtins.readFile ./hashes.json);

in {
	# do anything with this
	vendorSha256 = hashes."arbitrary-key";
}
```

Then, run `nix-hash-fuzzer` followed by `--` then whatever command that will
output the Nix errors containing the hashes.

**Note:** nix-hash-fuzzer will run the given command until either no hashes can
be found OR the command exits fatally without any matching hash. If this is a
particularly bad idea for your command, DO NOT USE THIS SCRIPT.

## Example

```sh
cd example/gomod/
nix-hash-fuzzer -- \
	nix-build --max-jobs 0 -E "with import <nixpkgs> {}; (callPackage ./. {}).all"
```
