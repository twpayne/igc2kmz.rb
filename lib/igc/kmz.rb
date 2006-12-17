require "RMagick"
require "igc"
require "igc/analysis"
require "kmz"
require "task"
require "optima"
require "optima/kmz"
require "ostruct"
require "photo/kmz"
require "task/kmz"
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

  class Folder

    class << self

      def radio(*args)
        style = KML::Style.new(KML::ListStyle.new(:listItemType => :radioFolder))
        new(style, *args)
      end

      def hide_children(*args)
        style = KML::Style.new(KML::ListStyle.new(:listItemType => :checkHideChildren))
        new(style, *args)
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
      image = Image.new(columns + 2, rows + 2, &block)
      (0..2).each do |i|
        (0..2).each do |j|
          image.composite!(mask, i, j, Magick::MultiplyCompositeOp)
        end
      end
      image.composite!(self, 1, 1, Magick::OverCompositeOp)
      image
    end

  end

end

class Numeric

  def to_duration
    rem, secs = self.divmod(60)
    hours, mins = rem.divmod(60)
    "%d:%02d:%02d" % [hours, mins, secs]
  end

end

class Scale

  def initialize(range, format, multiplier = 1, gradient = Gradient::Default)
    @range = range
    @format = format
    @multiplier = multiplier
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

  def to_image
    border = 8
    height = 256
    width = 64
    multiplied_range = Range.new(@multiplier * @range.first, @multiplier * @range.last, @range.exclude_end?)
    Magick::RVG.new(width + 2 * border, height + 2 * border) do |canvas|
      canvas.styles(:font_family => "Verdana", :font_size => 9, :font_weight => "bold")
      i = 3 * (Math.log10(multiplied_range.last - multiplied_range.first).to_i - 2)
      step = [1.0, 2.5, 5.0][i % 3] * (10 ** (i / 3))
      while (multiplied_range.last - multiplied_range.first) / step > 15
        i += 1
        step = [1.0, 2.5, 5.0][i % 3] * (10 ** (i / 3))
      end
      value = step * (multiplied_range.first / step).ceil
      while value <= multiplied_range.last
        y = (height * (1.0 - (value - multiplied_range.first) / (multiplied_range.last - multiplied_range.first))).round + border
        color = color_of(value / @multiplier)
        canvas.line(border, y, 8 + border, y).styles(:stroke => color)
        canvas.text(12 + border, y, @format % value).d(0, 4).styles(:fill => color)
        value += step
      end
      (0...height).each do |y|
        value = @range.last - (y + 0.5) * (@range.last - @range.first) / height
        color = color_of(value)
        canvas.line(border, border + y, border + 4, border + y).styles(:stroke => color)
      end
    end.draw.outline do
      self.background_color = "transparent"
    end
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
      a = "#{@alt}m"
      t = (@time + hints.tz_offset).strftime("%H:%M:%S")
      case name
      when :alt  then name = a
      when :time then name = t
      end
      name = KML::Name.new(name) if name.is_a?(String)
      statistics = []
      statistics << ["Altitude", a]
      statistics << ["Time", t]
      description = KML::Description.new(KML::CData.new("<table>", statistics.collect do |th, td|
        "<tr><th>#{th}</th><td>#{td}</td></tr>"
      end.join, "</table>"))
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
      KMZ.new(KML::Folder.hide_children(screen_overlay, options))
    end

=begin
    def make_logo
      href = "http://www.flyozone.com/common/images/logo.jpg"
      href = "http://www.flysunvalley.com/images/Ozone-logo.jpg"
      icon = KML::Icon.new(:href => href)
      overlay_xy = KML::OverlayXY.new(:x => 0.5, :y => 1, :xunits => :fraction, :yunits => :fraction)
      screen_xy = KML::ScreenXY.new(:x => 0.5, :y => 1, :xunits => :fraction, :yunits => :units)
      size = KML::Size.new(:x => 0, :y => 0, :xunits => :fraction, :yunits => :fraction)
      KML::ScreenOverlay.new(icon, overlay_xy, screen_xy, size, :name => "Sponsored by Ozone")
    end
