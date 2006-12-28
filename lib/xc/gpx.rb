require "gpx"
require "xc"

class GPX

  element :Circuit
  element :League
  element :Multiplier

end

module XC

  class Turnpoint

    def to_gpx
      trkpt = GPX::TrkPt.new("lat" => Radians.to_deg(@lat), "lon" => Radians.to_deg(@lon))
      trkpt.add(GPX::League.new(@league.name))
      trkpt.add(GPX::Name.new(@name))
      trkpt.add(GPX::Time.new(@time.to_gpx))
      trkpt
    end

  end

  class Flight

    def to_gpx
      trk = GPX::Rte.new
      trk.add(GPX::Name.new(name))
      trk.add(GPX::Circuit.new) if circuit?
      trk.add(GPX::Multiplier.new(multiplier)) unless multiplier == 1.0
      @turnpoints.collect(&:to_gpx).each(&trk.method(:add))
      trk
    end

  end

end
