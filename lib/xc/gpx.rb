require "gpx"
require "xc"

class GPX

  element :Circuit
  element :Distance
  element :Multiplier
  element :Score

end

module XC

  class Turnpoint

    def to_gpx
      rtept = GPX::RtePt.new("lat" => Radians.to_deg(@lat), "lon" => Radians.to_deg(@lon))
      rtept.add(GPX::Name.new(@name))
      rtept.add(GPX::Ele.new(@alt))
      rtept.add(GPX::Time.new(@time.to_gpx))
      rtept
    end

  end

  class Flight

    def to_gpx
      rte = GPX::Rte.new
      rte.add(GPX::Desc.new(type))
      extensions = GPX::Extensions.new
      extensions.add(GPX::Circuit.new) if circuit?
      extensions.add(GPX::Distance.new(@distance.to_s))
      extensions.add(GPX::Multiplier.new(MULTIPLIER.to_s))
      extensions.add(GPX::Score.new(@score.to_s))
      rte.add(extensions)
      rte.add(GPX::Multiplier.new(multiplier)) unless multiplier == 1.0
      @turnpoints.collect(&:to_gpx).each(&rte.method(:add))
      rte
    end

  end

end
