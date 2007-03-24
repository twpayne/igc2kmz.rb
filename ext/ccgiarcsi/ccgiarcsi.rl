/* vim: set filetype=ragel shiftwidth=4 softtabstop=4 tabstop=8: */

/* FIXME remove asserts */

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include <ruby.h>

static VALUE id_read;
static VALUE id_write;

void Init_ccgiarcsi(void);

%%{

machine cgiarcsi;

whitespace = [\t ];
newline = "\r\n";

# unsigned
action unsignedFirst { _unsigned = fc - '0'; }
action unsignedNext { _unsigned = 10 * _unsigned + fc - '0'; }
unsigned = digit @unsignedFirst digit* $unsignedNext;

# int
action posIntFirst { _int = fc - '0'; }
action posIntNext { _int = 10 * _int + fc - '0'; }
posInt = digit @posIntFirst digit* $posIntNext;
action negIntFirst { _int = -(fc - '0'); }
action negIntNext { _int = 10 * _int - (fc - '0'); }
negInt = '-' digit @negIntFirst digit* $negIntNext;
int = posInt | negInt;

# double
action posDoubleIntFirst { _double = fc - '0'; }
action posDoubleIntNext { _double = 10 * _double + (fc - '0'); }
posDoubleInt = digit @posDoubleIntFirst digit* $posDoubleIntNext;
action posDoubleFracFirst { _double += (fc - '0') / 10.0; _denom = 100; }
action posDoubleFracNext { _double += (fc - '0') / _denom; _denom *= 10; }
posDoubleFrac = '.' digit @posDoubleFracFirst digit* $posDoubleFracNext;
posDouble = posDoubleInt posDoubleFrac?;
action negDoubleIntFirst { _double = -(fc - '0'); }
action negDoubleIntNext { _double = 10 * _double - (fc - '0'); }
negDoubleInt = '-' digit @negDoubleIntFirst digit* $negDoubleIntNext;
action negDoubleFracFirst { _double -= (fc - '0') / 10.0; _denom = 100; }
action negDoubleFracNext { _double -= (fc - '0') / _denom; _denom *= 10; }
negDoubleFrac = '.' digit @negDoubleFracFirst digit* $negDoubleFracNext;
negDouble = negDoubleInt negDoubleFrac?;
double = posDouble | negDouble;

action ncols {
    ncols = _unsigned;
    assert(ncols > 0);
}
ncols = "ncols" whitespace+ unsigned %ncols newline;

action nrows {
    nrows = _unsigned;
    assert(nrows > 0);
}
nrows = "nrows" whitespace+ unsigned %nrows newline;

action xllcorner {
    xllcorner = _double;
    assert(-180.0 <= xllcorner && xllcorner < 180.0);
}
xllcorner = "xllcorner" whitespace+ double %xllcorner newline;

action yllcorner {
    yllcorner = _double;
    assert(-180.0 <= yllcorner && yllcorner < 180.0);
}
yllcorner = "yllcorner" whitespace+ double %yllcorner newline;

action cellsize {
    cellsize = _double;
    assert(cellsize > 0.0);
}
cellsize = "cellsize" whitespace+ double %cellsize newline;

action NODATA_value {
    NODATA_value = _int;
}
NODATA_value = "NODATA_value" whitespace+ int %NODATA_value newline;

header = ncols nrows xllcorner yllcorner cellsize NODATA_value;

action rowStart {
    assert(row < nrows);
    ++row;
    datump = (short *) RSTRING(rb_row)->ptr;
}

action datum {
    assert(datump < rowe);
    *datump++ = _int;
}

action rowEnd {
    assert(datump == rowe);
    rb_funcall(rb_dst, id_write, 1, rb_row);
}

row = int >rowStart %datum ( whitespace+ int %datum )* whitespace* newline %rowEnd;

action dataStart {
    rb_row = rb_str_new(NULL, ncols * sizeof(short));
    rowe = (short *) RSTRING(rb_row)->ptr + ncols;
}

action dataEnd {
    assert(row == nrows);
}

data = row+ >dataStart %dataEnd;

main := header data 0;

}%%

static VALUE
rb_CGIARCSI_parse_ASC(VALUE rb_self, VALUE rb_src, VALUE rb_dst)
{
    unsigned ncols = 0;
    unsigned nrows = 0;
    double xllcorner = 0;
    double yllcorner = 0;
    double cellsize = 0;
    short NODATA_value = 0;
    short *datump = NULL;
    short *rowe = NULL;
    unsigned row = 0;
    VALUE rb_row = Qnil;
    int cs = 0;
    int _int = 0;
    unsigned _unsigned = 0;
    double _double = 0;
    double _denom = 0;

    %% write data;
    %% write init;
    while (cs != cgiarcsi_error) {
	VALUE rb_buffer = rb_funcall(rb_src, id_read, 1, INT2NUM(65536));
	const char *p;
	const char *pe;
	if (rb_buffer == Qnil) {
	    p = "";
	    pe = p + 1;
	} else {
	    p = RSTRING(rb_buffer)->ptr;
	    pe = p + RSTRING(rb_buffer)->len;
	}
	%% write exec;
	if (rb_buffer == Qnil) {
	    %% write eof;
	    break;
	}
    }

    if (cs == cgiarcsi_error) {
	assert(cs != cgiarcsi_error);
    } else if (cs < cgiarcsi_first_final) {
	assert(cs >= cgiarcsi_first_final);
    }

    return Qnil;
}

void
Init_ccgiarcsi(void)
{
    id_read = rb_intern("read");
    id_write = rb_intern("write");
    VALUE rb_CGIARCSI = rb_define_module("CGIARCSI");
    rb_define_module_function(rb_CGIARCSI, "parse_ASC", rb_CGIARCSI_parse_ASC, 2);

}
