require "rexml/document"

class GPX < REXML::Document

  ROOT_ATTRIBUTES = {
    "creator" => "http://www.maximumxc.com/",
    "version" => "1.1",
    "xmlns" => "http://www.topografix.com/GPX/1/1",
    "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
    "xsi:schemaLocation" => "http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd",
  }

  def initialize(*args)
    super()
    add(REXML::XMLDecl.new)
    gpx = GPX.new(ROOT_ATTRIBUTES)
    args.each(&gpx.method(:add))
    add(gpx)
  end

  class Element < REXML::Element

    def initialize(name, *args)
      super(name)
      args.each do |arg|
        case arg
        when Hash           then add_attributes(arg)
        when REXML::Element then add(arg)
        else add_text(arg.to_s)
        end
      end
    end

  end

  class << self

    def element(*args)
      args.each do |arg|
        class_eval <<-EOC
          class #{arg} < Element
            def initialize(*args)
              super("#{arg.to_s.downcase}", *args)
            end
          end
        EOC
      end
    end

  end

  element :AgeOfGPSData
  element :Author
  element :Bounds
  element :Copyright
  element :Cmt
  element :Desc
  element :DGPSId
  element :Ele
  element :Email
  element :Extensions
  element :Fix
  element :GeoidHeight
  element :GPX
  element :HDOP
  element :Keywords
  element :License
  element :Link
  element :MagVar
  element :Metadata
  element :Name
  element :Number
  element :PDOP
  element :Person
  element :Pt
  element :PtSeg
  element :Rte
  element :RtePt
  element :Sat
  element :Sym
  element :Text
  element :Time
  element :Trk
  element :TrkPt
  element :TrkSeg
  element :Type
  element :VDOP
  element :Year
  element :Wpt

end

class Time

  def to_gpx
    getutc.strftime("%Y-%m-%dT%H:%M:%SZ")
  end

  class << self

    def new_from_gpx(text)
      md = /\A(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+)Z\z/.match(text)
      md or raise ArgumentError, text
      Time.utc(*md[1..6].collect(&:to_i))
    end

  end

end
