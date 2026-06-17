# make stand-alone command line tool

all:
	gcc myups.c -framework IOKit -framework CoreFoundation  -o myups