=end

    def stock
      stock = OpenStruct.new
      stock.kmz = KMZ.new
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
      icon_style = KML::IconStyle.new(KML::Icon.palette(4, 24), :scale => IGC::ICON_SCALE)
      stock.task_style = KML::Style.new(icon_style)
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
      hints.league = :open
      hints.photo_tz_offset = 0
      hints.photos = []
      hints.stock = stock
      hints.width = 2
      hints
    end

  end

  def to_kmz(hints = nil)
    hints = hints ? hints.clone : self.class.default_hints
    unless hints.tz_offset
      if @header[:timezone_offset]
        hints.tz_offset = 60 * @header[:timezone_offset].to_i
      else
        hints.tz_offset = 0
      end
    end
    analyse
    if hints.bounds
      hints.bounds.merge(@bounds)
    else
      hints.bounds = @bounds
    end
    hints.igc = self
    hints.optima = Optima.new_from_igc(self, hints.league, hints.complexity) unless hints.task
    rows = []
    rows << ["Pilot", hints.pilot || @header[:pilot]] if hints.pilot or @header[:pilot]
    rows << ["Date", (@fixes[0].time + hints.tz_offset).strftime("%A, %d %B %Y")]
    if hints.task
      rows << ["Competition", hints.task.competition_name] if hints.task.competition_name
      rows << ["Task", hints.task.number] if hints.task.number
    end
    rows << ["Site", @header[:site]] if @header[:site]
    rows << ["Glider", @header[:glider_type]] if @header[:glider_type]
    rows << ["Created by", "<a href=\"http://maximumxc.com/\">maximumxc.com</a>"]
    description = KML::Description.new(KML::CData.new("<table>", rows.collect do |th, td|
      "<tr><th>#{th}</th><td>#{td}</td></tr>"
    end.join, "</table>"))
    fields = []
    fields << (hints.pilot || @header[:pilot]) if hints.pilot or @header[:pilot]
    fields << "#{hints.task.competition_name} task #{hints.task.number}" if hints.task
    fields << @header[:site] if @header[:site]
    fields << (@fixes[0].time + hints.tz_offset).strftime("%d %b %Y")
    snippet = KML::Snippet.new(fields.join(", "), :maxlines => 1)
    kmz = KMZ.new(KML::Folder.new(description, snippet, :name => @filename, :open => 1))
    kmz.merge(hints.stock.kmz)
    kmz.merge(track_log_folder(hints))
    kmz.merge(shadow_folder(hints))
    kmz.merge(photos_folder(hints)) if hints.photos and !hints.photos.empty?
    kmz.merge(optima_folder(hints)) if hints.optima
    kmz.merge(competition_folder(hints)) if hints.task
    kmz.merge(altitude_marks_folder(hints))
    kmz.merge(thermals_and_glides_folder(hints))
    kmz.merge(time_marks_folder(hints))
  end

  def make_monochromatic_track_log(color, width, altitude_mode, folder_options = {})
    style = KML::Style.new(KML::LineStyle.new(color, :width => width))
    line_string = KML::LineString.new(:coordinates => @fixes, :altitudeMode => altitude_mode)
    placemark = KML::Placemark.new(style, line_string)
    KMZ.new(KML::Folder.hide_children(placemark, folder_options))
  end

  def make_colored_track_log(hints, values, scale, folder_options = {})
    folder = KML::Folder.hide_children(folder_options)
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
    href = "images/%x.%s" % [image.object_id.abs, image.format.downcase]
    icon = KML::Icon.new(:href => href)
    overlay_xy = KML::OverlayXY.new(:x => 0, :y => 0, :xunits => :fraction, :yunits => :fraction)
    screen_xy = KML::ScreenXY.new(:x => 0, :y => 16, :xunits => :fraction, :yunits => :pixels)
    size = KML::Size.new(:x => 0, :y => 0, :xunits => :fraction, :yunits => :fraction)
    screen_overlay = KML::ScreenOverlay.new(icon, overlay_xy, screen_xy, size)
    folder.add(screen_overlay)
    KMZ.new(folder, :roots => styles, :files => {href => image.to_blob})
  end

  def track_log_folder(hints)
    kmz = KMZ.new(KML::Folder.radio(:name => "Track log", :open => 1))
    kmz.merge(hints.stock.invisible_none_folder)
    kmz.merge(make_colored_track_log(hints, @fixes.collect(&:alt), Scale.new(hints.bounds.alt, "%d m"), :name => "Colored by altitude"))
    kmz.merge(make_colored_track_log(hints, @averages.collect(&:climb), ZeroCenteredScale.new(hints.bounds.climb, "%+.1f m/s"), :name => "Colored by climb", :visibility => 0))
    kmz.merge(make_colored_track_log(hints, @averages.collect(&:speed), Scale.new(hints.bounds.speed, "%d km/h", 3.6), :name => "Colored by speed", :visibility => 0))
    #kmz.merge(make_colored_track_log(hints, @averages.collect(&:climb_or_glide), BilinearScale.new(hints.bounds.speed, "+.1f m/s", 1, "%d:1", 1), :name => "Colored by climb and glide", :visibility => 0))
    kmz.merge(make_monochromatic_track_log(hints.color, hints.width, :absolute, :name => "Solid color", :visibility => 0))
  end

  def shadow_folder(hints)
    kmz = KMZ.new(KML::Folder.radio(:name => "Shadow"))
    kmz.merge(hints.stock.invisible_none_folder)
    kmz.merge(make_monochromatic_track_log(KML::Color.color("black"), 1, nil, :name => "Normal", :visibility => 1))
    kmz.merge(make_monochromatic_track_log(hints.color, hints.width, nil, :name => "Solid color", :visibility => 0))
  end

  def photos_folder(hints)
    icon_style = KML::IconStyle.new(KML::Icon.palette(4, 46), :scale => ICON_SCALE)
    label_style = KML::LabelStyle.new(:scale => LABEL_SCALES[0])
    style = KML::Style.new(icon_style, label_style)
    kmz = KMZ.new(KML::Folder.new(:name => "Photos", :open => 0), :roots => [style])
    hints.photos.sort_by(&:time.to_proc(hints)).each do |photo|
      kmz.merge(photo.to_kmz(hints, :styleUrl => style.url))
    end
    kmz
  end

  def altitude_marks_folder(hints)
    scale = Scale.new(hints.bounds.alt, "%d m")
    styles = scale.pixels.collect do |pixel|
      icon_style = KML::IconStyle.new(KML::Icon.palette(4, 24), :scale => ICON_SCALE)
      label_style = KML::LabelStyle.new(KML::Color.pixel(pixel))
      KML::Style.new(icon_style, label_style)
    end
    folders = {}
    [Extreme::Maximum, Extreme::Minimum].each do |type|
      folders[type] = KML::Folder.hide_children(:name => type.to_s.sub(/\A.*::(Max|Min)imum/) { "#{$1}ima" }, :visibility => 0)
    end
    @alt_extremes.each do |extreme|
      folders[extreme.class].add(extreme.fix.to_kml(hints, :alt, {:altitudeMode => :absolute}, :styleUrl => styles[scale.discretize(extreme.fix.alt)].url))
    end
    folder = KML::Folder.new(folders[Extreme::Maximum], folders[Extreme::Minimum], :name => "Altitude marks", :open => 0, :visibility => 0)
    KMZ.new(folder, :roots => styles)
  end

  def thermals_and_glides_folder(hints)
    folder = KML::Folder.new(:name => "Thermals and glides", :open => 0, :visibility => 0)
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
      if extreme0.is_a?(Extreme::Minimum) and extreme1.is_a?(Extreme::Maximum)
        name = "+%dm at %.1fm/s" % [dz, dz.to_f / dt]
        style = thermal_style
      elsif extreme0.is_a?(Extreme::Maximum) and extreme1.is_a?(Extreme::Minimum)
        name = "%.1fkm at %.1f:1" % [ds / 1000.0, -ds / dz]
        style = glide_style
      end
      min_climb = max_climb = max_speed = 0.0
      (@times.find_first_ge(extreme0.fix.time.to_i)...@times.find_first_ge(extreme1.fix.time.to_i)).each do |i|
        min_climb = @averages[i].climb if @averages[i].climb < min_climb
        max_climb = @averages[i].climb if @averages[i].climb > max_climb
        max_speed = @averages[i].speed if @averages[i].speed > max_speed
      end
      statistics = []
      if extreme0.is_a?(Extreme::Minimum) and extreme1.is_a?(Extreme::Maximum)
        statistics << ["Altitude gain", "%dm" % dz]
        statistics << ["Average climb", "%+.1fm/s" % (dz.to_f / dt)]
        statistics << ["Maximum climb", "%+.1fm/s" % max_climb]
      end
      if extreme0.is_a?(Extreme::Maximum) and extreme1.is_a?(Extreme::Minimum)
        statistics << ["Distance", "%.1fkm" % (ds / 1000.0)]
        statistics << ["Altitude loss", "%dm" % -dz]
        statistics << ["Average glide ratio", "%.1f:1" % (-ds / dz)]
        statistics << ["Average speed", "%dkm/h" % (3.6 * ds / dt)]
        statistics << ["Maximum speed", "%dkm/h" % (3.6 * max_speed)]
        statistics << ["Average sink", "%+.1fm/s" % (dz.to_f / dt)]
        statistics << ["Maximum sink", "%+.1fm/s" % min_climb]
      end
      statistics << ["Start altitude", "%dm" % extreme0.fix.alt]
      statistics << ["Finish altitude", "%dm" % extreme1.fix.alt]
      statistics << ["Start time", (extreme0.fix.time + hints.tz_offset).strftime("%H:%M:%S")]
      statistics << ["Finish time", (extreme1.fix.time + hints.tz_offset).strftime("%H:%M:%S")]
      statistics << ["Duration", (extreme1.fix.time - extreme0.fix.time).to_duration]
      description = KML::Description.new(KML::CData.new("<table>", statistics.collect do |th, td|
        "<tr><th>#{th}</th><td>#{td}</td></tr>"
      end.join, "</table>"))
      placemark = KML::Placemark.new(multi_geometry, description, KML::Snippet.new, :styleUrl => style.url, :name => name, :visibility => 0)
      folder.add(placemark)
    end
    KMZ.new(folder, :roots => [thermal_style, glide_style])
  end

  def make_time_marks_folder(hints, periods)
    folder = KML::Folder.hide_children(:name => "#{periods[-1].period / 60} minute", :visibility => 0)
    folder.add(@fixes[0].to_kml(hints, :time, {:altitudeMode => :absolute}, *periods[0].children))
    time = @fixes[0].time
    min_period = periods[-1].period
    time += min_period - (60 * time.min + time.sec) % min_period
    @fixes.each do |fix|
      if time < fix.time
        periods.each do |period|
          if (60 * time.min + time.sec) % period.period == 0
            name = (time + hints.tz_offset).strftime("%H:%M")
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
    folder = KML::Folder.radio(:name => "Time marks", :open => 0)
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
    hints.optima.to_kmz(hints)
  end

  def task_marks_folder(hints)
    task = hints.task
    folder = KML::Folder.new(:name => "Task marks", :open => 0, :visibility => 0)
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
    kmz = KMZ.new(KML::Folder.new(:name => "Competition", :open => 0))
    kmz.merge(hints.task.to_kmz(hints, :open => 0))
    kmz.merge(task_marks_folder(hints))
  end

end
