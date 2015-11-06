MAKEFLAGS="-j 3"
CC="gcc"
ARCH=i585
CFLAGS="-Wall -O2 -march=$(ARCH)"


ALL: map-gen phrase-gen restore


raid-map.o: raid-map.c raid-map.h
	$(CC) $(CFLAGS) -c raid-map.c

stamp.o: stamp.c stamp.h MD5Transform.h
	$(CC) $(CFLAGS) -c stamp.c

map-gen.o: map-gen.c raid-map.h stamp.h
	$(CC) $(CFLAGS) -c map-gen.c

map-gen: map-gen.o raid-map.o stamp.o
	$(CC) $(CFLAGS) -s -o map-gen map-gen.o raid-map.o stamp.o

phrase-gen.o: phrase-gen.c stamp.h
	$(CC) $(CFLAGS) -c phrase-gen.c

phrase-gen: phrase-gen.o stamp.o
	$(CC) $(CFLAGS) -s -o phrase-gen phrase-gen.o stamp.o

restore.o: restore.c raid-map.h
	$(CC) $(CFLAGS) -c restore.c
 
restore: restore.o raid-map.o
	$(CC) $(CFLAGS) -s -o restore restore.o raid-map.o
       
clean:	
	rm -f map-gen phrase-gen restore *.o


