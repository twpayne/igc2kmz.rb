require "coord"
require "date"
require "digest/md5"

class IGC

  class Fix < Coord

    attr_reader :time
    attr_reader :validity
    attr_reader :gnss_alt
    attr_reader :extensions

    def initialize(time, lat, lon, alt = 0, validity = 0, gnss_alt = 0, extensions = {})
      super(lat, lon, alt)
      @time = time
      @validity = validity
      @gnss_alt = gnss_alt
      @extensions = extensions
    end

  end

  class Waypoint < Coord

    attr_reader :name

    def initialize(lat, lon, alt, name)
      super(lat, lon, alt)
      @name = name
    end

  end

  Extension = Struct.new(:bytes, :code)

  attr_reader :filename
  attr_reader :flight_recorder
  attr_reader :header
  attr_reader :extensions
  attr_reader :route
  attr_reader :fixes
  attr_reader :security_code
  attr_reader :bsignature
  attr_reader :unknowns
  attr_reader :altitude_data

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
    "TZO" => :timezone_offset,
  }

  def initialize(io)
    @filename = io.respond_to?(:path) ? File.basename(io.path) : nil
    @flight_recorder = {}
    @header = {}
    @extensions = []
    @route = []
    @fixes = []
    @security_code = []
    @unknowns = []
    bdigest = Digest::MD5.new
    date = nil
    sec0 = -1
    io.each do |line|
      line = line.chomp
      case line
      when /\AA(.*?)\s*\z/i
        @flight_recorder = $1
      when /\AH([FOP])DTE(\d\d)(\d\d)(\d\d)\s*\z/i
        year = $4.to_i
        if line[5, 6] == "000000"
          date = Date.new(1970, 1, 1)
        else
          date = Date.new((year < 70 ? 2000 : 1900) + year, $3.to_i, $2.to_i)
        end
        @header[:date] ||= date
      when /\AH([FOP])DTM(\d\d\d)[A-Z]*:(.*?)\s*\z/i
        (@header[:datum] ||= {})[$2.to_i] = $3
      when /\AH([FOP])FXA(\d{3})\s*\z/i
        @header[:fix_accuracy] = $2.to_i
      when /\AH([FOP])(#{HEADERS.keys.join("|")})[ A-Z]*:(.*?)\s*\z/io
        @header[HEADERS[$2]] = $3
      when /\AI(\d\d)(\d{4}[0-9A-Z]{3})*\s*\z/i
        unless $1.to_i.zero?
          $2.scan(/(\d\d)(\d\d)([0-9A-Z]{3})/) do |md|
            @extensions << Extension.new(($1.to_i - 1)...$2.to_i, $3.intern)
          end
        end
      when /\AC(\d\d)(\d\d)(\d{3})([NS])(\d{3})(\d\d)(\d{3})([EW])(.*?)\s*\z/i
        lat = Radians.new_from_dmsh($1.to_i, $2.to_i + 0.001 * $3.to_i, 0, $4)
        lon = Radians.new_from_dmsh($5.to_i, $6.to_i + 0.001 * $7.to_i, 0, $8)
        @route << Waypoint.new(lat, lon, 0, $9)
      when /\AB(\d\d)(\d\d)(\d\d)(\d\d)(\d{5})([NS])(\d{3})(\d{5})([EW])([AV])(\d{5}|-\d{4})(\d{5}|-\d{4})(.*?)\s*\z/i
        bdigest << line
        hour = $1.to_i
        min = $2.to_i
        sec = $3.to_i
        sec1 = 3600 * hour + 60 * min + sec
        date += 1 if sec1 < sec0
        time = Time.utc(date.year, date.month, date.mday, hour, min, sec)
        sec0 = sec1
        lat = Radians.new_from_dmsh($4.to_i, 0.001 * $5.to_i, 0, $6)
        lon = Radians.new_from_dmsh($7.to_i, 0.001 * $8.to_i, 0, $9)
        extensions = @extensions.collect do |extension|
          line[extension.bytes].to_i
        end
        @fixes << Fix.new(time, lat, lon, $11.to_i, $10.intern, $12.to_i, extensions)
      when /\AL/i
      when /\AG(.*)\s*\z/i
        @security_code << $1
      when /\A\s*\z/
      else
        @unknowns << line
      end
    end
    @bsignature = bdigest.hexdigest
    if @fixes.find { |fix| fix.alt.nonzero? }
      @altitude_data = true
    elsif @fixes.find { |fix| fix.gnss_alt.nonzero? }
      @altitude_data = true
      @fixes.each do |fix|
        fix.alt = fix.gnss_alt
      end
    else
      @altitude_data = false
    end
    @times = @fixes.collect(&:time).collect!(&:to_i)
  end

  def fix_at(time)
    @fixes[@times.find_first_ge(time.to_i) || -1]
  end

end
