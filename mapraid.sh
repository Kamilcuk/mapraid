#!/bin/bash
set -euo pipefail

VERSION="raidmap_v0.2.0"
if ${DEBUG:=false}; then set -x; fi;

# Functions ##########################

usage() {
	cat <<EOF
Usage: 
	$0 [OPTIONS] <mark|map> file [blocksize:=512]
	$0 [OPTIONS] restore mapfile output [blocksize:=512]

Options:
	-h --help     - print this help and exit
	-p            - print progressbar
	-v --verbose  - increase verbose level
	-i            - pring when ignoring blocks when mapping
	-f --force    - don't ask for confirmation on deleting files

Modes:
	mark    - writes blocksize chunks to file containing:
	          <version string> <chunk number> <string of '0' characters> <md5sum of leading characters>\n
	map     - reads blocksize chunks from file.
			  Checks if chunks is valid and then extracts <chunk number> from each chunk.
			  Prints out mapping information as
			    <filename> <chunk number in filename> <extracted chunks number>
	restore - reads mapfile in format as outputted by map
			  copies block by block data from input files (contained in mapfile) to output

Usage example:
	\$ # create raid device from some loop files
	\$ mdadm --create .... /dev/md100 /dev/loop1 /dev/loop2 /dev/loop3
	\$ # mark sectors on raid
	\$ $0 -p mark /dev/md100
	\$ mdam --stop /dev/md100
	\$ # map marked sectors to mapfile
	\$ $0 -p map /dev/loop1 > mapfile
	\$ $0 -p map /dev/loop2 >> mapfile
	\$ $0 -p map /dev/loop3 >> mapfile
	\$ # then you can restore raid content from /dev/loop{1,2,3} with
	\$ $0 -p restore mapfile outputdevice

Written by Kamil Cukrowski.
Licensed jointly under MIT License and Beerware License.
EOF
	if [ -n "${1:-}" ]; then
		echo
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
	echo -ne "[${pre}${post}] (${val}/${max})"$'\r' >&2
	if [ "$val" -eq "$max" ]; then echo >&2; fi
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
		echo "$@" >&2
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

ignoreprint() {
	local -g IGNOREPRINT
	if ! ${IGNOREPRINT:-false}; then return; fi
	local cnt
	cnt=$1
	shift
	echo "# ignoring block $cnt:" "$@" >&2
}

confirm() {
	local -g FORCE
	if ${FORCE:-false}; then return; fi
	local file tmp
	file=$1
	echo "This operation will erase all data on file '$file'."
	echo "Are you sure you want to continue?"
	read -p 'Answer [y|n]: ' tmp
	case "$tmp" in Y*|y*) ;; *) exit; ;; esac
}

mode:mark() {
	local -g DEV DEVBCNT BS
	local -i cnt 
	local temp

	confirm "$DEV"

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

		echo "$DEV $cnt $readcnt"

		((++cnt))
	done

	rm "$temp" "$temp2"
	trap '' EXIT
	assert [ "$cnt" -eq "$DEVBCNT" ] "Internal read error: cnt=$cnt != devbcnt=$DEVBCNT"

	verbose 0 "Done. IgnoredBlocksCnt=$ignored"
}

