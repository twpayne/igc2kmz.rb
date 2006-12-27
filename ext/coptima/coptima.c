#include <ruby.h>
#include <math.h>
#include <stdio.h>
#include <time.h>

#define p(rb_value) rb_funcall(rb_mKernel, rb_intern("p"), 1, (rb_value))

#define R 6371.0

static VALUE rb_cOptima;
static VALUE rb_cOptimum;
static VALUE sym_frcfd;
static VALUE sym_ukxcl;
static VALUE id_fixes;
static VALUE id_lat;
static VALUE id_lon;
static VALUE id_new;
static VALUE id_time;
static VALUE id_to_i;

typedef struct {
	double cos_lat;
	double sin_lat;
	double lon;
} fix_t;

typedef struct {
	int index;
	double distance;
} limit_t;

typedef struct {
	int n;
	fix_t *fixes;
    time_t *times;
	double *sigma_delta;
	limit_t *before;
	limit_t *after;
	int *last_finish;
	int *best_start;
	double max_delta;
} track_t;

typedef struct {
	double min;
	double max;
} bound_t;

static inline double track_delta(const track_t *track, int i, int j) __attribute__ ((nonnull(1))) __attribute__ ((pure));
static inline int track_forward(const track_t *track, int i, double d) __attribute__ ((nonnull(1))) __attribute__ ((pure));
static inline int track_fast_forward(const track_t *track, int i, double d) __attribute__ ((nonnull(1))) __attribute__ ((pure));
static inline int track_backward(const track_t *track, int i, double d) __attribute__ ((nonnull(1))) __attribute__ ((pure));
static inline int track_fast_backward(const track_t *track, int i, double d) __attribute__ ((nonnull(1))) __attribute__ ((pure));
static inline int track_first_at_least(const track_t *track, int i, int begin, int end, double bound) __attribute__ ((nonnull(1))) __attribute__ ((pure));
static inline int track_last_at_least(const track_t *track, int i, int begin, int end, double bound) __attribute__ ((nonnull(1))) __attribute__ ((pure));
static track_t *track_new(VALUE rb_fixes) __attribute__ ((malloc));
void Init_coptima(void);

static inline VALUE
rb_ary_push_unless_nil(VALUE rb_self, VALUE rb_value)
{
	if (rb_value != Qnil)
		rb_ary_push(rb_self, rb_value);
	return rb_self;
}

static inline double
track_delta(const track_t *track, int i, int j)
{
	const fix_t *fix_i = track->fixes + i;
	const fix_t *fix_j = track->fixes + j;
	double x = fix_i->sin_lat * fix_j->sin_lat + fix_i->cos_lat * fix_j->cos_lat * cos(fix_i->lon - fix_j->lon);
	return x < 1.0 ? acos(x) : 0.0;
}

static inline int
track_forward(const track_t *track, int i, double d)
{
	int step = (int) (d / track->max_delta);
	return step > 0 ? i + step : ++i;
}

static inline int
track_fast_forward(const track_t *track, int i, double d)
{
	double target = track->sigma_delta[i] + d;
	i = track_forward(track, i, d);
	if (i >= track->n)
		return i;
	while (1) {
		double error = target - track->sigma_delta[i];
		if (error <= 0.0)
			return i;
		i = track_forward(track, i, error);
		if (i >= track->n)
			return i;
	}
}

static inline int
track_backward(const track_t *track, int i, double d)
{
	int step = (int) (d / track->max_delta);
	return step > 0 ? i - step : --i;
}

static inline int
track_fast_backward(const track_t *track, int i, double d)
{
	double target = track->sigma_delta[i] - d;
	i = track_backward(track, i, d);
	if (i < 0)
		return i;
	while (1) {
		double error = track->sigma_delta[i] - target;
		if (error <= 0.0)
			return i;
		i = track_backward(track, i, error);
		if (i < 0)
			return i;
	}
}

static inline int
track_furthest_from(const track_t *track, int i, int begin, int end, double bound, double *out)
{
	int result = -1, j;
	for (j = begin; j < end; ) {
		double d = track_delta(track, i, j);
		if (d > bound) {
			bound = *out = d;
			result = j;
			++j;
		} else {
			j = track_fast_forward(track, j, bound - d);
		}
	}
	return result;
}

