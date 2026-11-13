require "rails_helper"

RSpec.describe BarChart::Component, type: :component do
  include ViewComponent::TestHelpers

  def rows(html)
    html.css(".flex.items-center").map do |row|
      [row.css("span").first.text.strip, row.at_css("[style]")["style"], row.css("span").last.text.strip]
    end
  end

  it "draws a bar per entry at its share of the largest" do
    html = render_inline(described_class.new(title: "Genres", counts: {"rock" => 4, "jazz" => 1}))
    expect(rows(html)).to eq([["rock", "width: 100%", "4"], ["jazz", "width: 25%", "1"]])
  end

  it "titles the chart with a level-3 heading" do
    html = render_inline(described_class.new(title: "Genres", counts: {"rock" => 4}))
    expect(html.at_css("h3").text.strip).to eq("Genres")
  end

  it "titles the chart with the heading level it is given" do
    html = render_inline(described_class.new(title: "Top Genres", counts: {"rock" => 4}, heading: :h2))
    expect(html.at_css("h2").text.strip).to eq("Top Genres")
  end

  it "fills the bars with the gradient it is given" do
    html = render_inline(described_class.new(title: "Top Genres", counts: {"rock" => 4}, gradient: :plays))
    expect(html.at_css("[style]")["class"]).to include("from-neon-pink", "to-neon-cyan")
  end

  it "renders nothing, heading included, when there is nothing to count" do
    html = render_inline(described_class.new(title: "Genres", counts: {}))
    expect(html.to_html).to be_empty
  end
end