mode:restore() {
	local -g BS
	local -i cnt mapfilelen outfilelen_shouldbe
	local mapfile outfile tmp i tmp2 infiles tmp3
	mapfile=$1
	outfile=$2
	BS=${3:-512}

	tmp=$(cut -d' ' -f1,2 "$mapfile" | uniq -d)
	assert [ -z "$tmp" ] "mapfile error:: duplicate in first and second column"
	tmp=$(cut -d' ' -f2 "$mapfile")
	for i in $tmp; do assert [ "$i" -eq "$i" ] "mapfile error: Value in second column is not a number: $i"; done
	tmp=$(cut -d' ' -f3 "$mapfile")
	for i in $tmp; do assert [ "$i" -eq "$i" ] "mapfile error: Value in third column is not a number: $i"; done
	tmp=$(uniq -d <<<"$tmp")
	assert [ -z "$tmp" ] "mapfile error: duplicate found in third column"
	
	infiles=$(cut -d' ' -f1 "$mapfile" | uniq)
	for i in $infiles; do assert [ -e "$i" ] "mapfile error: mentioned file '$i' that does not exists!"; done

	mapfilelen=$(wc -l "$mapfile" | cut -d' ' -f1)
	outfilelen_shouldbe=$((BS*mapfilelen))

	verbose 0 "Restoring $outfile of size blocksize=$BS*$mapfilelen from files:" $infiles

	confirm "$outfile"

	cnt=0
	while IFS=' ' read -r infile inblock outblock; do
		assert [ "$inblock" -eq "$inblock" ] "Error inblock=$inblock is not a number"
		assert [ "$outblock" -eq "$outblock" ] "Error outblock=$outblock is not a number"
		progressbar "$cnt" "$mapfilelen"
		verbose 1 "Coyping if=$infile skip=$inblock of=$outfile seek=$outblock"
		dd if="$infile" skip="$inblock" of="$outfile" seek="$outblock" bs="$BS" count=1 status=none
		((++cnt))
	done < <(sort -t' ' -n -k3 "$mapfile")

	progressbar "$cnt" "$mapfilelen"

	tmp=$(wc -c "$outfile" | cut -d' ' -f1)
	tmp2=$((mapfilelen*BS))
	assert [ "$tmp" -eq "$tmp2" ] "outputfile has different size then expected ! outfilelen=$tmp -eq (mapfilelen=$mapfilelen*BS=$BS)=$tmp2"

	verbose 0 "Success"
}

# Main ################################

tmp="${BASH_VERSION//.*}" 
if [ "$tmp" -lt 4 ]; then
	echo "ERROR: this scripts needs bash version at least 4" >&2
	exit 255
fi

hash bash >/dev/null 2>/dev/null
for i in getopt cmp dd md5sum; do
	if ! hash "$i" >/dev/null 2>/dev/null; then
		echo "ERROR: command '$i' was not found in PATH" >&2
		exit 255
	fi
done

OPTS=$(getopt -n "mapraid.sh" -o hpvif -l help,verbose,force -- "$@")
eval set -- "$OPTS"
while (($#)); do
	case "$1" in
		-h|--help) usage; exit 0; ;;
		-p) : ${PROGRESSBAR:=true}; ;;
		-v|--verbose) : ${VERBOSE_LVL:=0}; ((++VERBOSE_LVL)); ;;
		-i) : ${IGNOREPRINT:=true}; ;;
		-f|--force) : ${FORCE:=true}; ;;
		--|*) shift; break; ;;
	esac
	shift
done

if [ $# -lt 1 ]; then usage "Wrong number of arguments: $#:" "$@"; fi;

MODE=${1:-}
shift
case "$MODE" in
	mark|map) 
		if [ $# -ne 1 -a $# -ne 2 ]; then usage "Wrong number of arguments for mode $MODE: $#:" "$@"; fi;
		DEV=$1
		BS=${2:-512}
		if [ ! -e "$DEV" ]; then usage "File '$dev' does not exists"; fi;
		devsize=$(wc -c "$DEV" | cut -d' ' -f1)
		DEVBCNT=$((devsize/BS))
		assert [ $((devsize%BS)) -eq 0 ] "Size of '$DEV'=$devsize is not a multiplicity of blosize=$BS"

		verbose 1 "MODE=$MODE DEV=$DEV BS=$BS devsize=$devsize DEVBCNT=$DEVBCNT"

		"mode:${MODE}"
		;;
	restore)
		if [ $# -ne 2 -a $# -ne 3 ]; then usage "Wrong number of arguments for mode $MODE: $#:" "$@"; fi;
		mode:restore "$@"
		;;
	*) usage "Unknown mode $mode"; ;;
esac
