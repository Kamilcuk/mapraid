#!/bin/bash
set -euo pipefail

VERSION="raidmap_v0.2.0"

# Functions ##########################

usage() {
	cat <<EOF
Usage: 
	$0 <mark|map> file [blocksize:=512]

Written by Kamil Cukrowski.
Licensed jointly under MIT License and Beerware License.
EOF
}

progressbar() {
	local -i val
	max=40
	val=$(($1*40/100))
	echo ' [$(printf '#%.0s' $(seq $val))$(printf '#%.0s' $(seq $((max-val)))] (${1}%)'$'\r'
}

assert() {
	if ! "${@:1:$(($#-1))}"; then 
		echo "Assertion failed in ${FUNCNAME[-1]}:" >&2
		echo " ${@:$#}" >&2;
		exit 1;
	fi
}		

debug() {
	if ${DEBUG:-false}; then
		echo "DBG: $@" >&2
	fi
}	

mark() {
	local -g VERSION dev devsize devbs tmp bs
	local -i cnt i strlen tmplen
	local md5sum
	exec 10>"$dev"
	cnt=0
	while [ "$cnt" -lt "$devbs" ]; do

		echo -n "$VERSION $cnt " >"$tmp"
		md5sum=$(md5sum "$tmp" | cut -d' ' -f1)
		echo -n "$md5sum" >>"$tmp"
		strlen=$(wc -c "$tmp" | cut -d' ' -f1)
		assert [ "$strlen" -le "$bs" ] "block $cnt: strlen=$strlen -gt bs=$bs"
		printf ' ' >>"$tmp"
		printf '0%.0s' $(seq 3 $((bs-strlen))) >>"$tmp"
		echo >>"$tmp"
		tmplen=$(wc -c "$tmp" | cut -d' ' -f1)
		assert [ "$tmplen" -eq "$bs" ] "block $cnt: Internal error - tmplen=$tmplen not equal bs"
		debug "Write '$VERSION $cnt $md5sum' to file, length=$tmplen"
		cat "$tmp" >&10

		((++cnt))
	done
	exec 10>&-
}

readn() {
	# read eaxactly $1 characters using read
	local char
	local -i num
	num=$1
	shift
	while ((num--)); do
		if ! LANG=C IFS= read "$@" -r -d '' -n 1 char; then
			return 1
		fi
		echo -n "$char"
	done
}

map() {
	local -g VERSION dev devsize devbs tmp bs
	local -i cnt readcnt
	local str md5sum version readmd5sum rest
	exec 10<"$dev"
	cnt=0
	while line=$(readn $bs -u 10); do
		read -r version readcnt readmd5sum rest <<<"$line"

		debug "$cnt Read: '$version $readcnt $readmd5sum $rest'"
		if [ ! "$version" = "$VERSION" ]; then
			echo "ignoring block $cnt: version is wrong: $version != $VERSION" >&2
			echo "ignoring block $cnt: farbage in input" >&2
			continue
		fi
		str="$version $readcnt $readmd5sum"
		strlen=$(echo -n "$str" | wc -c)
		str="$(printf '0%.0s' $(seq 3 $((bs-strlen))) )"	
		if [ ! "$rest" = "$str" ]; then
			echo "ignoring block $cnt: bad zeros on end of line $(echo "$rest"|wc -c) != $(echo "$str"|wc -c) -> rest=$rest" >&2
			echo "Probably you specified bad blocksize." >&2
			continue;
		fi

		md5sum=$(echo -n "$version $readcnt " | md5sum - | cut -d' ' -f1)
		assert [ "$md5sum" = "$readmd5sum" ] "block $cnt: md5sum is wrong: $md5sum != $readmd5sum"
		echo "$cnt -> $readcnt"

		((++cnt))
	done
	exec 10<&-
	assert [ "$cnt" -eq "$devbs" ] "Read error: cnt=$cnt != devbs=$devbs. Read count error."
}

# Main ################################

mode=${1:-}
case "$mode" in
mark|map) ;;
*)
	usage
	echo "ERR: Unknown mode $mode" >&2
	exit 1
	;;
esac
shift
dev=$1
shift
bs=${1:-512}

devsize=$(wc -c "$dev" | cut -d' ' -f1)
devbs=$((devsize/bs))
assert [ $((devsize%bs)) -eq 0 ] "((devsize=$devsize%bs=$bs))=$((devsize%bs)) -gt 0"

tmp=$(mktemp)
trap 'rm $tmp' EXIT

debug "mode=$mode dev=$dev bs=$bs devsize=$devsize devbs=$devbs tmp=$tmp"

$mode
