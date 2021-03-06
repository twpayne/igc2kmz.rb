require "abbrev"
require "date"

module Comparable

  def constrain(minimum = nil, maximum = nil)
    minimum, maximum = minimum.first, minimum.last if minimum.is_a?(Range)
    return minimum if minimum and self < minimum
    return maximum if maximum and self > maximum
    self
  end

end

module Enumerable

  def collect_with_index
    result = []
    each_with_index do |element, index|
      result.push(yield(element, index))
    end
    result
  end

  def hash_by(default = nil)
    result = Hash.new(default)
    each do |object|
      result[yield(object)] = object
    end
    result
  end

  def segment(exclude_end = true)
    first = index = 0
    last_value = nil
    result = []
    each do |value|
      if index.zero?
        last_value = value
      elsif value != last_value
        result << Range.new(first, index, exclude_end)
        last_value = value
        first = index
      end
      index += 1
    end
    result << Range.new(first, exclude_end ? index : index - 1, exclude_end) unless index.zero?
  end

end

class Array

  def binary_search(value)
    left = 0
    right = length
    while left <= right
      middle = (left + right) / 2
      case block_given? ? yield(value, self[middle]) : value <=> self[middle]
      when -1 then right = middle - 1
      when  0 then return middle
      when  1 then left = middle + 1
      end
    end
    nil
  end

  def find_first_ge(value)
    left = 0
    right = length
    while left < right
      middle = (left + right) / 2
      case block_given? ? yield(value, self[middle]) : value <=> self[middle]
      when -1 then right = middle - 1
      when  0 then right = middle
      when  1 then left = middle + 1
      end
    end
    return left == length ? nil : left
  end

  def strip_trailing_nils
    last = -1
    each_with_index do |element, index|
      last = index unless element.nil?
    end
    last == -1 ? [] : self[0..last]
  end

  def to_h
    result = {}
    each_with_index do |element, index|
      result[index] = element
    end
    result
  end

end

class Class

  def module_heirarchy
    klass = Object
    name.split(/::/).collect! do |const|
      klass = klass.const_get(const)
    end.reverse!
  end

end

class Date

  def to_time
    Time.utc(year, month, day)
  end

end

class Hash

  def abbrev(pattern = nil)
    result = {}
    Abbrev::abbrev(self.keys, pattern).each do |key, value|
      result[key] = self[value]
    end
    result
  end

end

class NilClass

  def default(value = nil)
    value
  end

end

class Object

  def default(value = nil, &block)
    block ? instance_eval(&block) : self
  end

end

class Range

  def <=>(range)
    # FIXME include exclude_end?
    (first <=> range.first).nonzero? or (last <=> range.last).nonzero? or 0
  end

  def constrain(minimum = nil, maximum = nil)
    minimum, maximum = minimum.first, minimum.last if minimum.is_a?(Range)
    minimum = first > minimum ? first : minimum
    maximum = last < maximum ? last : maximum
    minimum..maximum
  end

  def merge(range)
    start = first < range.first ? first : range.first
    if exclude_end?
      if range.exclude_end?
        stop = last > range.last ? last : range.last
        exclusive = true
      else
        case last <=> range.last
        when -1 then stop, exclusive = range.last, false
        when  0 then stop, exclusive = range.last, true
        when  1 then stop, exclusive = last, false
        end
      end
    else
      if range.exclude_end?
        case last <=> range.last
        when -1 then stop, exclusive = range.last, false
        when  0 then stop, exclusive = range.last, true
        when  1 then stop, exclusive = last, false
        end
      else
        stop = last > range.last ? last : range.last
        exclusive = false
      end
    end
    Range.new(start, stop, exclusive)
  end

  def overlap?(range)
    return true if include?(range.first)
    return true if !range.exclude_end? and include?(range.last)
    if exclude_end?
      return false if last <= range.first
    else
      return false if last < range.first
    end
    if range.exclude_end?
      return false if range.last <= first
    else
      return false if range.last < first
    end
    true
  end

  def size
    last - first
  end

  alias length size

end

class String

  XML_ENTITIES = { "\"" => "quot", "&" => "amp", "'" => "apos", "<" => "lt", ">" => "gt" }

  def to_xml
    gsub(/[^\x20-\x21\x23-\x25\x28-\x3b\x3d\x3f-\x7f]/) do |s|
      "&#{XML_ENTITIES[s] || "#x%x" % s[0]};"
    end
  end

end

class Symbol

  def to_proc(*args)
    lambda do |object|
      object.send(self, *args)
    end
  end

end

class Time

  def to_date(sg = Date::ITALY)
    Date.new(year, mon, day, sg)
  end

end
