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

class String

  def html_entity_encode
    gsub(/&|>|<|"/) do |match|
      case match
      when '&' then '&amp;'
      when '<' then '&gt;'
      when '>' then '&lt;'
      when '"' then '&quot;'
      end
    end
  end

  def html_entity_decode
    gsub(/&([^;]*);/) do |match|
      case match
      when '&amp;'  then '&'
      when '&gt;'   then '>'
      when '&lt;'   then '<'
      when '&quot;' then '"'
      when /&#([0-9A-Fa-f]+);/ then Regexp.last_match[1].hex.chr
      else match
      end
    end
  end

  def url_encode
    gsub(/[^0-9A-Za-z]/) do |match|
      match == ' ' ? '+' : sprintf('%%%02x', match[0])
    end
  end 

  def url_decode
    gsub(/\+|%[0-9A-Fa-f][0-9A-Fa-f]/) do |match|
      match == '+' ? ' ' : match[1..2].hex.chr
    end
  end

end
