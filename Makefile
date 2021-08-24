PROJECT := gov-hack-meta

default: usage

usage:
	bin/makefile/usage

data-copy:
	cp tmp/*.csv data/

data-slurp-hackerspace:
	rake data:slurp[https://hackerspace.govhack.org/,tmp,]

data: data-slurp-hackerspace data-copy

