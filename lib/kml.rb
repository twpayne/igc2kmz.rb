require "coord"
require "stringio"

class Coord

  def to_kml_coord
    "%.6f,%.6f,%d" % [Radians.to_deg(lon), Radians.to_deg(lat), alt]
  end

end

class Time

  def to_kml
    getutc.strftime("%Y-%m-%dT%H:%M:%SZ")
  end

end

class KML

  VERSION = [2, 1].extend(Comparable)

  def initialize(*args)
    @kml = KML::Kml.new
    @kml.add_attributes(:xmlns => "http://earth.google.com/kml/#{VERSION.join(".")}")
    args.each(&@kml.method(:add))
  end

  def fast_write(io)
    io.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
    @kml.write(io)
  end

  def pretty_write(io, indent = "\t")
    io.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
    @kml.pretty_write(io, indent, "")
  end

  def write(io, indent = nil)
    indent ? pretty_write(io, indent) : fast_write(io)
  end

  def to_s
    stringio = StringIO.new
    pretty_write(stringio)
    stringio.string
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
      name = self.class.const_get(:NAME)
      io.write("<#{name}")
      @attributes.each do |attribute, value|
        io.write(" #{attribute}=\"#{value}\"")
      end
      io.write(@text && !@text.empty? ? ">#{@text}</#{name}>" : "/>")
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
      name = self.class.const_get(:NAME)
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
      name = self.class.const_get(:NAME)
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
              class_name = key.to_s.sub(/\A./) { |s| s.upcase }.to_sym
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
        class_name = arg.to_s.sub(/\A./) { |s| s.upcase }.to_sym
        class_eval("class #{class_name} < SimpleElement; NAME = \"#{arg}\"; end")
        const_get(class_name).instance_eval(&block) if block
        method_name = arg.to_s.sub(/\A[A-Z]/) { |s| s.downcase }.gsub(/[A-Z]/) { |s| "_#{s.downcase}" }
        ComplexElement.class_eval(<<-EOC)
          def #{method_name}=(value)
            add(#{class_name}.new(value))
            value
          end
        EOC
      end
    end

    def complex(*args, &block)
      args.each do |arg|
        class_name = arg.to_s.sub(/\A./) { |s| s.upcase }.to_sym
        class_eval("class #{class_name} < ComplexElement; NAME = \"#{arg}\"; end")
        const_get(class_name).instance_eval(&block) if block
      end
    end

  end

  simple :address
  complex :AddressDetails
  simple :altitude
  simple :altitudeMode
  complex :BalloonStyle
  simple :begin
  simple :bgColor
  complex :Change
  simple :code
  simple :color
  simple :colorMode
  simple :cookie

  simple :coordinates do

    class << self

      def new(*args)
        super(args.collect(&:to_kml_coord).join("\n"))
      end

      def arc(center, radius, start, stop, error = 0.1)
        decimation = (Math::PI / Math.acos((radius - error) / (radius + error))).ceil
        stop += 2 * Math::PI while stop < start
        from = (decimation * start / (2.0 * Math::PI)).to_i + 1
        to = (decimation * stop / (2.0 * Math::PI)).to_i
        coords = [center.destination_at(start, radius + error)]
        (from..to).each do |i|
          coords << center.destination_at(2 * Math::PI * i / decimation, radius + error)
        end 
        coords << center.destination_at(stop, radius + error)
        new(*coords)
      end

      def circle(center, radius, alt = nil, error = 0.1)
        decimation = (Math::PI / Math.acos((radius - error) / (radius + error))).ceil
        new(*(0..decimation).collect do |i|
          coord = center.destination_at(-2.0 * Math::PI * i / decimation, radius + error)
          coord.alt = alt if alt
          coord
        end)
      end

    end

  end

  complex :Create
  complex :Delete
  simple :description
  complex :Document
  simple :drawOrder
  simple :east
  simple :end
  simple :expires
  simple :extrude
  simple :fill
  simple :flyToView
  complex :Folder
  complex :GroundOverlay
  simple :h
  simple :heading
  simple :hotSpot
  simple :href
  simple :httpQuery

  complex :Icon do

    class << self

      def palette(pal, icon, extra = nil)
        new(:href => "http://maps.google.com/mapfiles/kml/pal#{pal}/icon#{icon}#{extra}.png")
      end

      def default
        palette(3, 55)
      end

      def character(c, extra = nil)
        case c
        when ?1..?9 then palette(3, (c - ?1) % 8 + 16 * ((c - ?1) / 8), extra)
        when ?A..?Z then palette(5, (c - ?A) % 8 + 16 * ((31 - c + ?A) / 8), extra)
        else default
        end
      end

      def null
        palette(2, 15)
      end

      def number(n, extra = nil)
        case n
        when 1..10 then palette(3, (n - 1) % 8 + 16 * ((n - 1) / 8), extra)
        else default
        end
      end

    end

  end

  complex :IconStyle
  complex :innerBoundaryIs
  complex :ItemIcon
  simple :key
  complex :kml
  complex :LabelStyle
  simple :latitude
  complex :LatLonAltBox
  complex :LatLonBox
  complex :LinearRing
  complex :LineString
  complex :LineStyle
  complex :Link
  simple :linkDescription
  simple :linkName
  simple :listItemType
  complex :ListStyle
  complex :Location
  complex :Lod
  simple :longitude
  complex :LookAt
  simple :maxAltitude
  simple :maxFadeExtent
  simple :maxLodPixels
  simple :message
  complex :Metadata
  simple :minAltitude
  simple :minFadeExtent
  simple :minLodPixels
  simple :minRefreshPeriod
  complex :Model
  complex :MultiGeometry
  simple :name
  complex :NetworkLink
  complex :NetworkLinkControl
  simple :north
  complex :ObjArrayField
  complex :ObjField
  simple :open
  complex :Orientation
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
  complex :Region
  simple :request
  complex :Response
  complex :Roll
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
  complex :Status

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
  simple :targetHref
  simple :tessellate
  simple :text
  simple :tilt
  complex :TimeSpan
  complex :TimeStamp
  simple :type
  complex :Update
  complex :Url
  simple :viewBoundScale
  simple :viewFormat
  simple :viewRefreshMode
  simple :viewRefreshTime
  simple :visibility
  simple :w
  simple :west
  simple :when
  simple :width
  simple :x
  simple :y

end
