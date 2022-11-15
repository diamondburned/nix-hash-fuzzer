#!/usr/bin/env bash
set -e

generateHash() {
	nix-hash --type sha256 --to-base32 $(
		{
			echo "nix-hash-fuzzer, please don't collide!"
			head -n64 /dev/urandom
		} \
			| sha256sum \
			| cut -d' ' -f1
	)
}

log() {
	echo "$@"
}

main() {
	for arg in "$@"; do
		shift
		case "$arg" in
		--help|-h)
			echo "Usage: $(basename "$0") [arg0] [argv...]"
			return
			;;
		--)
			break
			;;
		*)
			log "Unknown argument: $arg"
			return 1
			;;
		esac
	done

	execArgs=( "$@" )
	if [[ ${#execArgs[@]} -eq 0 ]]; then
		log "Missing command to execute for fuzzing; see -h"
		return 1
	fi

	if [[ ! -f hashes.json ]]; then
		log "No hashes.json file found. Refer to the README for instructions."
		return 1
	fi

	updateKeys=()
	while read -d $'\n' -r key; do
		updateKeys+=( "$key" )
	done < <(jq -r 'to_entries | .[] | .key' hashes.json)

	if (( ${#updateKeys[@]} == 0 )); then
		log "No keys to update."
		return
	fi

	declare -A fakeHashes
	for key in "${updateKeys[@]}"; do
		fakeHashes["$key"]="sha256:$(generateHash)"
	done

	local oldHashesJSON=$(< hashes.json)
	for key in "${updateKeys[@]}"; do
		val="${fakeHashes["$key"]}"
		oldHashesJSON=$(jq \
			--arg key "$key" \
			--arg val "$val" \
			'.[$key] = $val' <<< "$oldHashesJSON")
	done
	echo "$oldHashesJSON" > hashes.json

	foundHashKeys=()
	foundHashes=()

	while :; do
		set +e
		cmdOutput=$("${execArgs[@]}" 2>&1)
		status=$?
		set -e

		found=
		for key in "${!fakeHashes[@]}"; do
			hash="${fakeHashes["$key"]}"

			result=$(grep -A 1 -F "  wanted: $hash" <<< "$cmdOutput" 2> /dev/null || true)
			if [[ "$result" == "" ]]; then
				continue
			fi

			gotHash=$(grep -oP "^  got:    \Ksha256:.*" <<< "$result" | head -n1)
			if [[ "$gotHash" == "" ]]; then
				continue
			fi

			found=1
			foundHashKeys+=( "$key" )
			foundHashes+=( "$gotHash" )

			unset fakeHashes["$key"]
			log "Found hash for $key: $gotHash"
		done

		if [[ "$found" == "" ]]; then
			if (( status == 0 )); then
				log "No new hashes found. Finishing up."
				break
			fi

			log "No hashes found, and command exited with status $status."
			log "Command output:"
			log
			log "$cmdOutput"
			return 1
		fi

		# This is horribly inefficient, but whatever.
		# TODO: make this faster.
		for ((i = 0; i < ${#foundHashes[@]}; i++)); do
			key="${foundHashKeys[$i]}"
			val="${foundHashes[$i]}"
			oldHashesJSON=$(jq \
				--arg key "$key" \
				--arg val "$val" \
				'.[$key] = $val' <<< "$oldHashesJSON")
		done
		echo "$oldHashesJSON" > hashes.json
	done

	log "Updated hashes.json with new hashes."
	return
}

main "$@"
