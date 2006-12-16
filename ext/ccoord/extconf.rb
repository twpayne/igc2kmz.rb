require "mkmf"

$CFLAGS += " -Wall -Wextra -Wmissing-prototypes -ffast-math"
create_makefile("ccoord")
