require "enumerator"

class Optimum

  attr_reader :fixes
  attr_reader :names
  attr_reader :flight_type
  attr_reader :multiplier
  attr_reader :circuit

  def initialize(fixes, names, flight_type, multiplier, circuit)
    @fixes = fixes
    @names = names
    @flight_type = flight_type
    @multiplier = multiplier
    @circuit = circuit
  end

  def distance
    return @distance if @distance
    @distance = 0.0
    if @circuit
      @fixes[1...-1].each_cons(2) do |fix0, fix1|
        @distance += fix0.distance_to(fix1)
      end
      @distance += @fixes[-2].distance_to(@fixes[1])
    else
      @fixes.each_cons(2) do |fix0, fix1|
        @distance += fix0.distance_to(fix1)
      end
    end
    @distance
  end

  def score
    @multiplier * distance / 1000.0
  end

end

class Optima

  def initialize(optima, league, complexity)
    @optima = optima
    @league = league
    @complexity = complexity
  end

  def each(&block)
    @optima.each(&block)
  end

end

require "coptima"
