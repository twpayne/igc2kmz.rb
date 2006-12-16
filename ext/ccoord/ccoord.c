/* http://www.movable-type.co.uk/scripts/LatLong.html */

#include <ruby.h>
#include <math.h>

#define DEFAULT_R 6371000.0

static VALUE rb_cCoord;
static VALUE id_alt;
static VALUE id_lat;
static VALUE id_lon;
static VALUE id_new;

void Init_ccoord(void);

static inline VALUE
rb_coord_new(double lat, double lon, double alt)
{
    return rb_funcall(rb_cCoord, id_new, 3, rb_float_new(lat), rb_float_new(lon), rb_float_new(alt));
}

static VALUE
rb_coord_distance_to(int argc, VALUE *argv, VALUE obj)
{
    if (argc < 1 || 2 < argc)
        rb_raise(rb_eArgError, "wrong number of arguments");
    VALUE oth = argv[0];
    double lat1 = NUM2DBL(rb_funcall(obj, id_lat, 0));
    double lon1 = NUM2DBL(rb_funcall(obj, id_lon, 0));
    double lat2 = NUM2DBL(rb_funcall(oth, id_lat, 0));
    double lon2 = NUM2DBL(rb_funcall(oth, id_lon, 0));
    double R = argc < 2 ? DEFAULT_R : NUM2DBL(argv[2]);
    double x = sin(lat1) * sin(lat2) + cos(lat1) * cos(lat2) * cos(lon2 - lon1);
    return rb_float_new(x < 1.0 ? R * acos(x) : 0.0);
}

static VALUE
rb_coord_halfway_to(VALUE obj, VALUE oth)
{
    double lat1 = NUM2DBL(rb_funcall(obj, id_lat, 0));
    double lon1 = NUM2DBL(rb_funcall(obj, id_lon, 0));
    double alt1 = NUM2DBL(rb_funcall(obj, id_alt, 0));
    double lat2 = NUM2DBL(rb_funcall(oth, id_lat, 0));
    double lon2 = NUM2DBL(rb_funcall(oth, id_lon, 0));
    double alt2 = NUM2DBL(rb_funcall(oth, id_alt, 0));
    double delta_lon = lon2 - lon1;
    double Bx = cos(lat2) * cos(delta_lon);
    double By = cos(lat2) * sin(delta_lon);
    double cos_lat1_plus_Bx = cos(lat1) + Bx;
	double lat = atan2(sin(lat1) + sin(lat2), sqrt(cos_lat1_plus_Bx * cos_lat1_plus_Bx + By * By));
	double lon = lon1 + atan2(By, cos_lat1_plus_Bx);
	double alt = (alt1 + alt2) / 2.0;
    return rb_coord_new(lat, lon, alt);
}

static VALUE
rb_coord_initial_bearing_to(VALUE obj, VALUE oth)
{
    double lat1 = NUM2DBL(rb_funcall(obj, id_lat, 0));
    double lon1 = NUM2DBL(rb_funcall(obj, id_lon, 0));
    double lat2 = NUM2DBL(rb_funcall(oth, id_lat, 0));
    double lon2 = NUM2DBL(rb_funcall(oth, id_lon, 0));
    double lon = lon2 - lon1;
    return rb_float_new(atan2(sin(lon) * cos(lat2), cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(lon)));
}

static VALUE
rb_coord_destination_at(int argc, VALUE *argv, VALUE obj)
{
    if (argc < 2 || 3 < argc)
        rb_raise(rb_eArgError, "wrong number of arguments");
    double lat1 = NUM2DBL(rb_funcall(obj, id_lat, 0));
    double lon1 = NUM2DBL(rb_funcall(obj, id_lon, 0));
    double alt1 = NUM2DBL(rb_funcall(obj, id_alt, 0));
    double brng = NUM2DBL(argv[0]);
    double d_div_R = NUM2DBL(argv[1]) / (argc < 3 ? DEFAULT_R : NUM2DBL(argv[2]));
    double cos_lat1 = cos(lat1);
    double sin_lat1 = sin(lat1);
    double cos_d_div_R = cos(d_div_R);
    double sin_d_div_R = sin(d_div_R);
    double lat2 = asin(sin_lat1 * cos_d_div_R + cos_lat1 * sin_d_div_R * cos(brng));
    double lon2 = lon1 + atan2(sin(brng) * sin_d_div_R * cos_lat1, cos_d_div_R - sin_lat1 * sin(lat2));
    return rb_coord_new(lat2, lon2, alt1);
}

void
Init_ccoord(void)
{
    rb_cCoord = rb_define_class("Coord", rb_cObject);
    id_alt = rb_intern("alt");
    id_lat = rb_intern("lat");
    id_lon = rb_intern("lon");
    id_new = rb_intern("new");
    rb_define_method(rb_cCoord, "distance_to", rb_coord_distance_to, -1);
    rb_define_method(rb_cCoord, "halfway_to", rb_coord_halfway_to, 1);
    rb_define_method(rb_cCoord, "initial_bearing_to", rb_coord_initial_bearing_to, 1);
    rb_define_method(rb_cCoord, "destination_at", rb_coord_destination_at, -1);
}