static inline int
track_nearest_to(const track_t *track, int i, int begin, int end, double bound, double *out)
{
	int result = -1, j;
	for (j = begin; j < end; ) {
		double d = track_delta(track, i, j);
		if (d < bound) {
			result = j;
			bound = *out = d;
			++j;
		} else {
			j = track_fast_forward(track, j, d - bound);
		}
	}
	return result;
}

static inline int
track_furthest_from2(const track_t *track, int i, int j, int begin, int end, double bound, double *out)
{
	int result = -1, k;
	for (k = begin; k < end; ) {
		double d = track_delta(track, i, k) + track_delta(track, k, j);
		if (d > bound) {
			result = k;
			bound = *out = d;
			++k;
		} else {
			k = track_fast_forward(track, k, (bound - d) / 2.0);
		}
	}
	return result;
}

static inline int
track_first_at_least(const track_t *track, int i, int begin, int end, double bound)
{
	int j;
	for (j = begin; j < end; ) {
		double d = track_delta(track, i, j);
		if (d > bound)
			return j;
		j = track_fast_forward(track, j, bound - d);
	}
	return -1;
}

static inline int
track_last_at_least(const track_t *track, int i, int begin, int end, double bound)
{
	int j;
	for (j = end - 1; j >= begin; ) {
		double d = track_delta(track, i, j);
		if (d > bound)
			return j;
		j = track_fast_backward(track, j, bound - d);
	}
	return -1;
}

static inline int
track_furthest_from2_constrained(const track_t *track, int i, int j, int begin, int end, double shortestlegbound, double longestlegbound, double *out1, double *out2)
{
	double bound = 0.0;
	int result = -1, k;
	for (k = begin; k < end; ) {
		double leg1 = track_delta(track, i, k);
		if (leg1 < shortestlegbound) {
			k = track_fast_forward(track, k, shortestlegbound - leg1);
			continue;
		} else if (leg1 > longestlegbound) {
			k = track_fast_forward(track, k, leg1 - longestlegbound);
			continue;
		}
		double leg2 = track_delta(track, k, j);
		if (leg2 < shortestlegbound) {
			k = track_fast_forward(track, k, shortestlegbound - leg2);
			continue;
		} else if (leg2 > longestlegbound) {
			k = track_fast_forward(track, k, leg2 - longestlegbound);
			continue;
		}
		double d = leg1 + leg2;
		if (d > bound) {
			result = k;
			bound = d;
			*out1 = leg1;
			*out2 = leg2;
			++k;
		} else {
			k = track_fast_forward(track, k, 0.5 * (bound - d));
		}
	}
	return result;
}

static track_t *
track_new_common(track_t *track)
{
	/* Compute before lookup table */
	track->before = ALLOC_N(limit_t, track->n);
	track->before[0].index = 0;
	track->before[0].distance = 0.0;
	int i;
	for (i = 1; i < track->n; ++i)
		track->before[i].index = track_furthest_from(track, i, 0, i, track->before[i - 1].distance - track->max_delta, &track->before[i].distance);

	/* Compute after lookup table */
	track->after = ALLOC_N(limit_t, track->n);
	for (i = 0; i < track->n - 1; ++i)
		track->after[i].index = track_furthest_from(track, i, i + 1, track->n, track->after[i - 1].distance - track->max_delta, &track->after[i].distance);
	track->after[track->n - 1].index = track->n - 1;
	track->after[track->n - 1].distance = 0.0;

	return track;
}

static track_t *
track_new(VALUE rb_fixes)
{
	Check_Type(rb_fixes, T_ARRAY);

	track_t *track = ALLOC(track_t);
	memset(track, 0, sizeof(track_t));
	track->n = RARRAY(rb_fixes)->len;

	/* Compute cos_lat, sin_lat and lon lookup tables */
	track->fixes = ALLOC_N(fix_t, track->n);
	track->times = ALLOC_N(time_t, track->n);
	int i;
	for (i = 0; i < track->n; ++i) {
		VALUE rb_fix = RARRAY(rb_fixes)->ptr[i];
		double lat = NUM2DBL(rb_funcall(rb_fix, id_lat, 0));
		track->fixes[i].cos_lat = cos(lat);
		track->fixes[i].sin_lat = sin(lat);
		track->fixes[i].lon = NUM2DBL(rb_funcall(rb_fix, id_lon, 0));
        track->times[i] = NUM2INT(rb_funcall(rb_funcall(rb_fix, id_time, 0), id_to_i, 0));
	}

	/* Compute max_delta and sigma_delta lookup table */
	track->max_delta = 0.0;
	track->sigma_delta = ALLOC_N(double, track->n);
	track->sigma_delta[0] = 0.0;
	for (i = 1; i < track->n; ++i) {
		double delta = track_delta(track, i - 1, i);
		track->sigma_delta[i] = track->sigma_delta[i - 1] + delta;
		if (delta > track->max_delta)
			track->max_delta = delta;
	}

	return track_new_common(track);
}

