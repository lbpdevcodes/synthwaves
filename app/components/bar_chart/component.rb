module BarChart
  # A titled chart of horizontal bars, one per label, each as long as its
  # count's share of the largest. Draws nothing, title included, when there
  # is nothing to count.
  class Component < ViewComponent::Base
    GRADIENTS = {
      library: "from-neon-purple to-laser-green",
      plays: "from-neon-pink to-neon-cyan"
    }.freeze

    HEADINGS = {
      h2: "text-lg font-semibold text-white mb-3",
      h3: "text-base font-semibold text-white mb-2"
    }.freeze

    # counts: {"rock" => 4, "jazz" => 1}, drawn in the order given.
    def initialize(title:, counts:, gradient: :library, heading: :h3)
      @title = title
      @counts = counts
      @gradient = gradient
      @heading = heading
    end

    def render? = counts.any?

    private

    attr_reader :title, :counts, :gradient, :heading

    def title_tag = content_tag(heading, title, class: HEADINGS.fetch(heading))

    def bar_classes = "h-full bg-gradient-to-r #{GRADIENTS.fetch(gradient)} rounded-full transition-all"

    def bar_style(count) = "width: #{(count / largest * 100).round}%"

    def largest = counts.values.max.to_f
  end
end
