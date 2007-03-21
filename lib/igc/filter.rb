require "enumerator"
require "igc"

class IGC

  def filter_duplicate_fixes!
    filtered_fixes = [@fixes.first]
    @fixes.each_cons(2) do |fix0, fix1|
      filtered_fixes << fix1 unless fix0.lat == fix1.lat and fix0.lon == fix1.lon
    end
    @fixes = filtered_fixes
    @times = @fixes.collect(&:time).collect!(&:to_i)
    self
  end

end
