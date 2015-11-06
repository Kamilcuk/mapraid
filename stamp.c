#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "MD5Transform.h"
#include "stamp.h"

int stamp_test(char *buff,char *phrase)
{
   __u32 md5_sum[4];
   char buff2[33];
   int i,j;
   
   for (j=0;j<11;j++)
     if ((buff[j]<'0')||(buff[j]>'9'))
       return(-1);
   for (i=11;i<64;i++)
     if (buff[i]!=' ')
       return(-2);
   for ( j = 0; j < 4; j++ )
     md5_sum[j] = 0;
   MD5Transform(md5_sum,(__u32 *)buff);
   snprintf(buff2,33,"%.8x%.8x%.8x%.8x",md5_sum[0],md5_sum[1],md5_sum[2],md5_sum[3]);
   if ( memcmp(buff+64,buff2,32) != 0 )
     return(-3);
   for (i=96;i<128;i++)
     if (buff[i]!=' ')
       return(-4);
   if ( memcmp(buff+128,phrase,strlen(phrase)) != 0 )
     return(-5);
   for (i=128+strlen(phrase);i<511;i++)
     if (buff[i]!=' ')
       return(-6);
   if (buff[511]!='\n')
     return(-7);
   return((unsigned int) atol(buff));
}

void stamp_gen(char *buff, int nr, char *phrase)
{
   __u32 md5_sum[4];
   int i, j;
   
   for ( i = 0; i < 511; i++ )
     buff[i]=' ';
   if ( phrase != NULL )
     {
	strcpy(buff+128,phrase);
	buff[128+strlen(phrase)]=' ';
     }
   buff[511]='\n';
   buff[512]=0;
   snprintf(buff,100,"%.11d",nr);
   buff[11]=' ';
   for ( j = 0; j < 4; j++ )
     md5_sum[j] = 0;
   MD5Transform(md5_sum,(__u32 *)buff);
   snprintf(buff+64,64,"%.8x%.8x%.8x%.8x",md5_sum[0],md5_sum[1],md5_sum[2],md5_sum[3]);
   buff[96]=' ';
}
