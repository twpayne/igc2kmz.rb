require "kmz"
require "sponsor"

class Sponsor

  def to_kmz(hints)
    name = KML::Name.new("Sponsored by #{@name}")
    img_src = @img.scheme ? @img : "images/#{File.basename(@img.path)}"
    description = KML::Description.new(KML::CData.new(<<-EOHTML))
      <center>
        <p><a href="#{@url}"><img alt="#{@name}" src="#{img_src}" /></a></p>
        <p><a href="#{@url}">#{@url}</a></p>
        <p>Created by <a href="http://maximumxc.com/">maximumxc.com</a></p>
      </center>
    EOHTML
    snippet = KML::Snippet.new
    icon = KML::Icon.new(:href => img_src)
    overlay_xy = KML::OverlayXY.new(:x => 0.5, :y => 1, :xunits => :fraction, :yunits => :fraction)
    screen_xy = KML::ScreenXY.new(:x => 0.5, :y => 1, :xunits => :fraction, :yunits => :fraction)
    size = KML::Size.new(:x => 0, :y => 0, :xunits => :fraction, :yunits => :fraction)
    screen_overlay = KML::ScreenOverlay.new(name, description, snippet, icon, overlay_xy, screen_xy, size)
    files = {}
    files[img_src] = File.open(@img.to_s) unless @img.scheme
    KMZ.new(screen_overlay, :files => files)
  end

end
