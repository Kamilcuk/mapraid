#ifndef _RAID_MAP_H
#define _RAID_MAP_H

#define max_dev 64
#define dev_len 64

int init_map(int fd, int argc, char *argv[]);
int write_record(int fd, const void *d, const void *o);
int open_map(int fd, char *buff, char devices[][]);
int read_record(int fd, void *d, void *o);

#endif

