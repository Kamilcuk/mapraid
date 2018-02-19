#!/bin/bash
set -euo pipefail

VERSION="raidmap_v0.2.0"
if ${DEBUG:=false}; then set -x; fi;

# Functions ##########################

usage() {
	cat <<EOF
Usage: 
	$0 [OPTIONS] <mark|map> file [blocksize:=512]

Options:
	-h --help     - print this help and exit
	-p            - print progressbar
	-v --verbose  - increase verbose level
	-i            - don't pring ignored blocks when mapping

Written by Kamil Cukrowski.
Licensed jointly under MIT License and Beerware License.
EOF
	if [ -n "${1:-}" ]; then
		echo "ERROR:" "$@" >&2
		exit 1
	fi
}

progressbar() {
	local -g PROGRESSBAR
	if ! ${PROGRESSBAR:-false}; then return; fi
	local -g -i PROGRESSBAR_LENMAX
	local -i val max len notlen lenmax=${PROGRESSBAR_LENMAX:-40}
	local pre post
	val=$1
	max=$2
	len=$((lenmax*val/max))
	notlen=$((lenmax-len))
	if [ "$len" -eq 0 ]; then pre=""; else
		pre=$(printf '#%.0s' $(seq $len))
	fi
	if [ "$notlen" -eq 0 ]; then post=""; else
		post=$(printf ' %.0s' $(seq $notlen))
	fi
	echo -ne "[${pre}${post}] (${val}/${max})"$'\r'
	if [ "$val" -eq "$max" ]; then echo; fi
}

assert() {
	if ! "${@:1:$(($#-1))}"; then 
		echo "Assertion '${@:1:$(($#-1))}' failed in ${FUNCNAME[-1]}:" >&2
		echo " ${@:$#}" >&2;
		exit 1;
	fi
}		

verbose() {
	local -g VERBOSE_LVL
	if [ "${VERBOSE_LVL:-0}" -gt "$1" ]; then
		shift
		echo "$@"
	fi
}

data_create() {
	local -g VERSION BS
	local -i outlen num md5sumlen=32
	local out fill
	num=$1
	out=$2

	str="$VERSION $num "
	strlen=${#str}
	((fill=strlen+md5sumlen+2))
	assert [ "$BS" -gt "$fill" ] "blocksize=$BS is too small!"
	((fill=BS-fill))
	fill=$(seq "$fill")
	{
		echo -n "$str"
		printf '0%.0s' $fill
		echo -n ' '
	} >"$out"
	md5sum=$(md5sum "$out" | cut -d' ' -f1)
	echo "$md5sum" >>"$out"

	outlen=$(wc -c "$out" | cut -d' ' -f1)
	assert [ "$outlen" -eq "$BS" ] "block $num: outlen=$outlen -gt BS=$BS"
	
	verbose 2 "Write '$VERSION $num <#${#fill} 0s> $md5sum' to file '$out', length=$outlen"
}

mode:mark() {
	local -g DEV DEVBCNT BS
	local -i cnt 
	local temp

	temp=$(mktemp)
	trap 'echo "INTERNAL ERROR: last command returned $?."; rm "$temp";' EXIT
	verbose 1 "temp=$temp"

	verbose 0 "Starting marking '$DEV' with '$DEVBCNT' blocks"

	for ((cnt = 0; cnt < DEVBCNT; ++cnt)); do
		progressbar "$cnt" "$DEVBCNT"
		data_create "$cnt" "$temp"
		verbose 1 "Write block $cnt with '$(cut -d' ' -f1,2,4 $temp)'"
		dd if="$temp" of="$DEV" seek="$cnt" bs="$BS" count=1 status=none
	done

	progressbar "$cnt" "$DEVBCNT"
	rm "$temp"
	trap '' EXIT
	assert [ "$cnt" -eq "$DEVBCNT" ] "Internal error: cnt=$cnt != devbcnt=$DEVBCNT"

	verbose 0 "Done"
}

ignoreprint() {
	local -g IGNOREPRINT
	if ! ${IGNOREPRINT:-true}; then return; fi
	local cnt
	cnt=$1
	shift
	echo "ignoring block $cnt:" "$@"
}

mode:map() {
	local -g VERSION DEV DEVBCNT BS
	local -i cnt ret ignored=0
	local temp temp2
	local readversion readcnt readfill readmd5sum

	temp=$(mktemp)
	temp2=$(mktemp)
	trap 'echo "INTERNAL ERROR: last command returned $?."; rm "$temp" "$temp2";' EXIT
	verbose 1 "temp=$temp temp2=$temp2"

	verbose 0 "Starting mapping '$DEV' with '$DEVBCNT' blocks"

	cnt=0
	while dd if="$DEV" of="$temp2" bs="$BS" skip="$cnt" count=1 status=none ; do

		progressbar "$cnt" "$DEVBCNT"

		tmp="$(wc -c "$temp2" | cut -d' ' -f1)"
		if [ "$tmp" -eq 0 ]; then break; fi; # EOF
		assert [ "$tmp" -eq "$BS" ] "Error - readed file is not blocksize=$BS bytes long"
		if ! IFS=' ' read -r readversion readcnt readfill readmd5sum <"$temp2"; then 
			ignoreprint "$cnt" "input is not parsable"
			((++ignored)); ((++cnt)); continue;
		fi

		verbose 2 "$cnt Read: '$readversion $readcnt $readfill $readmd5sum'"
		if [ "$readversion" != "$VERSION" ]; then
			ignoreprint "$cnt" "version is not valid: '$VERSION' != '$readversion'"
			((++ignored)); ((++cnt)); continue;
		fi

		data_create "$readcnt" "$temp"
		cmp -s "$temp" "$temp2" && ret=$? || ret=$?
		if [ "$ret" -ne 0 ]; then
			assert [ "$ret" -eq 1 ] "Comparing files '$temp' '$temp2' error"
			ignoreprint "$cnt" "md5sum error"
			((++ignored)); ((++cnt)); continue;
		fi

		echo "$cnt -> $readcnt"

		((++cnt))
	done

	progressbar "$cnt" "$DEVBCNT"
	rm "$temp" "$temp2"
	trap '' EXIT
	assert [ "$cnt" -eq "$DEVBCNT" ] "Internal read error: cnt=$cnt != devbcnt=$DEVBCNT"

	verbose 0 "Done. IgnoredBlocksCnt=$ignored"
}

# Main ################################

OPTS=$(getopt -n "mapraid.sh" -o hpvi -l help,verbose -- "$@")
eval set -- "$OPTS"
while (($#)); do
	case "$1" in
		-h|--help) usage; exit 0; ;;
		-p) : ${PROGRESSBAR:=true}; ;;
		-v|--verbose) : ${VERBOSE_LVL:=0}; ((++VERBOSE_LVL)); ;;
		-i) : ${IGNOREPRINT:=false}; ;;
		--|*) shift; break; ;;
	esac
	shift
done

if [ $# -ne 3 ]; then usage "Wrong number of arguments: $#:" "$@"; fi;

MODE=${1:-}
case "$MODE" in
	mark|map) ;;
	*) usage "Unknown mode $mode"; ;;
esac
shift
DEV=$1
shift
BS=${1:-512}

devsize=$(wc -c "$DEV" | cut -d' ' -f1)
DEVBCNT=$((devsize/BS))
assert [ $((devsize%BS)) -eq 0 ] "Size of '$DEV'=$devsize is not a multiplicity of blosize=$BS"

verbose 1 "MODE=$MODE DEV=$DEV BS=$BS devsize=$devsize DEVBCNT=$DEVBCNT"

"mode:${MODE}"