static track_t *
track_downsample(track_t *track, double threshold)
{
	track_t *result = ALLOC(track_t);
	memset(result, 0, sizeof(track_t));

	result->fixes = ALLOC_N(fix_t, track->n);
	result->times = ALLOC_N(time_t, track->n);
	result->max_delta = 0.0;
	result->sigma_delta = ALLOC_N(double, track->n);
	result->fixes[0] = track->fixes[0];
	result->sigma_delta[0] = 0.0;
	result->n = 1;
	int i = 0, j;
	for (j = 1; j < track->n; ++j) {
		double delta = track_delta(track, i, j);
		if (delta > threshold) {
			result->fixes[result->n] = track->fixes[j];
            result->times[result->n] = track->times[j];
			result->sigma_delta[result->n] = result->sigma_delta[result->n - 1] + delta;
			if (delta > result->max_delta)
				result->max_delta = delta;
			++result->n;
			i = j;
		}
	}

	fprintf(stderr, "original: %d points\n", track->n);
	fprintf(stderr, "downsampled: %d points\n", result->n);

	return track_new_common(result);
}

static void
track_compute_circuit_tables(track_t *track, double bound)
{
	track->last_finish = ALLOC_N(int, track->n);
	track->best_start = ALLOC_N(int, track->n);
	int current_best_start = 0, i, j;
	for (i = 0; i < track->n; ++i) {
		for (j = track->n - 1; j >= i; ) {
			double error = track_delta(track, i, j);
			if (error < bound) {
				track->last_finish[i] = j;
				break;
			} else {
				j = track_fast_backward(track, j, error - bound);
			}
		}
		if (track->last_finish[i] > track->last_finish[current_best_start])
			current_best_start = i;
		if (track->last_finish[current_best_start] < i) {
			current_best_start = 0;
			for (j = 1; j <= i; ++j)
				if (track->last_finish[j] > track->last_finish[current_best_start])
					current_best_start = j;
		}
		track->best_start[i] = current_best_start;
	}
}

static void
track_delete(track_t *track)
{
	if (track) {
		xfree(track->fixes);
		xfree(track->times);
		xfree(track->sigma_delta);
		xfree(track->before);
		xfree(track->after);
		xfree(track->last_finish);
		xfree(track->best_start);
		xfree(track);
	}
}

static int
track_time_to_index(const track_t *track, time_t time, int left, int right)
{
    while (left <= right) {
        int middle = (left + right) / 2;
        if (track->times[middle] > time)
            right = middle - 1;
        else if (track->times[middle] == time)
            return middle;
        else
            left = middle + 1;
    }
    return -1;
}

static void
track_times_to_indexes(const track_t *track, int n, const time_t *times, int *indexes)
{
    int left = 0;
    int right = track->n;
    int i;
    for (i = 0; i < n; ++i) {
        indexes[i] = track_time_to_index(track, times[i], left, right);
        left = indexes[i];
    }
}

static void
track_indexes_to_times(const track_t *track, int n, const int *indexes, time_t *times)
{
    int i;
    for (i = 0; i < n; ++i)
        times[i] = indexes[i] == -1 ? -1 : track->times[indexes[i]];
}

static VALUE
track_rb_optimum_new(const track_t *track, VALUE rb_fixes, int n, time_t *times, const char *names[], const char *flight_type, double multiplier, int circuit)
{
	if (times[0] == -1)
		return Qnil;
    int indexes[n];
    track_times_to_indexes(track, n, times, indexes);
	VALUE rb_fixes2 = rb_ary_new2(n);
	VALUE rb_names = rb_ary_new2(n);
	int i;
	for (i = 0; i < n; ++i) {
		rb_ary_push(rb_fixes2, RARRAY(rb_fixes)->ptr[indexes[i]]);
		rb_ary_push(rb_names, rb_str_new2(names[i]));
	}
	return rb_funcall(rb_cOptimum, id_new, 5, rb_fixes2, rb_names, rb_str_new2(flight_type), rb_float_new(multiplier), circuit ? Qtrue : Qfalse);
}

