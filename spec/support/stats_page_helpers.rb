# Reads figures off a Stats page response: a tile's value, a bar chart's row.
module StatsPageHelpers
  # The figure drawn above a tile's label.
  def tile_value(label)
    stats_page.css("div").find { |node| node.text.strip == label && node.element_children.empty? }
      &.previous_element&.text&.strip
  end

  # The [count, bar width] a bar chart under a heading draws for a label.
  def bar(heading, label)
    rows = stats_page.css("h2, h3").find { |node| node.text.strip == heading }.next_element
    row = rows.css("span").find { |span| span.text.strip == label }.parent
    [row.css("span").last.text.strip, row.at_css("[style]")["style"]]
  end

  def stats_page = Nokogiri::HTML(response.body)
end

RSpec.configure do |config|
  config.include StatsPageHelpers, type: :request
end
