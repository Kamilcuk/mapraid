#define _LARGEFILE64_SOURCE

#include <unistd.h>
#include "stamp.h"
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <time.h>
#include <signal.h>

time_t StartTime,CurentTime,Time;
unsigned long long count;
off64_t file_size=0;

static void disp(int sig)
{
   unsigned long long counter;
   double speed;
   counter=count/2;
   CurentTime=time(NULL);
   fprintf ( stderr, "\r%.4llu.%.4llu.%.4llu.%.4llu.%.4llu.%.4llu.%.4llu kilobytes written",
             (counter >> 60 ) & 1023,
             (counter >> 50 ) & 1023,
             (counter >> 40 ) & 1023,
             (counter >> 30 ) & 1023,
             (counter >> 20 ) & 1023,
             (counter >> 10 ) & 1023,
             counter & 1023);
   speed=((double) count*512)/((double) (CurentTime-StartTime));
   if ( speed >= 1024*1024*1024 )
     {
        speed=speed/(1024*1024*1024);
        fprintf ( stderr, " (%6.2f GBps)",speed);
     }
   else { if ( speed >= 1024*1024 )
     {
        speed=speed/(1024*1024);
        fprintf ( stderr, " (%6.2f MBps)",speed);
     }
      else { if ( speed >= 1024 )
        {
           speed=speed/(1024);
           fprintf ( stderr, " (%6.2f KBps)",speed);
        }
         else
           fprintf ( stderr, " (%6.2f Bps)",speed);
      }
   }
   alarm(1);
}

static void disp_p(int sig)
{
   double progres;
   double speed;
   CurentTime=time(NULL);
   progres=((double) count*100)/((double) (file_size));
   fprintf(stderr,"\r%5.1f%% done.",progres);
   speed=((double) count*512)/((double) (CurentTime-StartTime));
   if ( speed >= 1024*1024*1024 )
     {
        speed=speed/(1024*1024*1024);
        fprintf ( stderr, " (%6.2f GBps)",speed);
     }
   else { if ( speed >= 1024*1024 )
     {
        speed=speed/(1024*1024);
        fprintf ( stderr, " (%6.2f MBps)",speed);
     }
      else { if ( speed >= 1024 )
        {
           speed=speed/(1024);
           fprintf ( stderr, " (%6.2f KBps)",speed);
        }
         else
           fprintf ( stderr, " (%6.2f Bps)",speed);
      }
   }
   alarm(1);
}

int main(int argc, char *argv[])
{
   int i,c;
   int fd=-1;
   char buff[513];
   extern char *optarg;
   char patern[PHR_LEN];
   patern[0]=0;
   
   while ( c != -1)
     {
	c=getopt(argc,argv,"f:p:h");
	switch (c)
	  {
	   case 'h':
	     printf("\nUsage: phrase-gen [options]\n");
	     printf(" -h\t\tprint this help,\n");
	     printf(" -f <file name>\toutput file name,\n");
	     printf(" -p <patern>\tinclude the patern in stamps.\n");
	     break;
	   case 'f':
	     if ( (fd=open(optarg,O_LARGEFILE|O_WRONLY)) == -1 )
	       {
		  perror("phrase-gen");
		  exit(1);
	       }
	     file_size=lseek64(fd,0,SEEK_END);
	     (void)lseek(fd,0,SEEK_SET);
	     if (file_size>MAX_DEV_SIZE)
	       fprintf(stderr,"WARNING: Device is too large.\n"
		       "The created map will cover only %llu bytes\n",
		       MAX_DEV_SIZE);
	     fprintf(stderr,"Size=%lli",file_size);
	     file_size=file_size/512;
	     fprintf(stderr,"(=%lli sectors)\n",file_size);
	     break;
	   case 'p':
	     if ( strlen(optarg)>PHR_LEN )
	       {
		  fprintf(stderr,
			  "ERROR! Patern too long. "
			  "The maximum lenght is %d.\n",
			  PHR_LEN);
		  exit(1);
	       }
	     strncpy(patern,optarg,PHR_LEN);
	     break;
	  }
     }

   if ( fd==-1)
     fd=1;
   if ( file_size < 1 )
     {
	signal(SIGALRM, disp);
	file_size=MAX_DEV_SIZE >> 9;
     }
   else
     {
	signal(SIGALRM, disp_p);
     }   
   alarm(2);
   StartTime=time(NULL);
   Time=StartTime;
   
   for ( count = 0; count < file_size ; count++ )
     {
	stamp_gen(buff,count,patern);
	if ( write(fd,buff,512) != 512 )
	  {
	     perror("phrase-gen");	
	     break;
	  }
	
     }
   
   return(0);
}
