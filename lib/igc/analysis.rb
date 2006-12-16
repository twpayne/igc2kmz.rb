require "enumerator"
require "igc"

class IGC

  class Bounds

    attr_accessor :lat, :lon, :alt, :time, :speed, :climb, :glide

    def merge(other)
      @lat = @lat ? [@lat.first, other.lat.first].min..[@lat.last, other.lat.last].max : other.lat
      @lon = @lon ? [@lon.first, other.lon.first].min..[@lon.last, other.lon.last].max : other.lon
      @alt = @alt ? [@alt.first, other.alt.first].min..[@alt.last, other.alt.last].max : other.alt
      @time = @time ? [@time.first, other.time.first].min..[@time.last, other.time.last].max : other.time
      @speed = @speed ? [@speed.first, other.speed.first].min..[@speed.last, other.speed.last].max : other.speed
      @climb = @climb ? [@climb.first, other.climb.first].min..[@climb.last, other.climb.last].max : other.climb
      @glide = @glide ? [@glide.first, other.glide.first].min..[@glide.last, other.glide.last].max : other.glide
    end

  end

  class Average

    attr_reader :speed, :climb, :glide

    def initialize(ds, dz, dt)
      @speed = ds / dt
      @climb = dz / dt
      @glide = Math.atan2(dz, ds)
    end

    def climb_or_glide
      if @climb >= 0.0
        @climb
      else
        1.0 / Math.tan(@glide)
      end
    end

  end

  module Extreme

    class Base

      attr_reader :fix

      def initialize(fix)
        @fix = fix
      end

    end

    class Minimum < Base; end
    class Maximum < Base; end

  end

  attr_reader :bounds
  attr_reader :averages
  attr_reader :alt_extremes

  def analyse
    analyse_averages(15)
    analyse_altitude_extremes(64, 1.0 / 8.0)
    @bounds = Bounds.new
    @bounds.lat = @fixes.collect(&:lat).bounds
    @bounds.lon = @fixes.collect(&:lon).bounds
    @bounds.alt = @fixes.collect(&:alt).bounds
    @bounds.time = @fixes[0].time..@fixes[-1].time
    @bounds.speed = @averages.collect(&:speed).bounds(0.0, nil)
    @bounds.climb = @averages.collect(&:climb).bounds(-0.5, 0.5)
    @bounds.glide = @averages.collect(&:glide).bounds
    self
  end

  def analyse_averages(dt)
    fix0 = @fixes[0]
    accumulator = 0.0
    s = @fixes.collect do |fix1|
      accumulator += fix0.distance_to(fix1)
      fix0 = fix1
      accumulator
    end
    i0 = i1 = 0
    n = @fixes.length
    k = t0 = z0 = s0 = t1 = z1 = s1 = nil
    @averages = @fixes.collect do |fix|
      t0 = fix.time - 0.5 * dt
      i0 += 1 while @fixes[i0].time < t0
      if i0 == 0
        z0 = @fixes[0].alt
        s0 = s[0]
      else
        k = (t0 - @fixes[i0 - 1].time) / (@fixes[i0].time - @fixes[i0 - 1].time)
        z0 = k * @fixes[i0 - 1].alt + (1.0 - k) * @fixes[i0].alt
        s0 = k * s[i0 - 1] + (1.0 - k) * s[i0]
      end
      t1 = t0 + dt
      i1 += 1 while i1 < n and @fixes[i1].time < t1
      if i1 == n
        z1 = @fixes[-1].alt
        s1 = s[-1]
      else
        k = (t1 - @fixes[i1 - 1].time) / (@fixes[i1].time - @fixes[i1 - 1].time)
        z1 = k * @fixes[i1 - 1].alt + (1.0 - k) * @fixes[i1].alt
        s1 = k * s[i1 - 1] + (1.0 - k) * s[i1]
      end
      Average.new(s1 - s0, z1 - z0, dt)
    end
  end

  def remove_adjacent_extremes(extremes)
    result = []
    best = nil
    extremes.each do |extreme|
      if best.nil?
        best = extreme
      elsif extreme.class == best.class
        case best
        when Extreme::Maximum
          best = extreme if extreme.fix.alt > best.fix.alt
        when Extreme::Minimum
          best = extreme if extreme.fix.alt < best.fix.alt
        end
      else
        result << best
        best = extreme
      end
    end
    result << best if best
    result
  end

  def analyse_altitude_extremes(absolute, relative)
    extremes = []
    last_extreme_fix = @fixes[0]
    direction = 0
    @fixes.each_cons(2) do |fix0, fix1|
      case direction
      when -1
        case fix1.alt <=> fix0.alt
        when -1
          last_extreme_fix = fix1
        when  1
          extremes << Extreme::Minimum.new(last_extreme_fix)
          last_extreme_fix = fix1
          direction = 1
        end
      when  0
        case fix1.alt <=> fix0.alt
        when -1
          extremes << Extreme::Maximum.new(last_extreme_fix)
          last_extreme_fix = fix1
          direction = -1
        when  1
          extremes << Extreme::Minimum.new(last_extreme_fix)
          last_extreme_fix = fix1
          direction = 1
        end
      when  1
        case fix1.alt <=> fix0.alt
        when -1
          extremes << Extreme::Maximum.new(last_extreme_fix)
          last_extreme_fix = fix1
          direction = -1
        when  1
          last_extreme_fix = fix1
        end
      end
    end
    case direction
    when -1 then extremes << Extreme::Minimum.new(last_extreme_fix)
    when  1 then extremes << Extreme::Maximum.new(last_extreme_fix)
    end
    loop do
      discard = {}
      extremes.each_cons(4) do |extreme0, extreme1, extreme2, extreme3|
        dz03 = (extreme3.fix.alt - extreme0.fix.alt).abs
        dz12 = (extreme2.fix.alt - extreme1.fix.alt).abs
        if dz12 < absolute or dz12.to_f / dz03 < relative
          case extreme0
          when Extreme::Minimum
            discard[extreme0.fix.alt < extreme2.fix.alt ? extreme2 : extreme0] = true
            discard[extreme1.fix.alt > extreme3.fix.alt ? extreme3 : extreme1] = true
          when Extreme::Maximum
            discard[extreme0.fix.alt > extreme2.fix.alt ? extreme2 : extreme0] = true
            discard[extreme1.fix.alt < extreme3.fix.alt ? extreme3 : extreme1] = true
          end
        end
      end
      break if discard.empty?
      extremes.delete_if { |extreme| discard[extreme] }
      extremes = remove_adjacent_extremes(extremes)
      discard = {}
      extremes.each_cons(3) do |extreme0, extreme1, extreme2|
        case extreme1
        when Extreme::Maximum
          discard[extreme1] = true if extreme1.fix.alt < extreme0.fix.alt or extreme1.fix.alt < extreme2.fix.alt
        when Extreme::Minimum
          discard[extreme1] = true if extreme1.fix.alt > extreme0.fix.alt or extreme1.fix.alt > extreme2.fix.alt
        end
      end
      unless discard.empty?
        extremes.delete_if { |extreme| discard[extreme] }
        extremes = remove_adjacent_extremes(extremes)
      end
    end
    @alt_extremes = extremes
  end

end
