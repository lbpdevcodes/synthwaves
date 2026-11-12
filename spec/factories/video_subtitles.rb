FactoryBot.define do
  factory :video_subtitle do
    video
    sequence(:label) { |n| "Language #{n}" }
    language { "en" }
    kind { "subtitles" }
    vtt { "WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHello\n" }
  end
end
