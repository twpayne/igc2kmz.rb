require "coord"

class TimeSeries

  attr_reader :t
  attr_reader :x

  def initialize(t, x)
    @t = t
    @x = x
  end

  def at(time)
    @x[@t.find_first_ge(time.to_i) || -1]
  end

  def each(&block)
    @t.each_with_index do |t, i|
      yield(t, @x[i])
    end
  end

  def interpolate(fix, delta)
    coord = super(fix, delta)
    return nil unless coord
    time = Time.at(((1.0 - delta) * @time.to_f + delta * fix.time.to_f).ceil).utc
    Fix.new(time, coord.lat, coord.lon, coord.alt)
  end

end

module Track

  class Base

    class Waypoint < Coord

      attr_reader :name

      def initialize(lat, lon, alt, name)
        super(lat, lon, alt)
        @name = name
      end

    end

    class Task

      attr_accessor :declaration_time
      attr_accessor :flight_date
      attr_accessor :task_number
      attr_accessor :turnpoints
      attr_accessor :description
      attr_reader :route

      def initialize
        @route = []
      end

    end

    attr_reader :filename
    attr_reader :header
    attr_reader :times
    attr_reader :fixes
    attr_reader :tz_offset
    attr_reader :task
    attr_reader :extras

    def initialize(io, options = {})
      if options[:filename]
        @filename = options[:filename]
      elsif io.respond_to?(:path)
        @filename = File.basename(io.path)
      else
        @filename = nil
      end
      @header = {}
      @times = []
      @fixes = []
      @tz_offset = 0
      @task = nil
      @extras = {}
    end

    def altitude_data?
      unless @altitude_data.nil?
        if @fixes.find { |fix| fix.alt.nonzero? }
          @altitude_data = true
        elsif @extras[:gnss_alt] and @extras[:gnss_alt].x.find { |gnss_alt| gnss_alt.nonzero? }
          @fixes.each_with_index do |fix, i|
            @fixes[i].alt = @extras[:gnss_alt].x[i]
          end
          @altitude_data = true
        else
          @altitude_data = false
        end
      end
      @altitude_data
    end

  end

end
