all: \
	ext/ccgiarcsi/ccgiarcsi.so \
	ext/ccoord/ccoord.so \
	ext/cgeometry/cgeometry.so \
	ext/cxc/cxc.so \
	ext/ratcliff/ratcliff.so

distclean: clean
	rm ext/ccgiarcsi/Makefile
	rm ext/ccoord/Makefile
	rm ext/cgeometry/Makefile
	rm ext/cxc/Makefile
	rm ext/ratcliff/Makefile

clean: \
	ext/ccgiarcsi/Makefile \
	ext/ccoord/Makefile \
	ext/cgeometry/Makefile \
	ext/cxc/Makefile \
	ext/ratcliff/Makefile
	rm ext/ccgiarcsi/ccgiarcsi.c
	cd ext/ccgiarcsi && make clean
	cd ext/ccoord && make clean
	cd ext/cgeometry && make clean
	cd ext/cxc && make clean
	cd ext/ratcliff && make clean

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

ext/cgeometry/cgeometry.so: ext/cgeometry/Makefile ext/cgeometry/cgeometry.c
	cd ext/cgeometry && make

ext/cgeometry/Makefile: ext/cgeometry/extconf.rb
	cd ext/cgeometry && ruby extconf.rb

ext/cxc/cxc.so: ext/cxc/Makefile ext/cxc/cxc.c
	cd ext/cxc && make

ext/cxc/Makefile: ext/cxc/extconf.rb
	cd ext/cxc && ruby extconf.rb

ext/ratcliff/ratcliff.so: ext/ratcliff/Makefile ext/ratcliff/ratcliff.c
	cd ext/ratcliff && make

ext/ratcliff/Makefile: ext/ratcliff/extconf.rb
	cd ext/ratcliff && ruby extconf.rb

check:
	ruby test/test_geometry.rb
	ruby test/test_lib.rb
	ruby -Iext/ratcliff ext/ratcliff/testratcliff.rb
