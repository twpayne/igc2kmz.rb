all: ext/ccoord/ccoord.so ext/cxc/cxc.so

distclean: clean
	rm ext/ccoord/Makefile
	rm ext/cxc/Makefile

clean: ext/ccoord/Makefile ext/cxc/Makefile
	cd ext/ccoord && make clean
	cd ext/cxc && make clean

ext/ccoord/ccoord.so: ext/ccoord/Makefile ext/ccoord/ccoord.c
	cd ext/ccoord && make

ext/ccoord/Makefile: ext/ccoord/extconf.rb
	cd ext/ccoord && ruby extconf.rb

ext/cxc/cxc.so: ext/cxc/Makefile ext/cxc/cxc.c
	cd ext/cxc && make

ext/cxc/Makefile: ext/cxc/extconf.rb
	cd ext/cxc && ruby extconf.rb

check:
	ruby test/test_lib.rb
