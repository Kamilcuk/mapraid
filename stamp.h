#ifndef _STAMP_H_
#define _STAMP_H_

#define PHR_POS 128
#define PHR_LEN (512-PHR_POS)
#define MAX_DEV_SIZE \
   (((unsigned long long) ((unsigned int) -1)) << 9)

int stamp_test(char *buff,char *phrase);
void stamp_gen(char *buff,int nr,char *phrase);

#endif
