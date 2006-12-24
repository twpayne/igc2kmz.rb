class Sponsor

  attr_reader :name
  attr_reader :url
  attr_reader :img

  def initialize(name, url, img)
    @name = name
    @url = url
    @img = img
  end

end
