require "RMagick"
require "html"
require "igc"
require "igc/analysis"
require "kmz"
require "task"
require "optima"
require "optima/kmz"
require "ostruct"
require "photo/kmz"
require "sponsor/kmz"
require "task/kmz"
require "units"
require "rvg/rvg"

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

class Scale

  class Border

    attr_reader :top
    attr_reader :right
    attr_reader :bottom
    attr_reader :left

    def initialize(*widths)
      case widths.length
      when 0
        @top = @right = @bottom = @left = 0
      when 1
        @top = @right = @bottom = @left = widths[0]
      when 2
        @top = @bottom = widths[0]
        @right = @left = widths[1]
      when 3
        @top    = widths[0]
        @right  = widths[1]
        @left   = widths[1]
        @bottom = widths[2]
      when 4
        @top    = widths[0]
        @right  = widths[1]
        @bottom = widths[2]
        @left   = widths[3]
      else
        raise ArgumentError
      end
    end

    def height
      @top + @bottom
    end

    def width
      @right + @left
    end

  end

  attr_reader :title

  def initialize(title, range, unit, gradient = Gradient::Default)
    @title = title
    @range = range
    @unit = unit
    @gradient = gradient
  end

  def color_of(value)
    pixel_of(value).to_color(Magick::SVGCompliance)
  end

  def pixel_of(value)
    @gradient[normalize(value)]
  end

  def pixels(steps = 32)
    (0...steps).collect do |i|
      @gradient[i.to_f / (steps - 1)]
    end
  end

  def normalize(value)
    ((value - @range.first) / (@range.last - @range.first)).constrain(0.0, 1.0)
  end

  def discretize(value, steps = 32)
    (steps * (value - @range.first) / (@range.last - @range.first)).round.constrain(0, steps - 1)
  end

  def make_step(n, steps = [[0.5, 5], [1.0, 5]])
    width = @unit.multiplier.to_f * (@range.last - @range.first) / n
    i = steps.length * (Math.log10(width).floor - 1)
    step = steps[i % steps.length][0] * 10.0 ** (i / steps.length)
    while width / step > 1.0
      i += 1
      step = steps[i % steps.length][0] * 10.0 ** (i / steps.length)
    end
    i0 = i - 1
    step0 = steps[i0 % steps.length][0] * 10 ** (i0 / steps.length)
    if [step / width, 1.25].min < width / step0
      [step / @unit.multiplier, steps[i % steps.length][1]]
    else
      [step0 / @unit.multiplier, steps[i0 % steps.length][1]]
    end
  end

  def make_scale_step(n)
    width = @unit.multiplier * (@range.last - @range.first)
    steps = [0.25, 0.5, 1.0]
    i = steps.length * (Math.log10(width).to_i - 1)
    step = steps[i % steps.length] * 10 ** (i / steps.length)
    while width / step > n
      i += 1
      step = steps[i % steps.length] * 10 ** (i / steps.length)
    end
    step0 = steps[(i - 1) % steps.length] * 10 ** ((i - 1) / steps.length)
    (n * step / width < width / (n * step0) ? step : step0) / @unit.multiplier
  end

  def make_time_step(width, n)
    steps = [[1, 1], [15, 3], [30, 3], [60, 4], [5 * 60, 5], [15 * 60, 3], [30 * 60, 3], [60 * 60, 4], [3 * 60 * 60, 3], [6 * 60 * 60, 6], [12 * 60 * 60, 4]]
    i = 0
    i += 1 while i < steps.length and width / steps[i][0] > n
    return steps[0] if i.zero?
    return steps[-1] if i == steps.length
    n * steps[i][0] / width < width / (n * steps[i - 1][0]) ? steps[i] : steps[i - 1]
  end

  def to_image
    border = Border.new(8)
    width, height = 64, 256
    Magick::RVG.new(width + border.width, height + border.height) do |canvas|
      canvas.g.translate(border.left, border.top) do |scale|
        scale.styles(:font_family => "Verdana", :font_size => 9, :font_weight => "bold", :stroke => "none")
        step = make_scale_step(7)
        unit = step < 1.0 ? @unit : @unit.integer_unit
        i = (@range.first / step).ceil
        value = step * i
        while value < @range.last
          y = (height * (1.0 - (value - @range.first) / (@range.last - @range.first))).round
          color = color_of(value)
          scale.line(0, y, 8, y).styles(:stroke => color)
          scale.text(12, y, unit[value]).d(0, 4).styles(:fill => color)
          i += 1
          value = step * i
        end
        (0...height).each do |y|
          value = @range.last - (y + 0.5) * (@range.last - @range.first) / height
          color = color_of(value)
          scale.line(0, y, 4, y).styles(:stroke => color)
        end
      end
    end.draw.outline do
      self.background_color = "transparent"
    end
  end

  def to_graph_image(hints, times, values)
    border = Border.new(16, 4, 16, 36)
    width, height = 640 - border.width, 240 - border.height
    tstep, tdivisions = make_time_step(times[-1] - times[0], 6)
    time_format = tstep < 60 ? "%H:%M:%S" : "%H:%M"
    xticks = (((tdivisions * times[0] + tstep - 1) / tstep)..(tdivisions * times[-1] / tstep)).collect do |i|
      t = tstep * i / tdivisions
      label = (i % tdivisions).zero? ? (Time.at(t).utc + hints.tz_offset).strftime(time_format) : nil
      [(width.to_f * (t - times[0]) / (times[-1] - times[0])).round, label]
    end
    vstep, vdivisions = make_step(6)
    vunit = vstep < 1.0 ? @unit : @unit.integer_unit
    vmin = vstep * (vdivisions * @range.first / vstep).floor / vdivisions
    vmax = vstep * (vdivisions * @range.last / vstep).ceil / vdivisions
    yticks = ((vdivisions * @range.first / vstep).floor..(vdivisions * @range.last / vstep).ceil).collect do |i|
      v = vstep * i / vdivisions
      label = (i % vdivisions).zero? ? vunit.convert(v) : nil
      [(height.to_f * (v - vmin) / (vmax - vmin)).round, label]
    end
    graph_image = Magick::RVG.new(width + border.width, height + border.height) do |canvas|
      canvas.g.translate(border.left, border.top + height).scale(1, -1) do |graph|
        graph.styles(:stroke => "black")
        graph.rect(width, height).styles(:fill => "white", :stroke => "none")
        graph.g.styles(:stroke => "#ddd") do |minor_grid|
          xticks.each { |x, label| minor_grid.line(x, 0, x, height) unless label }
          yticks.each { |y, label| minor_grid.line(0, y, width, y) unless label }
        end
        graph.g.styles(:stroke => "#bbb") do |major_grid|
          xticks.each { |x, label| major_grid.line(x, 0, x, height) if label }
          yticks.each { |y, label| major_grid.line(0, y, width, y) if label }
        end
        xticks.each { |x, label| graph.line(x, 0, x, label ? -4 : -2) }
        yticks.each { |y, label| graph.line(0, y, label ? -4 : -2, y) }
        graph.rect(width, height).styles(:fill => "none")
        xs = times.collect { |t| width.to_f * (t - times[0]) / (times[-1] - times[0]) }
        ys = values.collect { |v| height.to_f * (v - vmin) / (vmax - vmin) }
        graph.polyline(xs, ys).styles(:fill => "none")
      end
    end.draw
    Magick::RVG.new(width + border.width, height + border.height) do |canvas|
      canvas.g.translate(border.left, border.top + height) do |labels|
        labels.styles(:fill => "white", :font_family => "Verdana", :font_weight => "bold", :stroke => "none")
        labels.g.styles(:font_size => 9) do |axes|
          axes.g.styles(:text_anchor => "middle") do |xaxis|
            xticks.each { |x, label| xaxis.text(x, 4, label).d(0, 9) if label }
          end
          axes.g.styles(:text_anchor => "end") do |yaxis|
            yticks.each { |y, label| yaxis.text(-4, -y, label).d(0, 4) if label }
          end
        end
        title = "#{@title.capitalize} (#{@unit.unit})"
        labels.text(0, -height - 4, title).styles(:font_size => 11, :text_anchor => "start")
      end
    end.draw.outline do
      self.background_color = "transparent"
    end.composite!(graph_image, 0, 0, Magick::OverCompositeOp)
  end

