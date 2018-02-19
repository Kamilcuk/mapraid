#!/bin/bash
set -euo pipefail

assert() {
	if ! "${@:1:$(($#-1))}"; then 
		echo "${@:$#}" >&2;
		exit 1;
	fi
}			

test1() {
	"$mapraid" mark image 128
	out=$("$mapraid" map image 128)
	shouldbe=$(for i in $(seq 0 9); do echo "$i -> $i"; done)
	assert [ "$out" = "$shouldbe" ] "test1 error $out"
	echo "test1 ok"
}

test2() {
	dd if=image of=image2 count=5 bs=128 skip=5 status=none
	dd if=image of=image2 count=5 bs=128 seek=5 status=none
	out=$("$mapraid" map image2 128)
	shouldbe=$(cnt=0; for i in $(seq 5 9) $(seq 0 4); do echo "$cnt -> $i"; ((cnt++)); done)
	assert [ "$out" = "$shouldbe" ] "test2 error"	
	echo test2 ok
}
test3() {
	set -x
	loop=/dev/loop2000
	md=/dev/md250
	chunk=128
	res=/tmp/res.

	trap_exit() {
		sudo mdadm --stop $md ||:
		sudo losetup -d ${loop}{1,2,3} ||:
		sudo losetup -d disc{1,2,3} ||:
		rm -v disc{1,2,3} ||:
	}
	trap 'trap_exit' EXIT
	trap_exit

	truncate --size 192K disc{1,2,3}
	for i in 1 2 3; do
		sudo losetup $loop$i disc$i
	done
	sudo mdadm --create --chunk=$chunk --raid-devices=3 --level=5 --metadata=0.90 --verbose \
		$md ${loop}{1,2,3}
	sudo chown $UID $md
	sync

	"$mapraid" mark $md $chunk
	"$mapraid" map $md $chunk

	sudo mdadm --stop $md
	sudo losetup -d ${loop}{1,2,3}
	trap '' EXIT

	"$mapraid" map disc1 $chunk
	"$mapraid" map disc2 $chunk
	"$mapraid" map disc3 $chunk
}

mapraid=$(readlink -f ./mapraid.sh)
mkdir -p /tmp/10
cd /tmp/10
truncate image --size $((128*10))

test1
test2
test3
