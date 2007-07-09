require "track"
require "date"
require "digest/md5"

module Track

  class IGC < Base

    attr_reader :security_code
    attr_reader :unknowns

    HEADERS = {
      "CCL" => :competition_class,
      "CID" => :competition_id,
      "FTY" => :flight_recorder_type,
      "GID" => :glider_id,
      "GPS" => :gps,
      "GTY" => :glider_type,
      "PLT" => :pilot,
      "RFW" => :firmware_revision,
      "RHW" => :hardware_revision,
      "SIT" => :site,
    }

    class Extension

      attr_reader :code
      attr_reader :bytes

      def initialize(code, bytes)
        @code = code
        @bytes = bytes
      end

    end

    def initialize(io, options = {})
      super(io, options)
      @security_code = []
      @unknowns = []
      bdigest = Digest::MD5.new
      date = nil
      sec0 = -1
      @times = []
      @extras[:validity] = TimeSeries.new(@times, [])
      @extras[:gnss_alt] = TimeSeries.new(@times, [])
      extensions = []
      io.each do |line|
        line = line.chomp
        case line
        when /\A\x13?A(.*?)\s*\z/i
          @header[:flight_recorder] = $1
        when /\AH([FOP])DTE(\d\d)(\d\d)(\d\d)\s*\z/i
          year = $4.to_i
          begin
            date = Date.new(2000 + year, $3.to_i, $2.to_i)
            Time.utc(date.year, date.month, date.mday)
          rescue ArgumentError
            date = Date.new(2000, 1, 1)
          end
          @header[:date] ||= date
        when /\AH([FOP])DTM(\d\d\d)[A-Z]*:(.*?)\z/i
          value = $3.strip
          (@header[:datum] ||= {})[$2.to_i] = value unless value.empty?
        when /\AH([FOP])FXA(\d{3})\s*\z/i
          @header[:fix_accuracy] = $2.to_i
        when /\AH([FOP])TZ[NO][ A-Z]*:\s*([+\-]?)(\d+)(?::(\d\d))?\s*\z/i
          @tz_offset = ($2 == "-" ? -60 : 60) * (60 * $3.to_i + ($4 ? $4.to_i : 0))
        when /\AH([FOP])(#{HEADERS.keys.join("|")})[ A-Z]*:(.*?)\z/io
          key = HEADERS[$2]
          value = $3.strip
          @header[key] = value unless /\A(|none|not\s+set)\z/i.match(value)
        when /\AI(\d\d)(\d{4}[0-9A-Z]{3})*\s*\z/i
          unless $1.to_i.zero?
            $2.scan(/(\d\d)(\d\d)([0-9A-Z]{3})/i) do |md|
              code = $3.downcase.to_sym
              extensions << Extension.new(code, ($1.to_i - 1)...$2.to_i)
              @extras[code] = TimeSeries.new(@times, [])
            end
          end
        when /\AC(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d{4})(\d\d)(.*?)\s*\z/i
          @task ||= Task.new
          begin
            @task.declaration_time = Time.utc(2000 + $3.to_i, $2.to_i, $1.to_i, $4.to_i, $5.to_i, $6.to_i)
          rescue ArgumentError
          end
          begin
            @task.flight_date = Date.new(2000 + $9.to_i, $8.to_i, $7.to_i)
          rescue ArgumentError
          end
          @task.task_number = $10.to_i
          @task.turnpoints = $11.to_i
          @task.description = $12
        when /\AC(\d\d)(\d\d)(\d{3})([NS])(\d{3})(\d\d)(\d{3})([EW])(.*)\z/i
          @task ||= Task.new
          lat = Radians.new_from_dmsh($1.to_i, $2.to_i + 0.001 * $3.to_i, 0, $4)
          lon = Radians.new_from_dmsh($5.to_i, $6.to_i + 0.001 * $7.to_i, 0, $8)
          @task.route << Waypoint.new(lat, lon, 0, $9.strip)
        when /\AB(\d\d)(\d\d)(\d\d)(\d\d)(\d{5})([NS])(\d{3})(\d{5})([EW])([AV])(\d{5}|-\d{4})(\d{5}|-\d{4})(.*)\z/i
          bdigest << line
          begin
            hour = $1.to_i
            min = $2.to_i
            sec = $3.to_i
            sec1 = 3600 * hour + 60 * min + sec
            date += 1 if sec1 < sec0
            @times << Time.utc(date.year, date.month, date.mday, hour, min, sec).to_i
            sec0 = sec1
            lat = Radians.new_from_dmsh($4.to_i, 0.001 * $5.to_i, 0, $6)
            lon = Radians.new_from_dmsh($7.to_i, 0.001 * $8.to_i, 0, $9)
            @fixes << Coord.new(lat, lon, $11.to_i)
            @extras[:validity].x << $10.to_sym
            @extras[:gnss_alt].x << $12.to_i
            extensions.each do |extension|
              @extras[extension.code].x << line[extension.bytes].to_i
            end
          rescue ArgumentError
          end
        when /\A[DEFJKL]/i
        when /\AG(.*)\z/i
          @security_code << $1.strip
        when /\A\x11?\s*\z/
        else
          @unknowns << line
        end
      end
      @bsignature = bdigest.hexdigest
    end

  end

end
