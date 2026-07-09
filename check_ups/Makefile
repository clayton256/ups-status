# make stand-alone command line tool

PROJ=check_ups

all: check_ups swiftver

cversion: check_ups.c
	gcc check_ups.c -framework IOKit -framework CoreFoundation  -o check_ups

swiftver: check_ups.swift
	swift build

clean:
	rm $(PROJ)

# end