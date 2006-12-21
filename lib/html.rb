require "lib"

class Array

  def to_html_tr
    result = "<tr>"
    each_with_index do |element, index|
      tag = index.zero? ? "th" : "td"
      result << "<#{tag}>#{element.to_s}</#{tag}>"
    end
    result << "</tr>"
    result
  end

  def to_html_table
    "<table>#{collect(&:to_html_tr).join}</table>"
  end

end
