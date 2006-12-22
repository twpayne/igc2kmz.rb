class Numeric

  def to_altitude(hints)
    case hints.units
    when :metric   then "%dm" % self
    when :imperial then "%d'" % (self / 0.3048)
    when :nautical then "%d'" % (self / 0.3048)
    end
  end

  def to_climb(hints)
    case hints.units
    when :metric   then "%+.1fm/s" % self
    when :imperial then "%dfpm" % (self / 0.00508)
    when :nautical then "%.1fkn" % (1.9438445 * self)
    end
  end

  def to_distance(hints)
    case hints.units
    when :metric   then "%.1fkm" % (self / 1000.0)
    when :imperial then "%.1fmi" % (self / 1609.344)
    when :nautical then "%.1fnm" % (self / 1852.0)
    end
  end

  def to_duration
    rem, secs = self.divmod(60)
    hours, mins = rem.divmod(60)
    "%d:%02d:%02d" % [hours, mins, secs]
  end

  def to_glide(hints)
    "%.1f:1" % self
  end

  def to_speed(hints)
    case hints.units
    when :metric   then "%.1fkm/h" % (3.6 * self)
    when :imperial then "%.1fmph" % (self / 0.44704)
    when :nautical then "%.1fkn" % (1.9438445 * self)
    end
  end

end


class Time

  def to_time(hints, format = "%H:%M:%S")
    (self + hints.tz_offset).strftime(format)
  end

end
