require "coord"

class Coord

  def to_kml_coord
    "%.6f,%.6f,%d" % [Radians.to_deg(lon), Radians.to_deg(lat), alt]
  end

end

class KML

  VERSION = [2, 1].extend(Comparable)

  def initialize(root)
    @kml = KML::Kml.new
    @kml.add_attributes(:xmlns => "http://earth.google.com/kml/#{VERSION.join(".")}")
    @kml.add(root)
  end

  def write(io)
    io.write("<?xml version=\"1.0\"?>")
    @kml.write(io)
  end

  def pretty_write(io, indent = "  ")
    io.write("<?xml version=\"1.0\"?>\n")
    @kml.pretty_write(io, indent, "")
  end

  class Element

    def initialize
      @attributes = {}
    end

    def add_attributes(attrs)
      @attributes.merge!(attrs)
    end

    def kml_id
      "%x" % object_id.abs
    end

    def url
      "##{kml_id}"
    end

  end

  class SimpleElement < Element

    def text=(value)
      @text = value
    end

    def write(io)
      name = self.class.const_get("NAME")
      io.write("<#{name}")
      @attributes.each do |attribute, value|
        io.write(" #{attribute}=\"#{value}\"")
      end
      io.write(@text ? ">#{@text}</#{name}>" : "/>")
    end

    def pretty_write(io, indent, leader)
      io.write(leader)
      write(io)
      io.write("\n")
    end

    class << self

      def new(*args)
        element = super()
        args.each do |arg|
          case arg
          when nil
          when Hash
            element.add_attributes(arg)
          else
            element.text = arg.to_s
          end
        end
        element
      end

    end

  end

  class ComplexElement < Element

    def add(*children)
      if @children
        @children.concat(children)
      else
        @children = children
      end
      self
    end

    def write(io)
      name = self.class.const_get("NAME")
      io.write("<#{name}")
      @attributes.each do |attribute, value|
        io.write(" #{attribute}=\"#{value}\"")
      end
      if @children and !@children.empty?
        io.write(">")
        @children.each do |child|
          child.write(io)
        end
        io.write("</#{name}>")
      else
        io.write("/>")
      end
    end

    def pretty_write(io, indent, leader)
      name = self.class.const_get("NAME")
      io.write("#{leader}<#{name}")
      @attributes.each do |attribute, value|
        io.write(" #{attribute}=\"#{value}\"")
      end
      if @children and !@children.empty?
        io.write(">\n")
        child_leader = leader + indent
        @children.each do |child|
          child.pretty_write(io, indent, child_leader)
        end
        io.write("#{leader}</#{name}>\n")
      else
        io.write("/>\n")
      end
    end

    class << self

      def new(*args)
        element = super()
        args.each do |arg|
          case arg
          when nil
          when Hash
            arg.each do |key, value|
              next if value.nil?
              value = [value] unless value.is_a?(Array)
              class_name = key.to_s.sub(/\A./) { |s| s.upcase }
              element.add(KML.const_get(class_name).new(*value))
            end
          else
            element.add(arg)
          end
        end
        element
      end

    end

  end

  class CData

    def initialize(*texts)
      @text = texts.join
    end

    def to_s
      "<![CDATA[#{@text}]]>"
    end

  end

  class << self

    def simple(*args, &block)
      args.each do |arg|
        class_name = arg.to_s.sub(/\A./) { |s| s.upcase }
        class_eval("class #{class_name} < SimpleElement; NAME = \"#{arg}\"; end")
        const_get(class_name).instance_eval(&block) if block
      end
    end

    def complex(*args, &block)
      args.each do |arg|
        class_name = arg.to_s.sub(/\A./) { |s| s.upcase }
        class_eval("class #{class_name} < ComplexElement; NAME = \"#{arg}\"; end")
        const_get(class_name).instance_eval(&block) if block
      end
    end

  end

  simple :address
  simple :altitude
  simple :altitudeMode
  complex :BalloonStyle
  simple :color
  simple :colorMode
  simple :cookie

  simple :coordinates do

    class << self

      def new(*args)
        super(args.collect(&:to_kml_coord).join("\n"))
      end

      def arc(center, radius, start, stop, decimation = nil)
        decimation ||= (24.0 * radius / 400.0).to_i
        stop += 2 * Math::PI while stop < start
        from = (decimation * start / (2.0 * Math::PI)).to_i + 1
        to = (decimation * stop / (2.0 * Math::PI)).to_i
        coordinates = [center.destination_at(start, radius)]
        (from..to).each do |i|
          coordinates << center.destination_at(2 * Math::PI * i / decimation, radius)
        end 
        coordinates << center.destination_at(stop, radius)
        new(*coordinates)
      end

      def circle(center, radius, alt = nil, decimation = nil)
        decimation ||= (24.0 * radius / 400.0).to_i
        new(*(0..decimation).collect do |i|
          coord = center.destination_at(-2.0 * Math::PI * i / decimation, radius)
          coord.alt = alt if alt
          coord
        end)
      end

    end

  end

  simple :description
  complex :Document
  simple :drawOrder
  simple :east
  simple :extrude
  simple :fill
  complex :Folder
  simple :flyToView
  complex :GroundOverlay
  simple :h
  simple :heading
  simple :href

  complex :Icon do

    class << self

      def palette(index, x, y, w = 32, h = 32)
        new(:href => "root://icons/palette-#{index}.png", :x => x * w, :y => y * h, :w => w, :h => h)
      end

      def default
        palette(3, 7, 1)
      end

      def character(c)
        case c
        when ?1..?9
          index = c - ?1
          palette(3, index % 8, 7 - 2 * (index / 8))
        when ?A..?Z
          index = c - ?A
          palette(5, index % 8, 2 * (index / 8))
        else
          default
        end
      end

      def null
        palette(2, 7, 6)
      end

      def number(n)
        case n
        when 1..10 then palette(3, (n - 1) % 8, 7 - 2 * ((n - 1) / 8))
        else default
        end
      end

    end

  end

  complex :IconStyle
  complex :innerBoundaryIs
  simple :key
  complex :kml
  complex :LabelStyle
  simple :latitude
  complex :LatLonBox
  complex :LinearRing
  complex :LineString
  complex :LineStyle
  simple :linkDescription
  simple :linkName
  simple :longitude
  complex :LookAt
  simple :message
  simple :minRefreshPeriod
  complex :MultiGeometry
  simple :name
  complex :NetworkLink
  complex :NetworkLinkControl
  simple :north
  complex :ObjArrayField
  complex :ObjField
  simple :open
  complex :outerBoundaryIs
  simple :outline
  simple :overlayXY
  complex :Pair
  simple :complex
  complex :Placemark
  complex :Point
  complex :Polygon
  complex :PolyStyle
  simple :range
  simple :refreshInterval
  simple :refreshMode
  simple :refreshVisibility
  simple :rotation
  simple :scale
  complex :Schema
  complex :ScreenOverlay
  simple :screenXY
  complex :SimpleArrayField
  complex :SimpleField
  simple :size
  simple :south
  simple :Snippet

  complex :Style do |klass|

    class << self

      def new(*args)
        element = super(*args)
        element.add_attributes(:id => element.kml_id)
        element
      end

    end

  end

  complex :StyleMap
  simple :styleUrl
  simple :tessellate
  complex :Text
  simple :tilt
  simple :type
  complex :Url
  simple :viewBoundScale
  simple :viewRefreshMode
  simple :viewRefreshTime
  simple :visibility
  simple :w
  simple :west
  simple :width
  simple :x
  simple :y

  if VERSION < [2, 1]
    simple :ViewFormat
  end
  if VERSION >= [2, 1]
    complex :AddressDetails
    complex :Change
    simple :code
    complex :Create
    complex :Delete
    simple :expires
    complex :LatLonAltBox
    complex :Link
    simple :listItemType
    complex :ListStyle
    complex :Location
    complex :Lod
    simple :maxAltitude
    simple :maxFadeExtent
    simple :maxLodPixels
    simple :minAltitude
    simple :minFadeExtent
    simple :minLodPixels
    complex :Model
    complex :Orientation
    complex :Region
    simple :request
    complex :Response
    complex :Roll
    complex :Status
    simple :targetHref
    complex :Update
    simple :viewFormat
  end

end
