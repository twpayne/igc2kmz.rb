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

end

require "ccoord"
