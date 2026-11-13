module StatTile
  # One figure on the Stats page with its label under it: "10,536 Tracks".
  class Component < ViewComponent::Base
    COLORS = {
      cyan: "text-neon-cyan",
      pink: "text-neon-pink",
      green: "text-laser-green",
      purple: "text-neon-purple"
    }.freeze

    def initialize(value:, label:, color: :cyan)
      @value = value
      @label = label
      @color = color
    end

    private

    attr_reader :value, :label, :color

    def value_classes
      "text-2xl font-bold #{COLORS.fetch(color)} tabular-nums"
    end
  end
end