static double
track_open_distance(const track_t *track, double bound, time_t *times)
{
    int indexes[2] = { -1, -1 };
	int start;
	for (start = 0; start < track->n - 1; ++start) {
		int finish = track_furthest_from(track, start, start + 1, track->n, bound, &bound);
		if (finish != -1) {
			indexes[0] = start;
			indexes[1] = finish;
		}
	}
    track_indexes_to_times(track, 2, indexes, times);
	return bound;
}

static double
track_open_distance_one_point(const track_t *track, double bound, time_t *times)
{
    int indexes[3] = { -1, -1, -1 };
	int b1;
	for (b1 = 1; b1 < track->n - 1; ) {
		double total = track->before[b1].distance + track->after[b1].distance;
		if (total > bound) {
			indexes[0] = track->before[b1].index;
			indexes[1] = b1;
			indexes[2] = track->after[b1].index;
			bound = total;
			++b1;
		} else {
			b1 = track_fast_forward(track, b1, 2.0 * (bound - total));
		}
	}
    track_indexes_to_times(track, 3, indexes, times);
	return bound;
}

static double
track_open_distance_two_points(const track_t *track, double bound, time_t *times)
{
    int indexes[4] = { -1, -1, -1, -1 };
	int b1, b2;
	for (b1 = 1; b1 < track->n - 2; ++b1) {
		double leg1 = track->before[b1].distance;
		double bound23 = bound - leg1;
		for (b2 = b1 + 1; b2 < track->n - 1; ) {
			double leg23 = track_delta(track, b1, b2) + track->after[b2].distance;
			if (leg23 > bound23) {
				indexes[0] = track->before[b1].index;
				indexes[1] = b1;
				indexes[2] = b2;
				indexes[3] = track->after[b2].index;
				bound23 = leg23;
				++b2;
			} else {
				b2 = track_fast_forward(track, b2, 0.5 * (bound23 - leg23));
			}
		}
		bound = leg1 + bound23;
	}
    track_indexes_to_times(track, 4, indexes, times);
	return bound;
}

static double
track_open_distance_three_points(const track_t *track, double bound, time_t *times)
{
    int indexes[5] = { -1, -1, -1, -1, -1 };
	int b1, b2, b3;
	for (b1 = 1; b1 < track->n - 3; ++b1) {
		double leg1 = track->before[b1].distance;
		double bound234 = bound - leg1;
		for (b2 = b1 + 1; b2 < track->n - 2; ++b2) {
			double leg2 = track_delta(track, b1, b2);
			double bound34 = bound234 - leg2;
			for (b3 = b2 + 1; b3 < track->n - 1; ) {
				double legs34 = track_delta(track, b2, b3) + track->after[b3].distance;
				if (legs34 > bound34) {
					indexes[0] = track->before[b1].index;
					indexes[1] = b1;
					indexes[2] = b2;
					indexes[3] = b3;
					indexes[4] = track->after[b3].index;
					bound34 = legs34;
					++b3;
				} else {
					b3 = track_fast_forward(track, b3, 2.0 * (bound34 - legs34));
				}
			}
			bound234 = leg2 + bound34;
		}
		bound = leg1 + bound234;
	}
    track_indexes_to_times(track, 5, indexes, times);
	return bound;
}

/* FIXME */
static void
track_circuit_close(const track_t *track, int start, int b1, int b2, int finish, double boundda, int *outstart, int *outfinish)
{
	if (start == -1)
		return;
	int a, d;
	double bound = track_delta(track, b1, start) + track_delta(track, start, finish) + track_delta(track, finish, b2);
	for (d = start; d <= b1; ++d) {
		double leg1d = track_delta(track, b1, d);
		for (a = b2; a <= finish; ++a) {
			double legda = track_delta(track, d, a);
			if (legda < boundda) {
				double total = leg1d + legda + track_delta(track, a, b2);
				if (total < bound) {
					*outstart = d;
					*outfinish = a;
					bound = total;
				}
			}
		}
	}
}

