#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <errno.h>
#include "raid-map.h"

#define NAME NULL

#define write_map(fd,b,n) if ( (write(fd,b,n)!=n) ) \
   { perror(NAME); return(-1); }
#define read_map(fd,b,n) if ( (read(fd,b,n)!=n) ) \
   { perror(NAME); return(-1); }

char MapVersion[]="raid-map-0.0";

// procedura generuj±ca nag³ówek mapy
int init_map(int fd, int argc, char *argv[])
{
   int i;
   char c=0;
   // najpierw nazwa wersji
   write_map(fd, &MapVersion, strlen(MapVersion)+1);
   c=(char)(argc-2);
   
   // potem ilo¶æ dysków które by³y w macierzy
   write_map(fd, &c, 1);
   
   // nazwy devicków które by³u u¿ywane (oddzielona znakiem '\0')
   c=0;
   for ( i=0; i<argc-2; i++)
     {
	write_map(fd, argv[i+2], strlen(argv[i+2]));
	write_map(fd, &c, 1);
     }
   
   //znak koñca nag³ówka: '+++'
   c='+';
   write_map(fd, &c, 1);
   write_map(fd, &c, 1);
   write_map(fd, &c, 1);
   return(1);
}

// procedura parsuj±ca nag³ówek mapy (sk³adnia patrz powy¿ej)
int open_map(int fd, char *buff, char devices[][])
{
   char c;
   int i,j,k;

   read_map(fd, buff, strlen(MapVersion)+1);
   if ( memcmp(buff, MapVersion, strlen(MapVersion)+1) != 0 )
     {
	fprintf(stderr, "Unknown raid-map version!\n(%s!=%s)\n",buff,MapVersion);
	exit(1);
     }
   
   read_map(fd, &c, 1);
   if ( (k=c) > max_dev )
     {
	fprintf(stderr, "Error in raid-map header!\n");
	exit(1);
     }
   
   // je¶li devices == NULL to oznacza, ¿e nie interesuj± nas nazwy plików
   // je¶li nie to trzeba je odczytaæ
   if ( devices == NULL )
     {
	for (i=0; i<k; i++)
	  {
	     j=0;
	     c=1;
	     while ( (c!=0) && (j++<dev_len))
	       read_map(fd, &c, 1);
	     if ( c!=0 )
	       {
		  fprintf(stderr, "Error in raid-map header!\n");
		  exit(1);
	       }
	  }
     }
   else
     {
	for (i=0; i<k; i++)
	  {
	     j=0;
	     devices[i][0]=1;
	     while ( (devices[i][j]!=0) && (j++<dev_len))
	       read_map(fd, devices[i]+j, 1);
	     if ( c!=0 )
	       {
		  fprintf(stderr, "Error in raid-map header!\n");
		  exit(1);
	       }
	  }
     }
   
   // na koñcy powinien byæ znak koñca nag³ówka
   read_map(fd, buff, 3);
   if ( (buff[0]!='+') ||
	(buff[1]!='+') ||
	(buff[2]!='+') )
     {
	fprintf(stderr, "Error in raid-map header!\n");
	exit(1);
     }
	
   return(1);
}

int read_record(int fd, void *d, void *o)
{
   read_map(fd,d,1);
   read_map(fd,o,4);
   return(1);
}

int write_record(int fd, const void *d, const void *o)
{
   write_map(fd,d,1);
   write_map(fd,o,4);
   return(1);
}
