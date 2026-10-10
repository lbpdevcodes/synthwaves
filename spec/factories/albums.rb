FactoryBot.define do
  factory :album do
    sequence(:title) { |n| "Album #{n}" }
    artist { nil }
    user { nil }

    # An album and its artist live in one library. Fill whichever side the
    # caller left out from the side they gave, so `create(:album, user: u)`
    # and `create(:album, artist: a)` both stay inside one user's library.
    after(:build) do |album|
      album.user ||= album.artist&.user || build(:user)
      album.artist ||= build(:artist, user: album.user)
    end

    trait :with_cover_image do
      after(:create) do |album|
        album.cover_image.attach(io: StringIO.new("fake image"), filename: "cover.png", content_type: "image/png")
      end
    end
  end
end