static double
track_out_and_return(const track_t *track, double bound, time_t *times)
{
    int indexes[4] = { -1, -1, -1, -1 };
	int b1;
	for (b1 = 0; b1 < track->n - 2; ++b1) {
		int start = track->best_start[b1];
		int finish = track->last_finish[start];
		if (finish < 0)
			continue;
		double leg = 0.0;
		int b2 = track_furthest_from(track, b1, b1 + 1, finish + 1, bound, &leg);
		if (b2 >= 0) {
			indexes[0] = start;
			indexes[1] = b1;
			indexes[2] = b2;
			indexes[3] = finish;
			bound = leg;
		}
	}
	track_circuit_close(track, indexes[0], indexes[1], indexes[2], indexes[3], 3.0 / R, &indexes[0], &indexes[3]);
    track_indexes_to_times(track, 4, indexes, times);
	return bound;
}

static double
track_triangle(const track_t *track, double bound, time_t *times)
{
    int indexes[5] = { -1, -1, -1, -1, -1 };
	int b1, b3;
	for (b1 = 0; b1 < track->n - 1; ++b1) {
		int start = track->best_start[b1];
		int finish = track->last_finish[start];
		if (finish < 0)
			continue;
		for (b3 = finish; b3 > b1 + 1; --b3) {
			double leg31 = track_delta(track, b3, b1);
			double bound123 = bound - leg31;
			double legs123 = 0.0;
			int b2 = track_furthest_from2(track, b1, b3, b1 + 1, b3, bound123, &legs123);
			if (b2 > 0) {
				bound = leg31 + legs123;
				indexes[0] = start;
				indexes[1] = b1;
				indexes[2] = b2;
				indexes[3] = b3;
				indexes[4] = finish;
			}
		}
	}
	if (indexes[0] != -1) {
		fprintf(stderr, "triangle: %.2fkm\n", R * bound);
	}
	track_circuit_close(track, indexes[0], indexes[1], indexes[3], indexes[4], 3.0 / R, indexes + 0, indexes + 4);
    track_indexes_to_times(track, 5, indexes, times);
	return bound;
}

static double
track_triangle_fai(const track_t *track, double bound, time_t *times)
{
    int indexes[5] = { -1, -1, -1, -1, -1 };
	int b1, b2, b3;
	double legbound = 0.28 * bound;
	for (b1 = 0; b1 < track->n - 2; ++b1) {
		int start = track->best_start[b1];
		int finish = track->last_finish[start];
		if (finish < 0)
			continue;
		b2 = track_fast_forward(track, b1, legbound);
		for (; b2 < finish; ++b2) {
			double leg12 = track_delta(track, b1, b2);
			bound_t leg23bound;
			leg23bound.min = 0.28 * leg12 / 0.42;
			if (leg23bound.min < legbound)
				leg23bound.min = legbound;
			leg23bound.max = 0.42 * leg12 / 0.28;
			b3 = track_fast_forward(track, b2, leg23bound.min);
			while (b3 <= finish) {
				double leg23 = track_delta(track, b2, b3);
				if (leg23 < leg23bound.min) {
					b3 = track_fast_forward(track, b3, leg23bound.min - leg23);
					continue;
				} else if (leg23 > leg23bound.max) {
					b3 = track_fast_forward(track, b3, leg23 - leg23bound.max);
					continue;
				}
				bound_t leg31bound;
				leg31bound.min = 0.28 * (leg12 + leg23) / 0.72;
				leg31bound.max = 0.72 * (leg12 + leg23) / 0.28;
				if (leg23bound.min > leg31bound.min)
					leg31bound.min = leg23bound.min;
				if (leg23bound.max < leg31bound.max)
					leg31bound.max = leg23bound.max;
				if (leg31bound.max < leg31bound.min) {
					++b3; /* FIXME */
					continue;
				}
				double leg31 = track_delta(track, b3, b1);
				if (leg31 < leg31bound.min) {
					b3 = track_fast_forward(track, b3, leg31bound.min - leg31);
					continue;
				} else if (leg31 > leg31bound.max) {
					b3 = track_fast_forward(track, b3, leg31 - leg31bound.max);
					continue;
				}
				double d = leg12 + leg23 + leg31;
				if (d > bound) {
					bound = d;
					legbound = 0.28 * bound;
					indexes[0] = start;
					indexes[1] = b1;
					indexes[2] = b2;
					indexes[3] = b3;
					indexes[4] = finish;
				}
				++b3;
			}
		}
	}
	if (indexes[0] != -1) {
		fprintf(stderr, "fai triangle: %.2fkm\n", R * bound);
	}
	track_circuit_close(track, indexes[0], indexes[1], indexes[3], indexes[4], 3.0 / R, indexes + 0, indexes + 4);
    track_indexes_to_times(track, 5, indexes, times);
	return bound;
}

