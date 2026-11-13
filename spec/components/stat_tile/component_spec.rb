require "rails_helper"

RSpec.describe StatTile::Component, type: :component do
  include ViewComponent::TestHelpers

  it "shows the figure above its label" do
    html = render_inline(described_class.new(value: "1,234", label: "Tracks"))
    expect(html.css("div > div").map { |node| node.text.strip }).to eq(["1,234", "Tracks"])
  end

  it "colors the figure" do
    html = render_inline(described_class.new(value: 3, label: "Albums", color: :pink))
    expect(html.css("div > div").first["class"]).to include("text-neon-pink")
  end
end
