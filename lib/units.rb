module Units

  class Unit

    attr_reader :unit
    attr_reader :multiplier

    def initialize(unit, format, multiplier)
      @unit = unit
      @format = format
      @multiplier = multiplier
    end

    def [](value)
      convert(value) + @unit
    end

    def convert(value)
      @format % (@multiplier * value)
    end

  end

  GROUPS = {
    :metric => {
      :altitude => Unit.new("m", "%d", 1),
      :climb    => Unit.new("m/s", "%+.1f", 1),
      :distance => Unit.new("km", "%.1f", 1.0 / 1000.0),
      :speed    => Unit.new("km/h", "%.1f",  3.6),
    },
    :imperial => {
      :altitude => Unit.new("ft", "%d", 1.0 / 0.3048),
      :climb    => Unit.new("fpm", "%d", 1.0 / 0.00508),
      :distance => Unit.new("m", "%.1f", 1.0 / 1609.344),
      :speed    => Unit.new("mph", "%.1f", 1.0 / 0.44704),
    },
    :nautical => {
      :altitude => Unit.new("ft", "%d", 1.0 / 0.3048),
      :climb    => Unit.new("kn", "%.1f", 1.9438445),
      :distance => Unit.new("nm", "%.1f", 1.0 / 1852.0),
      :speed    => Unit.new("kn", "%.1f", 1.9438445),
    },
  }

end

class Numeric

  def to_duration
    rem, secs = self.divmod(60)
    hours, mins = rem.divmod(60)
    "%d:%02d:%02d" % [hours, mins, secs]
  end

  def to_glide
    "%.1f:1" % self
  end

end

class Time

  def to_time(hints, format = "%H:%M:%S")
    (self + hints.tz_offset).strftime(format)
  end

end
