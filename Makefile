all: ext/ccgiarcsi/ccgiarcsi.so ext/ccoord/ccoord.so ext/cxc/cxc.so

distclean: clean
	rm ext/ccgiarcsi/Makefile
	rm ext/ccoord/Makefile
	rm ext/cxc/Makefile

clean: ext/ccgiarcsi/Makefile ext/ccoord/Makefile ext/cxc/Makefile
	rm ext/ccgiarcsi/ccgiarcsi.c
	cd ext/ccgiarcsi && make clean
	cd ext/ccoord && make clean
	cd ext/cxc && make clean

ext/ccgiarcsi/ccgiarcsi.so: ext/ccgiarcsi/Makefile ext/ccgiarcsi/ccgiarcsi.c
	cd ext/ccgiarcsi && make

ext/ccgiarcsi/Makefile: ext/ccgiarcsi/ccgiarcsi.c ext/ccgiarcsi/extconf.rb
	cd ext/ccgiarcsi && ruby extconf.rb

ext/ccgiarcsi/ccgiarcsi.c: ext/ccgiarcsi/ccgiarcsi.rl
	ragel $< | rlgen-cd -o $@ -G2

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
