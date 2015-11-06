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
#ifndef _STAMP_H_
#define _STAMP_H_

#define PHR_POS 128
#define PHR_LEN (512-PHR_POS)
#define MAX_DEV_SIZE \
   (((unsigned long long) ((unsigned int) -1)) << 9)

int stamp_test(char *buff, char *phrase);
void stamp_gen(char *buff, int nr, char *phrase);

#endif