static double
track_quadrilateral(const track_t *track, double bound, time_t *times)
{
    int indexes[6] = { -1, -1, -1, -1, -1, -1 };
	/* FIXME */
    track_indexes_to_times(track, 6, indexes, times);
	return bound;
}

static VALUE
rb_Optima_new_from_fixes_open(VALUE rb_fixes, VALUE rb_complexity)
{
	VALUE rb_optima = rb_ary_new2(1);
	track_t *track = track_new(rb_fixes);
	int complexity = NUM2INT(rb_complexity);
	time_t times[2];
	if (2 <= complexity) {
		static const char *names[] = { "Start", "Finish" };
		track_open_distance(track, 0.0, times);
		rb_ary_push_unless_nil(rb_optima, track_rb_optimum_new(track, rb_fixes, 2, times, names, "Open distance", 1.0, 0));
	}
	track_delete(track);
	return rb_funcall(rb_cOptima, id_new, 3, rb_optima, Qnil, rb_complexity);
}

static VALUE
rb_Optima_new_from_fixes_frcfd(VALUE rb_fixes, VALUE rb_complexity)
{
	VALUE rb_optima = rb_ary_new2(7);
	track_t *track = track_new(rb_fixes);
	int complexity = NUM2INT(rb_complexity);
	time_t times[6];
	double bound = 0.0;
	if (2 <= complexity) {
		static const char *names[] = { "BD", "BA" };
		bound = track_open_distance(track, bound, times);
		rb_ary_push_unless_nil(rb_optima, track_rb_optimum_new(track, rb_fixes, 2, times, names, "Distance libre", bound < 15.0 / R ? 0.0 : 1.0, 0));
	}
	if (bound < 15.0 / R)
		bound = 15.0 / R;
	if (3 <= complexity) {
		static const char *names[] = { "BD", "B1", "BA" };
		bound = track_open_distance_one_point(track, bound, times);
		rb_ary_push_unless_nil(rb_optima, track_rb_optimum_new(track, rb_fixes, 3, times, names, "Distance libre avec un point de contournement", 1.0, 0));
	}
	if (4 <= complexity) {
		static const char *names[] = { "BD", "B1", "B2", "BA" };
		bound = track_open_distance_two_points(track, bound, times);
		rb_ary_push_unless_nil(rb_optima, track_rb_optimum_new(track, rb_fixes, 4, times, names, "Distance libre avec deux points de contournement", 1.0, 0));
		track_compute_circuit_tables(track, 3.0 / R);
		track_out_and_return(track, 15.0 / R, times);
		rb_ary_push_unless_nil(rb_optima, track_rb_optimum_new(track, rb_fixes, 4, times, names, "Parcours en aller-retour", 1.2, 1));
		if (5 <= complexity) {
			static const char *names[] = { "BD", "B1", "B2", "B3", "BA" };
			time_t times_fai[5];
			track_t *downsampled_track = track_downsample(track, 0.1 / R);
			track_compute_circuit_tables(downsampled_track, 3.0 / R);
			bound = 15.0 / R;
			bound = nextafter(track_triangle_fai(downsampled_track, bound, times_fai), 0.0);
			bound = track_triangle_fai(track, bound, times_fai);
			VALUE rb_triangle_fai = track_rb_optimum_new(track, rb_fixes, 5, times_fai, names, "Triangle FAI", 1.4, 1);
			bound = nextafter(track_triangle(downsampled_track, bound, times), 0.0);
			bound = track_triangle(track, bound, times);
			rb_ary_push_unless_nil(rb_optima, track_rb_optimum_new(track, rb_fixes, 5, times[0] == -1 ? times_fai : times, names, "Triangle plat", 1.2, 1));
			rb_ary_push_unless_nil(rb_optima, rb_triangle_fai);
			track_delete(downsampled_track);
			if (6 <= complexity) {
				static const char *names[] = { "BD", "B1", "B2", "B3", "B4", "BA" };
				track_quadrilateral(track, 15.0 / R, times);
				rb_ary_push_unless_nil(rb_optima, track_rb_optimum_new(track, rb_fixes, 6, times, names, "Quadrilat\xc3\xa8re", 1.2, 1));
			}
		}
	}
	track_delete(track);
	return rb_funcall(rb_cOptima, id_new, 3, rb_optima, sym_frcfd, rb_complexity);
}

