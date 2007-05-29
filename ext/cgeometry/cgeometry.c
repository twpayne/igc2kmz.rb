#include <ruby.h>
#include <math.h>

#define DEFAULT_R 6371000.0

static VALUE rb_cCoord;
static VALUE rb_cPoint;
static VALUE id_alt;
static VALUE id_lat;
static VALUE id_lon;
static VALUE id_new;
static VALUE id_x;
static VALUE id_y;
static VALUE id_z;

void Init_cgeometry(void);

static inline VALUE
rb_coord_new(double lat, double lon, double alt)
{
    return rb_funcall(rb_cCoord, id_new, 3, rb_float_new(lat), rb_float_new(lon), rb_float_new(alt));
}

static inline VALUE
rb_point_new(double x, double y, double z)
{
    return rb_funcall(rb_cPoint, id_new, 3, rb_float_new(x), rb_float_new(y), rb_float_new(z));
}

static VALUE
rb_coord_to_point(int argc, VALUE *argv, VALUE obj)
{
    if (1 < argc)
        rb_raise(rb_eArgError, "wrong number of arguments");
    double lat = NUM2DBL(rb_funcall(obj, id_lat, 0));
    double lon = NUM2DBL(rb_funcall(obj, id_lon, 0));
    double alt = NUM2DBL(rb_funcall(obj, id_alt, 0));
    double R = argc < 1 ? DEFAULT_R : NUM2DBL(argv[0]);
    double r = R + alt;
    double cos_lon = cos(lon);
    double x = r * cos_lon * cos(lat);
    double y = r * cos_lon * sin(lat);
    double z = r * sin(lon);
    return rb_point_new(x, y, z);
}

static VALUE
rb_point_to_coord(int argc, VALUE *argv, VALUE obj)
{
    if (1 < argc)
        rb_raise(rb_eArgError, "wrong number of arguments");
    double x = NUM2DBL(rb_funcall(obj, id_x, 0));
    double y = NUM2DBL(rb_funcall(obj, id_y, 0));
    double z = NUM2DBL(rb_funcall(obj, id_z, 0));
    double R = argc < 1 ? DEFAULT_R : NUM2DBL(argv[0]);
    double lat = atan2(y, x);
    double lon = atan2(z, sqrt(x * x + y * y));
    double r = sqrt(x * x + y * y + z * z);
    double alt = r - R;
    return rb_coord_new(lat, lon, alt);
}

void
Init_cgeometry(void)
{
    rb_cCoord = rb_define_class("Coord", rb_cObject);
    rb_cPoint = rb_define_class("Point", rb_cObject);
    id_alt = rb_intern("alt");
    id_lat = rb_intern("lat");
    id_lon = rb_intern("lon");
    id_new = rb_intern("new");
    id_x = rb_intern("x");
    id_y = rb_intern("y");
    id_z = rb_intern("z");
    rb_define_method(rb_cCoord, "to_point", rb_coord_to_point, -1);
    rb_define_method(rb_cPoint, "to_coord", rb_point_to_coord, -1);
}
