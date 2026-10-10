module TrackActions
  class Component < ViewComponent::Base
    def initialize(track:, favorited:)
      @track = track
      @favorited = favorited
    end

    private

    attr_reader :track, :favorited

    def downloadable? = track.audio_file.attached?
  end
end
