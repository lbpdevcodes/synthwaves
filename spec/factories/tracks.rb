FactoryBot.define do
  factory :track do
    sequence(:title) { |n| "Track #{n}" }
    album { nil }
    artist { nil }
    user { nil }
    duration { 180.0 }
    track_number { 1 }
    disc_number { 1 }
    file_format { "mp3" }
    file_size { 5_000_000 }
    bitrate { 320 }

    # A track, its album and its artist live in one library. Fill whatever
    # the caller left out from what they gave: user, artist or album.
    after(:build) do |track|
      track.user ||= track.album&.user || track.artist&.user || build(:user)
      track.artist ||= track.album&.artist || build(:artist, user: track.user)
      track.album ||= build(:album, artist: track.artist, user: track.user)
    end

    after(:build) do |track|
      unless track.youtube_video_id.present? || track.audio_file.attached?
        track.audio_file.attach(
          io: StringIO.new("fake audio data"),
          filename: "track.mp3",
          content_type: "audio/mpeg"
        )
      end
    end

    trait :youtube do
      youtube_video_id { "dQw4w9WgXcQ" }
      file_format { nil }
      file_size { nil }
      bitrate { nil }
    end

    trait :with_lyrics do
      lyrics { "Verse 1\nSome lyrics here\n\nChorus\nThe chorus goes here" }
    end
  end
end
