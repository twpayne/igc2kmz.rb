require "kml"
require "RMagick"

class KML

  class Color

    class << self

      def color(color)
        begin
          pixel(Magick::Pixel.from_color(color))
        rescue ArgumentError
          new("ffffffff")
        end
      end

      def pixel(pixel)
        channels = [:opacity, :blue, :green, :red].collect do |channel|
          (256 * pixel.send(channel).to_f / Magick::MaxRGB).round.constrain(0, 255)
        end
        channels[0] = 255 - channels[0]
        new("%02x%02x%02x%02x" % channels)
      end

    end

  end

end