static VALUE
rb_Optima_new_from_fixes_ukxcl(VALUE rb_fixes, VALUE rb_complexity)
{
	VALUE rb_optima = rb_ary_new2(4);
	track_t *track = track_new(rb_fixes);
	int complexity = NUM2INT(rb_complexity);
	time_t times[5];
	double bound = 0.0;
	if (2 <= complexity) {
		static const char *names[] = { "Start", "Finish" };
		bound = track_open_distance(track, bound, times);
		rb_ary_push_unless_nil(rb_optima, track_rb_optimum_new(track, rb_fixes, 2, times, names, "Open distance", bound < 15.0 / R ? 0.0 : 1.0, 0));
	}
	if (bound < 15.0 / R)
		bound = 15.0 / R;
	if (3 <= complexity) {
		static const char *names[] = { "Start", "TP1", "Finish" };
		bound = track_open_distance_one_point(track, bound, times);
		rb_ary_push_unless_nil(rb_optima, track_rb_optimum_new(track, rb_fixes, 3, times, names, "Open distance via a turnpoint", 1.0, 0));
	}
	if (4 <= complexity) {
		static const char *names[] = { "Start", "TP1", "TP2", "Finish" };
		bound = track_open_distance_two_points(track, bound, times);
		rb_ary_push_unless_nil(rb_optima, track_rb_optimum_new(track, rb_fixes, 4, times, names, "Open distance via two turnpoints", 1.0, 0));
	}
	if (5 <= complexity) {
		static const char *names[] = { "Start", "TP1", "TP2", "TP3", "Finish" };
		bound = track_open_distance_three_points(track, bound, times);
		rb_ary_push_unless_nil(rb_optima, track_rb_optimum_new(track, rb_fixes, 5, times, names, "Open distance via three turnpoints", 1.0, 0));
	}
	track_delete(track);
	return rb_funcall(rb_cOptima, id_new, 3, rb_optima, sym_ukxcl, rb_complexity);
}

static VALUE
rb_Optima_new_from_igc(VALUE rb_self, VALUE rb_igc, VALUE rb_league, VALUE rb_complexity)
{
	rb_self = rb_self;
	VALUE rb_fixes = rb_funcall(rb_igc, id_fixes, 0);
	if (rb_league == Qnil)
		return rb_Optima_new_from_fixes_open(rb_fixes, rb_complexity);
	else if (rb_league == sym_frcfd)
		return rb_Optima_new_from_fixes_frcfd(rb_fixes, rb_complexity);
	else if (rb_league == sym_ukxcl)
		return rb_Optima_new_from_fixes_ukxcl(rb_fixes, rb_complexity);
	else
		return Qnil;
}

void
Init_coptima(void)
{
	rb_cOptima = rb_const_get(rb_cObject, rb_intern("Optima"));
	rb_cOptimum = rb_const_get(rb_cObject, rb_intern("Optimum"));
	sym_frcfd = ID2SYM(rb_intern("frcfd"));
	sym_ukxcl = ID2SYM(rb_intern("ukxcl"));
    VALUE rb_LEAGUES = rb_hash_new();
    rb_hash_aset(rb_LEAGUES, Qnil, rb_str_new2("Open distance"));
    rb_hash_aset(rb_LEAGUES, sym_ukxcl, rb_str_new2("XC league (UK)"));
    rb_hash_aset(rb_LEAGUES, sym_frcfd, rb_str_new2("Coupe f\xc3\xa9""d\xc3\xa9rale de distance (France)"));
	rb_define_const(rb_cOptima, "LEAGUES", rb_LEAGUES);
	id_fixes = rb_intern("fixes");
	id_lat = rb_intern("lat");
	id_lon = rb_intern("lon");
	id_new = rb_intern("new");
	id_time = rb_intern("time");
	id_to_i = rb_intern("to_i");
	rb_define_module_function(rb_cOptima, "new_from_igc", rb_Optima_new_from_igc, 3);
}
