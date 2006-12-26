module Enumerable

  def bounds(min = nil, max = nil)
    each do |element|
      min = element if min.nil? or element < min
      max = element if max.nil? or element > max
    end
    min.nil? ? nil : min..max
  end

end

class Bounds

  def initialize(hash = {})
    @hash = hash
  end

  def each(&block)
    @hash.each(&block)
  end

  def merge(other)
    other.each do |key, value|
      @hash[key] = @hash.has_key?(key) ? @hash[key].merge(value) : value
    end
    self
  end

  def method_missing(id, *args)
    if @hash.has_key?(id)
      raise ArgumentError unless args.empty?
      @hash[id]
    elsif /\A(.*)=\z/.match(id.to_s)
      raise ArgumentError unless args.length == 1
      @hash[$1.intern] = args[0]
    else
      super
    end
  end

end
