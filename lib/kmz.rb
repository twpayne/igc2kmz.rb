require "kml"
require "zip/zip"

class KMZ

  attr_reader :elements
  attr_reader :roots
  attr_reader :files

  def initialize(*args)
    @elements = []
    @roots = []
    @files = {}
    args.each do |arg|
      case arg
      when Hash
        arg.each do |key, value|
          case key
          when :roots then merge_roots(*value)
          when :files then merge_files(value)
          else raise
          end
        end
      when KML::Element
        @elements << arg
      else
        raise
      end
    end
  end

  def merge(kmz)
    merge_elements(*kmz.elements)
    merge_roots(*kmz.roots)
    merge_files(kmz.files)
    self
  end

  def merge_roots(*roots)
    @roots.concat(roots)
    self
  end

  def merge_elements(*elements)
    if @elements.empty?
      @elements = elements
    else
      @elements[0].add(*elements)
    end
    self
  end

  def merge_files(files)
    @files.merge!(files)
    self
  end

  def write(filename)
    doc = KML::Document.new
    doc.add(*@roots)
    doc.add(*@elements)
    Zip::ZipOutputStream.open(filename) do |kmz|
      kmz.put_next_entry("doc.kml")
      KML.new(doc).pretty_write(kmz)
      @files.each do |filename, contents|
        kmz.put_next_entry(filename)
        kmz.write(contents.respond_to?(:read) ? contents.read : contents)
      end
    end
  end

end
