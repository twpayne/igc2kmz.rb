require "gpx"
require "optima"

class GPX

  element :Circuit
  element :League
  element :Multiplier

end

class Optimum

  def to_gpx
    rte = GPX::Rte.new
    rte.add(GPX::Type.new(@flight_type))
    rte.add(GPX::Circuit.new) if @circuit
    rte.add(GPX::Multiplier.new(@multiplier)) unless @multiplier == 1.0
    @fixes.each_with_index do |fix, index|
      rtept = GPX::RtePt.new("lat" => Radians.to_deg(fix.lat), "lon" => Radians.to_deg(fix.lon))
      rtept.add(GPX::Name.new(@names[index]))
      rte.add(rtept)
    end
    rte
  end

end

class Optima

  def to_gpx
    gpx = GPX.new
    gpx.root.add(GPX::League.new(@league)) if @league
    @optima.collect(&:to_gpx).each(&gpx.root.method(:add))
    gpx
  end

end
