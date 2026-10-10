module Modal
  class Component < ViewComponent::Base
    renders_one :header
    renders_one :footer
    renders_one :opener

    def initialize(title: nil, open: false, cancellable: true, backdrop_cancellable: true, remove_on_close: false)
      @title = title
      @open = open
      @cancellable = cancellable
      @backdrop_cancellable = backdrop_cancellable
      @remove_on_close = remove_on_close
    end

    private

    attr_reader :title, :open, :cancellable, :backdrop_cancellable, :remove_on_close

    def open? = open
    def cancellable? = cancellable
    def backdrop_cancellable? = backdrop_cancellable

    def dialog_actions
      actions = ["close->modal#closed"]
      actions << "click->modal#backdropClick" if backdrop_cancellable?
      actions.join(" ")
    end
  end
end
