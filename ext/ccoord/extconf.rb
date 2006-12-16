require 'mkmf'

$CFLAGS += ' -ffast-math'
create_makefile('ccoord')
