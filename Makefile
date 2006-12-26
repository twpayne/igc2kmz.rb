all: ext/ccoord/ccoord.so ext/coptima/coptima.so

distclean: clean
	rm ext/ccoord/Makefile
	rm ext/coptima/Makefile

clean: ext/ccoord/Makefile ext/coptima/Makefile
	cd ext/ccoord && make clean
	cd ext/coptima && make clean

ext/ccoord/ccoord.so: ext/ccoord/Makefile ext/ccoord/ccoord.c
	cd ext/ccoord && make

ext/ccoord/Makefile: ext/ccoord/extconf.rb
	cd ext/ccoord && ruby extconf.rb

ext/coptima/coptima.so: ext/coptima/Makefile ext/coptima/coptima.c
	cd ext/coptima && make

ext/coptima/Makefile: ext/coptima/extconf.rb
	cd ext/coptima && ruby extconf.rb

check:
	ruby test/test_lib.rb
