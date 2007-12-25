require "bounds"
require "lib"
require "uri"

# FIXME chbh

module Google

  class Chart

    attr_accessor :type
    attr_accessor :width
    attr_accessor :height
    attr_reader :encoding
    attr_accessor :datas
    attr_accessor :colors
    attr_accessor :fills
    attr_accessor :title
    attr_accessor :title_color
    attr_accessor :title_fontsize
    attr_accessor :legend
    attr_accessor :labels
    attr_accessor :axes
    attr_accessor :grid
    attr_accessor :markers
    attr_accessor :line_styles

    class Error < RuntimeError
    end

    class Axis

      attr_reader :axis
      attr_accessor :labels
      attr_accessor :positions
      attr_accessor :range
      attr_accessor :color
      attr_accessor :fontsize
      attr_accessor :alignment

      def initialize(axis, options = {})
        @axis = axis
        options.each do |key, value|
          case key
          when :alignment then @alignment = value
          when :color     then @color = value
          when :fontsize  then @fontsize = value
          when :labels    then add_labels(value)
          when :positions then add_positions(value)
          when :range     then @range = value
          else raise
          end
        end
      end

      def add_labels(labels)
        @labels ||= []
        @positions ||= []
        case labels
        when Hash
          labels.keys.sort.each do |key|
            @positions << key
            @labels << labels[key]
          end
        when Array
          @labels.concat(labels)
        else
          raise
        end
        self
      end

      def add_positions(positions)
        (@positions ||= []).concat(positions)
        self
      end

      def style
        [@color, @fontsize, @alignment].strip_trailing_nils
      end

    end

    class Encoding

      class Simple < self
        
        ENCODING = ["A".."Z", "a".."z", "0".."9"].collect(&:to_a).collect(&:join).join

        def encode(datas)
          "s:" + datas.collect do |data|
            data.collect do |datum|
              raise Error, "datum out of range (#{datum.inspect})" if datum and !(0..61).include?(datum)
              datum ? ENCODING[datum] : ?_
            end.pack("C*")
          end.join(",")
        end

        def rescale(data, bounds = nil)
          bounds ||= data.bounds
          data.collect do |datum|
            datum ? (61 * (datum - bounds.first) / (bounds.last - bounds.first)).round : nil
          end
        end

      end

      class Text < self

        def initialize(precision = 1)
          @format = precision ? "%.#{precision}f" : "%f"
        end

        def encode(datas)
          "t:" + datas.collect do |data|
            data.collect do |datum|
              raise Error, "datum out of range (#{datum.inspect})" if datum and !((0.0)..(100.0)).include?(datum)
              #datum ? (@format % datum).sub(/0+\z/, "").sub(/\.\z/, "") : "-1"
              datum ? (@format % datum) : "-1"
            end.join(",")
          end.join("|")
        end

        def rescale(data, bounds = nil)
          bounds ||= data.bounds
          data.collect do |datum|
            datum ? 100.0 * (datum - bounds.first) / (bounds.last - bounds.first) : nil
          end
        end

      end

      class Extended < self

        characters = ["A".."Z", "a".."z", "0".."9", "-".."-", ".".."."].collect(&:to_a).collect(&:join).join
        ENCODING = (0..4095).collect do |i|
          [characters[i / 64], characters[i % 64]].pack("CC")
        end

        def encode(datas)
          "e:" + datas.collect do |data|
            data.collect do |datum|
              raise Error, "datum out of range (#{datum.inspect})" if datum and !(0..4095).include?(datum)
              datum ? ENCODING[datum] : "__"
            end.join
          end.join(",")
        end

        def rescale(data, bounds = nil)
          bounds ||= data.bounds
          data.collect do |datum|
            datum ? (4095 * (datum - bounds.first) / (bounds.last - bounds.first)).round : nil
          end
        end

      end

    end

    class Fill

      class Solid < self

        def initialize(bgc, color)
          @bgc = bgc
          @color = color
        end

        def to_s
          [@bgc, "s", @color].join(",")
        end

      end

      class LinearGradient < self

        def initialize(bgc, angle, pairs)
          @bgc = bgc
          @angle = angle
          if pairs.is_a?(Range)
            @pairs = {0 => pairs.first, 1 => pairs.last}
          else
            @pairs = pairs
          end
        end

        def to_s
          pairs = @pairs.keys.sort.collect do |key|
            [@pairs[key], key].join(",")
          end
          [@bgc, "lg", @angle, pairs].join(",")
        end

      end

      class LinearStripes < self

        def initialize(bgc, angle, pairs)
          @bgc = bgc
          @angle = angle
          @pairs = pairs
        end

        def to_s
          [@bgc, "ls", @angle, @pairs.join(",")].join(",")
        end

      end

    end

    class Grid

      def initialize(xstep, ystep, line = nil, blank = nil)
        @xstep, @ystep, @line, @blank = xstep, ystep, line, blank
      end

      def to_s
        [@xstep, @ystep, @line, @blank].strip_trailing_nils.join(",")
      end

    end

    class Marker 

      class Fill < self

        def initialize(bB, color, first, last)
          @bB, @color, @first, @last = bB, color, first, last
        end

        def to_s
          [@bB, @color, @first, @last, 0].join(",")
        end

      end

      class Range < self

        def initialize(rR, color, first, last)
          @rR, @color, @first, @last = rR, color, first, last
        end

        def to_s
          [@rR, @color, 0, @first, @last].join(",")
        end

      end

      class Shape < self

        def initialize(type, color, index, point, size)
          @type, @color, @index, @point, @size = type, color, index, point, size
        end

        def to_s
          [@type, @color, @index, @point, @size].join(",")
        end

      end

    end
    
    class LineStyle

      def initialize(thickness, line, blank)
        @thickness, @line, @blank = thickness, line, blank
      end

      def to_s
        [@thickness, @line, @blank].join(",")
      end

    end

    def initialize(type, width, height, encoding = Encoding::Simple.new)
      @type, @width, @height, @encoding = type, width, height, encoding
      yield(self) if block_given?
    end

    def add_axis(axis)
      (@axes ||= []) << axis
      self
    end

    def add_data(data)
      (@datas ||= []) << data
      self
    end

    def add_fill(fill)
      (@fills ||= []) << fill
      self
    end

    def add_line_style(line_style)
      (@line_styles ||= []) << line_style
      self
    end

    def add_marker(marker)
      (@markers ||= []) << marker
      self
    end

    def add(object)
      case object
      when Array     then add_data(object)
      when Axis      then add_axis(object)
      when Fill      then add_fill(object)
      when LineStyle then add_line_style(object)
      when Marker    then add_marker(object)
      else raise ArgumentError, object.inspect
      end
    end

    alias :<< :add

    def rescale_and_add_data(data)
      @datas << @encoding.rescale(data)
      self
    end

    def pairs
      result = []
      result << ["cht", @type]
      result << ["chs", "#{@width}x#{@height}"]
      result << ["chd", @encoding.encode(@datas)] if @datas and !@datas.empty?
      result << ["chco", @colors.join(",")] if @colors
      result << ["chf", @fills.join("|")] if @fills and !@fills.empty?
      result << ["chtt", self.class.encode_string(@title)] if @title
      result << ["chts", [@title_color, @title_fontsize].join(",")] if @title_color and @title_fontsize
      result << ["chdl", @legend.join("|")] if @legend and !@legend.empty?
      result << ["chl", @labels.join("|")] if @labels and !@labels.empty?
      if @axes and !@axes.empty?
        labels, positions, ranges, styles = [], [], [], []
        @axes.each_with_index do |axis, index|
          labels << ["#{index}:"].concat(axis.labels).join("|") if axis.labels and !axis.labels.empty?
          positions << [index].concat(axis.positions).join(",") if axis.positions and !axis.positions.empty?
          ranges << [index, axis.range.first, axis.range.last].join(",") if axis.range
          style = axis.style
          styles << [index].concat(style).join(",") unless style.empty?
        end
        result << ["chxt", @axes.collect(&:axis).join(",")]
        result << ["chxl", labels.join("|")] unless labels.empty?
        result << ["chxp", positions.join("|")] unless positions.empty?
        result << ["chxr", ranges.join("|")] unless ranges.empty?
        result << ["chxs", styles.join("|")] unless styles.empty?
      end
      result << ["chls", @line_styles.join("|")] if @line_styles and !@line_styles.empty?
      result << ["chg", @grid.to_s] if @grid
      result << ["chm", @markers.join("|")] if @markers and !@markers.empty?
      result
    end

    def to_url
      "http://chart.apis.google.com/chart?" + pairs.collect { |pair| pair.join("=") }.join("&")
    end

    alias :to_s :to_url

    class << self

      def encode_string(s)
        s.gsub(/ /, "+").gsub(/\n/, "|")
      end

    end

  end

end
