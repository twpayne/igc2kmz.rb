require "RMagick"

module Gradient

  class Grayscale

    class << self

      def [](delta)
        value = delta * Magick::MaxRGB
        Magick::Pixel.new(value, value, value)
      end

    end

  end

  class Default

    class << self

      def [](delta)
        hue = 2.0 * (1.0 - delta.constrain(0.0, 1.0)) / 3.0
        Magick::Pixel.from_HSL([hue, 1.0, 0.5])
      end

    end

  end

end

module Magick

  class Image

    def outline(&block)
      mask = black_threshold(Magick::MaxRGB + 1)
      image = Image.new(columns, rows, &block)
      (-1..1).each do |i|
        (-1..1).each do |j|
          image.composite!(mask, i, j, Magick::MultiplyCompositeOp)
        end
      end
      image.composite!(self, 0, 0, Magick::OverCompositeOp)
      image
    end

  end

end
