#!/bin/bash
set -euo pipefail
set -x

assert() {
	if ! "${@:1:$(($#-1))}"; then 
		echo "Assertion '${@:1:$(($#-1))}' failed in ${FUNCNAME[-1]}:" >&2
		echo " ${@:$#}" >&2;
		exit 1;
	fi
}			

mapraid=$(readlink -f ./mapraid.sh)
mapraid() {
	"$mapraid" "$@"
}

test1() {
	mapraid mark -f image 128
	out=$(mapraid map image 128)
	shouldbe=$(for i in $(seq 0 9); do echo "image $i $i"; done)
	assert [ "$out" = "$shouldbe" ] "test1 error $out"
	echo "$out" > mapfile
	mapraid restore -f mapfile image_restored 128
	assert cmp image image_restored "test1 error restoring file"
	echo "test1 ok"
}

test2() {
	dd if=image of=image2 count=5 bs=128 skip=5 status=none
	dd if=image of=image2 count=5 bs=128 seek=5 status=none
	out=$(mapraid map image2 128)
	shouldbe=$(cnt=0; for i in $(seq 5 9) $(seq 0 4); do echo "image2 $cnt $i"; ((cnt++)); done)
	assert [ "$out" = "$shouldbe" ] "test2 error"	
	echo "$out" > mapfile
	mapraid restore -f mapfile image_restored 128
	assert cmp image image_restored "test2 error restoring file"
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

	"$mapraid" mark -f $md $chunk
	cat $md > disc

	sudo mdadm --stop $md
	sudo losetup -d ${loop}{1,2,3}
	trap '' EXIT

	"$mapraid" map disc1 $chunk >mapfile
	"$mapraid" map disc2 $chunk >>mapfile
	"$mapraid" map disc3 $chunk >>mapfile

	"$mapraid" restore -f mapfile disc_restored $chunk
	assert cmp disc disc_restored "test3 error restoring file"

}

mkdir -p /tmp/10
cd /tmp/10
truncate image --size $((128*10))

test1
test2
test3
