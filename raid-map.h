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
#ifndef _RAID_MAP_H
#define _RAID_MAP_H

#define max_dev 64
#define dev_len 64

int init_map(int fd, int argc, char *argv[]);
int write_record(int fd, const void *d, const void *o);
int open_map(int fd, char *buff, char **devices);
int read_record(int fd, void *d, void *o);

#endif
