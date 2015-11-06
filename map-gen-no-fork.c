#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>
#include "raid-map.h"
#include "stamp.h"

char buff[513];
//__u32 *buff32[64];
int offset[max_dev],sector[max_dev];
int fd[max_dev];

void get_sector(int i, char *buff, char *phrase)
{
   if ( read(fd[i],buff,512) != 512 )
     {
	sector[i]=-1;
	fprintf(stderr,"Done reading from device i=%d\n",i);
     }
   else
     offset[i]++;
   while ((sector[i]>=0)&&
	  ( (sector[i]=stamp_test(buff,phrase))<0))
     {
	if ( read(fd[i],buff,512) != 512 )
	  {
	     sector[i]=-1;
	     fprintf(stderr,"Done reading from device i=%d\n",i);
	  }
	else
	  {
	     sector[i]=0;
	     offset[i]++;
	  }
     }
}

int main(int argc, char *argv[])
{
//   __u32 md5_sum[4];
   int i, next=0;
   char c;
//   unsigned char *buff2;
   if ( argc==1 )
     {
	puts("please give me some more data");
	return(1);
     }
   
/*   for ( i = 0; i < 511; i++ )
     buff2[i]=' ';
   strcpy(buff2+128,argv[1]);
   buff2[128+strlen(argv[1])]=' ';
   buff2[511]='\n';
   buff2[512]=0;*/
   
   for ( i=0; i<argc-2; i++ )
     {
	fd[i]=open(argv[i+2],O_RDONLY);
	if ( fd[i] <= 0 )
	  fprintf(stderr,"Error opening file %s,i=%d.",argv[i+1],i);
//	buff32[i]=buff[i];
	offset[i]=-1;
	sector[i]=0;
	get_sector(i,buff,argv[1]);
//	printf("sector[%i]=%d,offset=%d\n", i,sector[i],offset[i]);
//	  puts(buff[i]);
     }
 
   init_map(1,argc,argv);

   for (;;)
     {
	c=-1;
	while ((++c<argc-2)&&(sector[(int)c]!=next));
	if (c==argc-2)
	  break;
	write_record(1,&c,&(offset[(int)c]));
	
//	fprintf(stderr,"Sector %d found at %d, offset %d.\n",next,c,offset[(int)c]);
	next++;
	get_sector(c,buff,argv[1]);
     }
   fprintf(stderr,"Total %d of sectors found.\n",next);
   return(0);
}

// gcc -O2 -Wall -o map-gen map-gen.c
