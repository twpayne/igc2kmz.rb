require "lib"

module Radians

  HEMISPHERES = {"NORTH" => 1, "SOUTH" => -1, "EAST" => 1, "WEST" => -1}.abbrev

  class << self

    def new_from_deg(deg)
      deg * Math::PI / 180.0
    end

    def new_from_dmsh(deg, min, sec, hemi)
      new_from_deg((HEMISPHERES[hemi] || hemi) * (deg + min / 60.0 + sec / 3600.0))
    end

    def to_deg(rad)
      rad * 180.0 / Math::PI
    end

    def new_from_s(s)
      md = /([+\-])?.*?(\d+(?:\.\d+)?)(?:.*?(\d+(?:\.\d+)?)(?:.*?(\d+(?:\.\d+)?))?)?(?:.*?\b(#{HEMISPHERES.keys.join('|')})\b)?/i.match(s)
      raise s unless md
      new_from_dmsh(md[2].to_f, md[3].to_f, md[4].to_f, (md[1] == '-' ? -1 : 1) * (md[5] ? HEMISPHERES[md[5].upcase] : 1))
    end

  end

end

class Numeric

  def to_deg
    Radians.to_deg(self)
  end

end

class Coord

  attr_accessor :lat
  attr_accessor :lon
  attr_accessor :alt

  def initialize(lat, lon, alt)
    @lat = lat
    @lon = lon
    @alt = alt
  end

  class << self

    def line_segment_intersection(coord0, coord1, coord2, coord3)
      n0 = (coord1.lon - coord0.lon) * (coord2.lat - coord0.lat) - (coord1.lat - coord0.lat) * (coord2.lon - coord0.lon)
      return nil if n0.zero?
      d = (coord1.lat - coord0.lat) * (coord3.lon - coord2.lon) - (coord1.lon - coord0.lon) * (coord3.lat - coord2.lat)
      return nil if d.zero?
      return nil unless (0.0..1.0).include?(n0 / d)
      n1 = (coord3.lon - coord2.lon) * (coord2.lat - coord0.lat) - (coord3.lat - coord2.lat) * (coord2.lon - coord0.lon)
      return nil if n1.zero?
      return nil unless (0.0..1.0).include?(n1 / d)
      [n1 / d, n0 / d]
    end

  end

end

require "ccoord"
