#include <ruby.h>

static int
ratcliff_obershelp(const char *begin1, const char *end1, const char *begin2, const char *end2)
{
	if (begin1 == end1 || begin2 == end2)
		return 0;
	if (end1 - begin1 == 1 && end2 - begin2 == 1)
		return 0;
	int length = 0;
	const char *i1, *i2;
	const char *start1, *start2;
	const char *limit1 = end1;
	const char *limit2 = end2;
	for (i1 = begin1; i1 < limit1; ++i1) {
		for (i2 = begin2; i2 < limit2; ++i2) {
			if (*i1 == *i2) {
				int j = 1;
				while (i1 + j < end1 && i2 + j < end2 && i1[j] == i2[j])
					++j;
				if (j > length) {
					length = j;
					start1 = i1;
					start2 = i2;
					limit1 = end1 - length;
					limit2 = end2 - length;
				}
			}
        }
    }
	return length ? ratcliff_obershelp(begin1, start1, begin2, start2) + length + ratcliff_obershelp(start1 + length, end1, start2 + length, end2) : 0;
}

static VALUE
String_ratcliff(VALUE self, VALUE s)
{
	Check_Type(s, T_STRING);
	if (RSTRING(self)->len == 1 && RSTRING(s)->len == 1)
		return INT2FIX(RSTRING(self)->ptr[0] == RSTRING(s)->ptr[0] ? 1 : 0);
	else
		return rb_float_new(2.0 * ratcliff_obershelp(RSTRING(self)->ptr, RSTRING(self)->ptr + RSTRING(self)->len, RSTRING(s)->ptr, RSTRING(s)->ptr + RSTRING(s)->len) / (RSTRING(self)->len + RSTRING(s)->len));
}

void Init_ratcliff(void)
{
    rb_define_method(rb_cString, "ratcliff", String_ratcliff, 1);
}
