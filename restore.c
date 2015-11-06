/*
	Copyright (C) 2015 Grzegorz Sójka, Kamil Cukrowski
	This file is part of mapraidgen.

    mapraidgen is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    mapraidgen is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Foobar.  If not, see <http://www.gnu.org/licenses/>.
*/
#define _LARGEFILE64_SOURCE

#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdlib.h>
#include <errno.h>
#include "raid-map.h"

#define NAME "restore"

char buff[512], next = 0;
int fd[64];

int main(int argc, char *argv[])
{

	unsigned int i;
	off64_t offset;
	char c;
	char dev[64][64];

	if (argc == 1) {
		puts("please give me some more data");
		return (1);
	}

	for (i = 0; i < argc - 1; i++) {
		fd[i] = open(argv[i + 1], O_RDONLY);
		if (fd[i] <= 0) {
			perror(NAME);
			return (-1);
		}
	}

	open_map(0, buff, (char **)dev);

	while (read_record(0, &c, &i) == 1) {
		// "konwersja" int -> off64_t
		offset = i;
		offset = offset * 512;

		// znajd¼ sektor
		if (lseek64(fd[(int)c], offset, SEEK_SET) != i * 512) {
			perror(NAME);
			return (1);
		}
		//odczytaj
		if (read(fd[(int)c], buff, 512) != 512) {
			perror(NAME);
			return (1);
		}
		//prze¶lij dalej
		if (write(1, buff, 512) != 512) {
			perror(NAME);
			return (1);
		}

		next++;
	}

	fprintf(stderr, "Total %d of sectors found.\n", next);
	return (0);

}
