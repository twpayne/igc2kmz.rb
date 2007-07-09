require "date"
require "track"

module Track

  class TNC < Base

    class Zeit

      def initialize(time, wind_speed, wind_dir, mcready)
        @time = time
        @wind_speed = wind_speed
        @wind_dir = @wind_dir
        @mcready = mcready
      end

    end

    class Fix

      def initialize(time, lat, lon, alt, vario, tas, speed, course, temp)
        @time = time
        @lat = lat
        @lon = lon
        @alt = alt
        @vario = vario
        @tas = tas
        @speed = speed
        @course = course
        @temp = temp
      end

    end

    def initialize(io, options = {})
      super(io, options)
      line = io.readline
      md = /\A
        @                   #    Kennung
        TN                  #    'TOP-NAVIGATOR'
        ([0-7])             #  1 Polare '0'..7
        .                   #    reserved
        ([0-9A-F]{4})       #  2 TN S|N (HEX)
        (\d)(\d)            #  3 SW-Version
        ..                  #    reserved
        ([0-9A-F]{2})       #  5 If. Barogramm-Nr. (HEX)
        (\d\d)(\d\d)(\d\d)  #  6 FLugdatuM (BCD)
        (\d\d)(\d\d)        #  9 Takeoff-Zeit (BCD)
        (\d\d)(\d\d)        # 11 Lande-Zeit (BCD)
        (\d\d)              # 13 LokalZeit - UTC (BCD)
        (.{11})             # 14 Takeoff-location (ASCII)
        ([0-9A-F]{4})       # 15 delta_Hohe_QHN (m) (HEX)
        ([0-9A-F]{4})       # 16 Takeoff-Hohe (m) (HEX)
        ([0-9A-F]{4})       # 17 Lande-Hohe (m) (HEX)
        ([0-9A-F]{4})       # 18 Maximal-Hohe (m) (HEX)
        ([0-9A-F]{4})       # 19 max. Hohengewinn (m) (HEX)
        ([0-9A-F]{4})       # 20 Summer aller Hohengewinne(m) (HEX)
        ([0-9A-F]{2})       # 21 max. Steigen (0.1 m|s) (HEX)
        ([0-9A-F]{2})       # 22 max. Sinken (0.1 m|s) (HEX)
        ..                  #    reserved
        ([0-9A-F]{2})       # 23 max. TAS (0.5 km|h) (HEX)
        ([0-9A-F]{4})       # 24 Distanz zwischen Takeoff und Landung (0.1 km) (HEX) order Dreieck zw. TPT
        \r\n
        \z/x.match(line)
      raise line unless md
      date = Date.new(2000 + md[6].to_i, md[7].to_i, md[8].to_i)
      utc_offset = 60 * md[13].to_i
      @header = {
        :flight_recorder => "TOP-NAVIGATOR",
        :polar => md[1].to_i,
        :serial_number => md[2].hex,
        :software_version => "%d.%02d" % [md[3].to_i, md[4].to_i],
        :barogram => md[5].hex,
        :takeoff_time => Time.utc(date.year, date.mon, date.day, md[9].to_i, md[10].to_i) + utc_offset,
        :landing_time => Time.utc(date.year, date.mon, date.day, md[11].to_i, md[12].to_i) + utc_offset,
        :takeoff => md[14].strip,
        :delta_QNH_height => 953 + 121.0 * md[15].hex / 1023,
        :takeoff_altitude => md[16].hex,
        :landing_altitude => md[17].hex,
        :max_altitude => md[18].hex,
        :max_altitude_gain => md[19].hex,
        :total_altitude_gain => md[20].hex,
        :max_climb => 0.1 * md[21].hex,
        :max_sink => 0.1 * md[22].hex,
        :max_speed => 0.5 * md[23].hex,
        :distance => 0.1 * md[24].hex,
      }
      time = nil
      @extras[:vario] = TimeSeries.new(@times, [])
      @extras[:tas] = TimeSeries.new(@times, [])
      @extras[:speed] = TimeSeries.new(@times, [])
      @extras[:course] = TimeSeries.new(@times, [])
      @extras[:temp] = TimeSeries.new(@times, [])
      @zeit_times = []
      @extras[:wind_speed] = TimeSeries.new(@zeit_times, [])
      @extras[:wind_dir] = TimeSeries.new(@zeit_times, [])
      @extras[:mcready] = TimeSeries.new(@zeit_times, [])
      io.each do |line|
        case line
        when /\A
          (\d\d)(\d\d)(\d\d)  #  1 Beginzeit (lokal) des folgenden 30s - Flugdatenblocks (BCD)
          ([0-9A-F]{2})       #  4 Windschwindigkeit (0.5 km|h) (HEX)
          ([0-9A-F]{2})       #  5 Windrichtung (2 degrees) (HEX)
          (\d)                #  6 M Cready (0.5 m|s) (BCD)
          AC                  #    AIRCOTEC
          .                   #    reserved
          \r\n
          \z/x
          md = Regexp.last_match
          time = Time.utc(date.year, date.mon, date.day, md[1].to_i, md[2].to_i, md[3].to_i) + utc_offset
          @zeit_times << time.to_i
          @extras[:wind_speed].x << 0.5 * md[4].hex
          @extras[:wind_dir].x << 2 * md[5].hex
          @extras[:mcready].x << 0.5 * md[6].hex
        when /\A
          ([0-9A-F]{6})  #  1 Latitude (0.01') von GPS (HEX)
          ([0-9A-F]{6})  #  2 Longitude (0.01') von GPS (HEX)
          ([0-9A-F]{4})  #  3 Altitude (m) (HEX)
          ([0-9A-F]{2})  #  4 Vario (0.1 m|s) (HEX)
          ([0-9A-F]{2})  #  5 True Air Speed (0.5 km|h) (HEX)
          ([0-9A-F]{2})  #  6 Speed over Ground von GPS (HEX)
          ([0-9A-F]{2})  #  7 Course over Ground (2 deg) von GPS (HEX)
          ([0-9A-F]{3})  #  8 Temperatur (0.1 K absolut) (HEX)
          ..             #    reserved
          (.)            #  9 FLAG
          \r\n
          \z/x
        md = Regexp.last_match
        time += 1
        @times << time.to_i
        @fixes << Coord.new(md[1].hex / 6000.0, md[2].hex / 6000.0, md[3].hex)
        @extras[:vario].x << 0.1 * md[4].hex
        @extras[:tas].x << 0.5 * md[5].hex
        @extras[:speed].x << md[6].hex
        @extras[:course].x << 2 * md[7].hex
        @extras[:temp].x << 0.1 * md[8].hex
        when /\A@EOF\r\n\z/
          break
        end
      end
    end

  end

end