end

class ZeroCenteredScale < Scale

  def normalize(value)
    case value <=> 0.0
    when -1 then 0.5 - 0.5 * value / @range.first
    when  0 then 0.5
    when  1 then 0.5 + 0.5 * value / @range.last
    end.constrain(0.0, 1.0)
  end

end

class IGC

  ICON_SCALE = 0.5
  LABEL_SCALES = [1.0, Math.sqrt(0.8), Math.sqrt(0.6), Math.sqrt(0.4)]

  class Fix

    def to_kml(hints, name, point_options, *children)
      point = KML::Point.new(KML::Coordinates.new(self), point_options)
      case name
      when :alt  then name = hints.units[:altitude][@alt]
      when :time then name = @time.to_time(hints)
      end
      name = KML::Name.new(name) if name.is_a?(String)
      statistics = []
      statistics << ["Altitude", hints.units[:altitude][@alt]]
      statistics << ["Time", @time.to_time(hints)]
      description = KML::Description.new(KML::CData.new(statistics.to_html_table))
      KML::Placemark.new(point, name, description, KML::Snippet.new, *children)
    end

  end

  class << self

    def make_empty_folder(stock, options = {})
      icon = KML::Icon.new(:href => stock.pixel_url)
      overlay_xy = KML::OverlayXY.new(:x => 0, :y => 1, :xunits => :fraction, :yunits => :fraction)
      screen_xy = KML::ScreenXY.new(:x => 0, :y => 1, :xunits => :fraction, :yunits => :fraction)
      size = KML::Size.new(:x => 0, :y => 0, :xunits => :fraction, :yunits => :fraction)
      screen_overlay = KML::ScreenOverlay.new(icon, overlay_xy, screen_xy, size, :visibility => options[:visibility])
      KMZ.new(KML::Folder.new(screen_overlay, KML::StyleUrl.new(stock.check_hide_children_style.url), options))
    end

    def stock
      stock = OpenStruct.new
      stock.kmz = KMZ.new
      # folder styles
      list_style = KML::ListStyle.new(:listItemType => :radioFolder)
      stock.radio_folder_style = KML::Style.new(list_style)
      stock.kmz.merge_roots(stock.radio_folder_style)
      list_style = KML::ListStyle.new(:listItemType => :checkHideChildren)
      stock.check_hide_children_style = KML::Style.new(list_style)
      stock.kmz.merge_roots(stock.check_hide_children_style)
      # pixel
      pixel = Magick::Image.new(1, 1) do |image|
        image.background_color = "transparent"
        image.format = "png"
      end
      pixel.set_channel_depth(Magick::AllChannels, 1)
      stock.pixel_url = "images/pixel.#{pixel.format.downcase}"
      stock.kmz.merge_files(stock.pixel_url => pixel.to_blob)
      # optima
      color = KML::Color.color("magenta")
      icon_style = KML::IconStyle.new(KML::Icon.palette(4, 24), :scale => IGC::ICON_SCALE)
      label_style = KML::LabelStyle.new(color)
      line_style = KML::LineStyle.new(color, :width => 2)
      stock.optima_style = KML::Style.new(icon_style, label_style, line_style)
      stock.kmz.merge_roots(stock.optima_style)
      # task
      color = KML::Color.color("yellow")
      icon_style = KML::IconStyle.new(KML::Icon.palette(4, 24), :scale => IGC::ICON_SCALE)
      label_style = KML::LabelStyle.new(color)
      line_style = KML::LineStyle.new(color)
      stock.task_style = KML::Style.new(icon_style, label_style, line_style)
      stock.kmz.merge_roots(stock.task_style)
      # none folders
      stock.visible_none_folder = make_empty_folder(stock, :name => "None", :visibility => 1)
      stock.invisible_none_folder = make_empty_folder(stock, :name => "None", :visibility => 0)
      stock
    end

    def default_hints
      hints = OpenStruct.new
      hints.color = KML::Color.color("red")
      hints.complexity = 4
      hints.photo_tz_offset = 0
      hints.photos = []
      hints.stock = stock
      hints.units = Units::GROUPS[:metric]
      hints.width = 2
      hints
    end

  end

  def make_description(hints)
    rows = []
    rows << ["Pilot", hints.pilot || @header[:pilot]] if hints.pilot or @header[:pilot]
    rows << ["Date", @fixes[0].time.to_time(hints, "%Y-%m-%d")]
    rows << ["Site", @header[:site]] if @header[:site]
    rows << ["Glider", @header[:glider_type]] if @header[:glider_type]
    if hints.task
      task = hints.task
      rows << ["Competition","%s task %d" % [task.competition, task.number]]
      rows << ["Task", "%s %s" % [hints.units[:distance][task.distance], Task::TYPES[task.type]]]
    end
    if hints.optima
      optimum = hints.optima.optima.sort_by(&:score)[-1]
      rows << ["Cross country league", Optima::LEAGUES[hints.optima.league]] if hints.optima.league
      rows << ["Cross country type", optimum.flight_type]
      rows << ["Cross country distance", "%s (%.1f points)" % [hints.units[:distance][optimum.distance], optimum.score]]
      rows << ["Time on task", (optimum.fixes[-1].time - optimum.fixes[0].time).to_duration]
      rows << ["Average speed", hints.units[:speed][optimum.distance / (optimum.fixes[-1].time - optimum.fixes[0].time)]]
    end
    rows << ["Take off time", @fixes[0].time.to_time(hints)]
    rows << ["Landing time", @fixes[-1].time.to_time(hints)]
    rows << ["Duration", (@fixes[-1].time - @fixes[0].time).to_duration]
    rows << ["Take off altitude", hints.units[:altitude][@fixes[0].alt]]
    rows << ["Maximum altitude", hints.units[:altitude][@bounds.alt.last]]
    rows << ["Maximum altitude above take off", hints.units[:altitude][@bounds.alt.last - @fixes[0].alt]]
    rows << ["Minimum altitude", hints.units[:altitude][@bounds.alt.first]]
    max_alt_gain = 0
    min_alt = max_alt = @fixes[0].alt
    @fixes.each do |fix|
      if fix.alt < min_alt
        min_alt = fix.alt
      elsif fix.alt > max_alt
        max_alt = fix.alt
        alt_gain = max_alt - min_alt
        max_alt_gain = alt_gain if alt_gain > max_alt_gain
      end
    end
    rows << ["Maximum altitude gain", hints.units[:altitude][max_alt_gain]]
    sum_alt_gain = 0
    @fixes.each_cons(2) do |fix0, fix1|
      change = fix1.alt - fix0.alt
      sum_alt_gain += change if change > 0
    end
    rows << ["Accumulated altitude gain", hints.units[:altitude][sum_alt_gain]]
    rows << ["Maximum climb", hints.units[:climb][@bounds.climb.last]]
    rows << ["Maximum sink", hints.units[:climb][@bounds.climb.first]]
    rows << ["Created by", "<a href=\"http://maximumxc.com/\">maximumxc.com</a>"]
    KML::Description.new(KML::CData.new(rows.to_html_table))
  end

  def to_kmz(hints = nil)
    hints = hints ? hints.clone : self.class.default_hints
    hints.tz_offset = 3600 * (@header[:timezone_offset] || 0) unless hints.tz_offset
    analyse
    if hints.bounds
      hints.bounds.merge(@bounds)
    else
      hints.bounds = @bounds
    end
    hints.igc = self
    hints.optima = Optima.new_from_igc(self, hints.league, hints.complexity) unless hints.task
    hints.scales = OpenStruct.new
    hints.scales.altitude = Scale.new("altitude", hints.bounds.alt, hints.units[:altitude])
    hints.scales.climb = ZeroCenteredScale.new("climb", hints.bounds.climb, hints.units[:climb])
    hints.scales.speed = Scale.new("speed", hints.bounds.speed, hints.units[:speed])
    fields = []
    fields << (hints.pilot || @header[:pilot]) if hints.pilot or @header[:pilot]
    fields << @fixes[0].time.to_time(hints, "%Y-%m-%d")
    fields << "#{hints.task.competition} task #{hints.task.number}" if hints.task
    fields << @header[:site] if @header[:site]
    snippet = KML::Snippet.new(fields.join(", "))
    kmz = KMZ.new(make_description(hints), snippet, KML::Name.new(@filename), KML::Open.new(1))
    kmz.merge_sibling(hints.stock.kmz)
    kmz.merge_sibling(track_log_folder(hints))
    kmz.merge_sibling(shadow_folder(hints))
    kmz.merge_sibling(photos_folder(hints)) if hints.photos
    kmz.merge_sibling(optima_folder(hints)) if hints.optima
    kmz.merge_sibling(competition_folder(hints)) if hints.task
    kmz.merge_sibling(altitude_marks_folder(hints))
    kmz.merge_sibling(thermals_and_glides_folder(hints))
    kmz.merge_sibling(time_marks_folder(hints))
    kmz.merge_sibling(graphs_folder(hints))
    kmz.merge_sibling(hints.sponsor.to_kmz(hints)) if hints.sponsor
    kmz
  end

  def make_monochromatic_track_log(hints, color, width, altitude_mode, folder_options = {})
    style = KML::Style.new(KML::LineStyle.new(color, :width => width))
    line_string = KML::LineString.new(:coordinates => @fixes, :altitudeMode => altitude_mode)
    placemark = KML::Placemark.new(style, line_string)
    KMZ.new(KML::Folder.new(placemark, KML::StyleUrl.new(hints.stock.check_hide_children_style.url), folder_options))
  end

  def make_colored_track_log(hints, values, scale, folder_options = {})
    name = KML::Name.new("Coloured by #{scale.title}")
    folder = KML::Folder.new(name, KML::StyleUrl.new(hints.stock.check_hide_children_style.url), folder_options)
    styles = scale.pixels.collect do |pixel|
      KML::Style.new(KML::LineStyle.new(KML::Color.pixel(pixel), :width => hints.width))
    end
    discrete_values = values.collect(&scale.method(:discretize))
    discrete_values.segment(false).each do |range|
      line_string = KML::LineString.new(:coordinates => @fixes[range], :altitudeMode => :absolute)
      style_url = KML::StyleUrl.new(styles[discrete_values[range.first]].url)
      placemark = KML::Placemark.new(style_url, line_string)
      folder.add(placemark)
    end
    image = scale.to_image
    image.set_channel_depth(Magick::AllChannels, 8)
    image.format = "png"
    href = "images/scales/#{scale.title}.#{image.format.downcase}"
    icon = KML::Icon.new(:href => href)
    overlay_xy = KML::OverlayXY.new(:x => 0, :y => 1, :xunits => :fraction, :yunits => :fraction)
    screen_xy = KML::ScreenXY.new(:x => 0, :y => 1, :xunits => :fraction, :yunits => :fraction)
    size = KML::Size.new(:x => 0, :y => 0, :xunits => :fraction, :yunits => :fraction)
    screen_overlay = KML::ScreenOverlay.new(icon, overlay_xy, screen_xy, size)
    folder.add(screen_overlay)
    KMZ.new(folder, :roots => styles, :files => {href => image.to_blob})
  end

  def track_log_folder(hints)
    kmz = KMZ.new(KML::Folder.new(:name => "Track log", :open => 1, :styleUrl => hints.stock.radio_folder_style.url))
    kmz.merge(hints.stock.invisible_none_folder)
    kmz.merge(make_colored_track_log(hints, @fixes.collect(&:alt), hints.scales.altitude))
    kmz.merge(make_colored_track_log(hints, @averages.collect(&:climb), hints.scales.climb, :visibility => 0))
    kmz.merge(make_colored_track_log(hints, @averages.collect(&:speed), hints.scales.speed, :visibility => 0))
    kmz.merge(make_monochromatic_track_log(hints, hints.color, hints.width, :absolute, :name => "Solid color", :visibility => 0))
  end

  def shadow_folder(hints)
    kmz = KMZ.new(KML::Folder.new(:name => "Shadow", :open => 1, :styleUrl => hints.stock.radio_folder_style.url))
    kmz.merge(hints.stock.invisible_none_folder)
    kmz.merge(make_monochromatic_track_log(hints, KML::Color.color("black"), 1, nil, :name => "Normal", :visibility => 1))
    kmz.merge(make_monochromatic_track_log(hints, hints.color, hints.width, nil, :name => "Solid color", :visibility => 0))
  end

  def photos_folder(hints)
    photos = hints.photos.find_all do |photo|
      (@times[0]..@times[-1]).include?(photo.time.to_i + hints.photo_tz_offset - hints.tz_offset)
    end
    return KMZ.new if photos.empty?
    icon_style = KML::IconStyle.new(KML::Icon.palette(4, 46), :scale => ICON_SCALE)
    label_style = KML::LabelStyle.new(:scale => LABEL_SCALES[0])
    style = KML::Style.new(icon_style, label_style)
    kmz = KMZ.new(KML::Folder.new(:name => "Photos"), :roots => [style])
    photos.sort_by(&:time).each do |photo|
      kmz.merge(photo.to_kmz(hints, :styleUrl => style.url))
    end
    kmz
  end

  def altitude_marks_folder(hints)
    styles = hints.scales.altitude.pixels.collect do |pixel|
      icon_style = KML::IconStyle.new(KML::Icon.palette(4, 24), :scale => ICON_SCALE)
      label_style = KML::LabelStyle.new(KML::Color.pixel(pixel))
      KML::Style.new(icon_style, label_style)
    end
    folders = {}
    [Extreme::Maximum, Extreme::Minimum].each do |type|
      folders[type] = KML::Folder.new(:name => type.to_s.sub(/\A.*::(Max|Min)imum/) { "#{$1}ima" }, :visibility => 0, :styleUrl => hints.stock.check_hide_children_style.url)
    end
    @alt_extremes.each do |extreme|
      folders[extreme.class].add(extreme.fix.to_kml(hints, :alt, {:altitudeMode => :absolute}, :styleUrl => styles[hints.scales.altitude.discretize(extreme.fix.alt)].url))
    end
    folder = KML::Folder.new(folders[Extreme::Maximum], folders[Extreme::Minimum], :name => "Altitude marks", :visibility => 0)
    KMZ.new(folder, :roots => styles)
  end

  def thermals_and_glides_folder(hints)
    folder = KML::Folder.new(:name => "Thermals and glides", :visibility => 0, :styleUrl => hints.stock.check_hide_children_style.url)
    icon_style = KML::IconStyle.new(KML::Icon.palette(4, 24), :scale => ICON_SCALE)
    label_style = KML::LabelStyle.new(KML::Color.new("ff0033ff"), :scale => LABEL_SCALES[2])
    line_style = KML::LineStyle.new(KML::Color.new("880033ff"), :width => 4)
    thermal_style = KML::Style.new(icon_style, label_style, line_style)
    icon_style = KML::IconStyle.new(KML::Icon.palette(4, 24), :scale => ICON_SCALE)
    label_style = KML::LabelStyle.new(KML::Color.new("ffff3300"), :scale => LABEL_SCALES[2])
    line_style = KML::LineStyle.new(KML::Color.new("88ff3300"), :width => 4)
    glide_style = KML::Style.new(icon_style, label_style, line_style)
    @alt_extremes.each_cons(2) do |extreme0, extreme1|
      dz = extreme1.fix.alt - extreme0.fix.alt
      dt = extreme1.fix.time - extreme0.fix.time
      ds = extreme0.fix.distance_to(extreme1.fix)
      point = KML::Point.new(:coordinates => extreme0.fix.halfway_to(extreme1.fix), :altitudeMode => :absolute)
      line_string = KML::LineString.new(:coordinates => [extreme0.fix, extreme1.fix], :altitudeMode => :absolute)
      multi_geometry = KML::MultiGeometry.new(point, line_string)
      if extreme0.is_a?(Extreme::Minimum)
        name = "%s at %s" % [hints.units[:altitude][dz], hints.units[:climb][dz.to_f / dt]]
        style = thermal_style
      else
        name = "%s at %s" % [hints.units[:distance][ds], (-ds / dz).to_glide]
        style = glide_style
      end
      min_climb = max_climb = max_speed = 0.0
      sum_alt_gain = sum_alt_loss = 0
      (@times.find_first_ge(extreme0.fix.time.to_i)...@times.find_first_ge(extreme1.fix.time.to_i)).each do |i|
        min_climb = @averages[i].climb if @averages[i].climb < min_climb
        max_climb = @averages[i].climb if @averages[i].climb > max_climb
        max_speed = @averages[i].speed if @averages[i].speed > max_speed
        change = @fixes[i + 1].alt - @fixes[i].alt
        case change <=> 0
        when  1 then sum_alt_gain += change
        when -1 then sum_alt_loss -= change
        end
      end
      rows = []
      if extreme0.is_a?(Extreme::Minimum)
        rows << ["Altitude gain", hints.units[:altitude][dz]]
        rows << ["Average climb", hints.units[:climb][dz.to_f / dt]]
        rows << ["Maximum climb", hints.units[:climb][max_climb]]
      else
        rows << ["Distance", hints.units[:distance][ds]]
        rows << ["Altitude loss", hints.units[:altitude][-dz]]
        rows << ["Average glide ratio", (-ds / dz).to_glide]
        rows << ["Average speed", hints.units[:speed][ds / dt]]
        rows << ["Maximum speed", hints.units[:speed][max_speed]]
        rows << ["Average sink", hints.units[:climb][dz.to_f / dt]]
        rows << ["Maximum sink", hints.units[:climb][min_climb]]
      end
      rows << ["Start altitude", hints.units[:altitude][extreme0.fix.alt]]
      rows << ["Finish altitude", hints.units[:altitude][extreme1.fix.alt]]
      rows << ["Start time", extreme0.fix.time.to_time(hints)]
      rows << ["Finish time", extreme1.fix.time.to_time(hints)]
      rows << ["Duration", (extreme1.fix.time - extreme0.fix.time).to_duration]
      rows << ["Accumulated altitude gain", hints.units[:altitude][sum_alt_gain]]
      rows << ["Accumulated altitude loss", hints.units[:altitude][sum_alt_loss]]
      description = KML::Description.new(KML::CData.new(rows.to_html_table))
      placemark = KML::Placemark.new(multi_geometry, description, :snippet => "", :styleUrl => style.url, :name => name, :visibility => 1)
      folder.add(placemark)
    end
    KMZ.new(folder, :roots => [thermal_style, glide_style])
  end

  def make_time_marks_folder(hints, periods)
    folder = KML::Folder.new(:name => "#{periods[-1].period / 60} minute", :visibility => 0, :styleUrl => hints.stock.check_hide_children_style.url)
    folder.add(@fixes[0].to_kml(hints, :time, {:altitudeMode => :absolute}, *periods[0].children))
    time = @fixes[0].time
    min_period = periods[-1].period
    time += min_period - (60 * time.min + time.sec) % min_period
    @fixes.each do |fix|
      if time < fix.time
        periods.each do |period|
          if (60 * time.min + time.sec) % period.period == 0
            name = time.to_time(hints,"%H:%M")
            folder.add(fix.to_kml(hints, name, {:altitudeMode => :absolute}, *period.children))
            break
          end
        end
        time += min_period
      end
    end
    folder.add(@fixes[-1].to_kml(hints, :time, {:altitudeMode => :absolute}, *periods[0].children))
    KMZ.new(folder)
  end

  def time_marks_folder(hints)
    folder = KML::Folder.new(:name => "Time marks", :styleUrl => hints.stock.radio_folder_style.url)
    styles = []
    period_struct = Struct.new(:period, :children)
    periods = [[3600, 27, 0], [1800, 27, 0], [900, 26, 1], [300, 25, 2], [60, 24, 3]].collect do |period, icon, label_scale_index|
      icon_style = KML::IconStyle.new(KML::Icon.palette(4, icon), :scale => ICON_SCALE)
      label_style = KML::LabelStyle.new(KML::Color.new("ff00ffff"), :scale => LABEL_SCALES[label_scale_index])
      style = KML::Style.new(icon_style, label_style)
      styles << style
      period_struct.new(period, [{:styleUrl => style.url}])
    end
    kmz = KMZ.new(folder, :roots => styles)
    (periods.length - 1).downto(0) do |index|
      kmz.merge(make_time_marks_folder(hints, periods[0..index]))
    end
    kmz.merge(hints.stock.visible_none_folder)
  end

  def optima_folder(hints)
    hints.optima.to_kmz(hints, :open => 1)
  end

  def task_marks_folder(hints)
    task = hints.task
    folder = KML::Folder.new(:name => "Task marks", :visibility => 0)
    index = 0
    index += 1 while task.course[index].is_a?(Task::TakeOff)
    turnpoint_number = 0
    @fixes.each_cons(2) do |fix0, fix1|
      object = task.course[index]
      fix = object.intersect?(fix0, fix1)
      next unless fix
      if object.is_a?(Task::Turnpoint)
        turnpoint_number += 1
        label = "T#{turnpoint_number}"
      else
        label = object.label
      end
      name = "#{label} #{(fix.time + hints.tz_offset).strftime("%H:%M:%S")}"
      folder.add(fix.to_kml(hints, name, {:altitudeMode => :absolute, :extrude => 1}, :styleUrl => hints.stock.task_style.url, :visibility => 0))
      index += 1
      break if index == task.course.length
    end
    KMZ.new(folder)
  end

  def competition_folder(hints)
    kmz = KMZ.new(KML::Folder.new(:name => "Competition", :open => 1))
    kmz.merge(hints.task.to_kmz(hints))
    kmz.merge(task_marks_folder(hints))
  end

  def make_graph(hints, values, scale, folder_options = {})
    name = KML::Name.new(scale.title.capitalize)
    folder = KML::Folder.new(name, KML::StyleUrl.new(hints.stock.check_hide_children_style.url), folder_options)
    image = scale.to_graph_image(hints, @times, values)
    image.set_channel_depth(Magick::AllChannels, 8)
    image.format = "png"
    href = "images/graphs/#{scale.title}.#{image.format.downcase}"
    icon = KML::Icon.new(:href => href)
    overlay_xy = KML::OverlayXY.new(:x => 0, :y => 0, :xunits => :fraction, :yunits => :fraction)
    screen_xy = KML::ScreenXY.new(:x => 0, :y => 16, :xunits => :fraction, :yunits => :pixels)
    size = KML::Size.new(:x => 0, :y => 0, :xunits => :fraction, :yunits => :fraction)
    screen_overlay = KML::ScreenOverlay.new(icon, overlay_xy, screen_xy, size)
    folder.add(screen_overlay)
    KMZ.new(folder, :files => {href => image.to_blob})
  end

  def graphs_folder(hints)
    kmz = KMZ.new(KML::Folder.new(:name => "Graphs", :styleUrl => hints.stock.radio_folder_style.url))
    kmz.merge(hints.stock.visible_none_folder)
    kmz.merge(make_graph(hints, @fixes.collect(&:alt), hints.scales.altitude, :visibility => 0))
    kmz.merge(make_graph(hints, @averages.collect(&:climb), hints.scales.climb, :visibility => 0))
    kmz.merge(make_graph(hints, @averages.collect(&:speed), hints.scales.speed, :visibility => 0))
  end

end
