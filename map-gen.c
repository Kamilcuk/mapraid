#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include "raid-map.h"
#include "stamp.h"

#define NAME "map-gen"

char buff[513];
unsigned int sec_off[max_dev][2];
int fd;
int pipes[max_dev],pfd[2];

void get_sector(int fd, char *buff, char *phrase, int pfd)
{
   //to jest procedura "childrena" skanuj±ca poszczególny dysk fizyczny
   
   //sec_off[0] - numer kolejnego sektora w woluminie logicznym
   //sec_off[1] - numer odpowiadaj±cego mu sektora na dysku fizycznym
   unsigned int sec_off[2];
    
   sec_off[1]=(unsigned int) -1;
   
   while ( read(fd,buff,512) == 512 )
     {
	sec_off[1]++;
	
	//sprawdzamy czy przeczytany sektor jest "ostemplowany"
	//je¶li nie to stamp_test==-1
	if ( (sec_off[0]=stamp_test(buff,phrase)) >= 0 )
	  {
	     // je¶li tak to odsy³amy info do "parenta"
	     write(pfd,&sec_off,8);
	  }
     }
   fprintf(stderr,"Done reading from device.\n");
   sec_off[0]=-1;
   write(pfd,&sec_off,8);
   fsync(pfd);
}

int main(int argc, char *argv[])
{
   int i, next=0;
   char c;
   pid_t cpid;
   
   
   if ( argc==1 )
     {
	puts("please give me some more data");
	return(0);
     }
   
   //dla ka¿dego dysku wej¶ciowego uruchamiamy "childrena" do skanowania
   for ( i=0; i<argc-2; i++ )
     {
	fd=open(argv[i+2],O_RDONLY);
	if ( fd <= 0 )
	  { perror(NAME); exit(1); }

	if (pipe(pfd) == -1)
	  { perror(NAME); exit(1); }

	if ( (cpid=fork()) <= 0 )
	  {
	     if ( cpid==-1 )
	       { perror(NAME); exit(1); }
	     else
	       {
		  close(pfd[0]);
		  get_sector(fd,buff,argv[1],pfd[1]);
		  exit(0);
	       }
	  }
	close(fd);
	pipes[i]=pfd[0];
	close(pfd[1]);
     }
   
   for ( i=0; i<argc-2; i++ )
     {
	if ( read(pipes[i],&(sec_off[i]),8) != 8 )
	  { perror(NAME); exit(1); }
	
     }
   
   init_map(1,argc,argv);

   for (;;)
     {
	c=-1;
	while ((++c<argc-2)&&(sec_off[(int)c][0]!=next));
	if (c==argc-2)
	  break;

	write_record(1,&c,&(sec_off[(int)c][1]));
	
	if ( read(pipes[(int)c],&(sec_off[(int)c]),8) != 8 )
	  { perror(NAME); exit(1); }
	
	next++;
     }
   fprintf(stderr,"Total %d of sectors found.\n",next);
   return(0);
}
