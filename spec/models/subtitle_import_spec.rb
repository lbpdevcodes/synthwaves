require "rails_helper"

RSpec.describe SubtitleImport do
  let(:video) { create(:video) }
  let(:srt) { "1\n00:00:02,000 --> 00:00:07,500\nBonjour\n" }

  it "files a subtitle named after its file" do
    import = SubtitleImport.new(video: video, filename: "Canadian.fre.srt", data: srt)

    expect(import.save).to be(true)
    expect(video.subtitles.sole).to have_attributes(label: "French (Canadian)", language: "fr", kind: "subtitles",
      vtt: "WEBVTT\n\n1\n00:00:02.000 --> 00:00:07.500\nBonjour\n")
  end

  it "reads the name against the video's own file name" do
    video.file.attach(io: StringIO.new("video"), filename: "Heat.1995.mp4", content_type: "video/mp4")

    SubtitleImport.new(video: video, filename: "Heat.1995.en.srt", data: srt).save

    expect(video.subtitles.sole.label).to eq("English")
  end

  it "takes a label given to it over the file name's" do
    SubtitleImport.new(video: video, filename: "Canadian.fre.srt", data: srt, label: "Québécois").save

    expect(video.subtitles.sole).to have_attributes(label: "Québécois", language: "fr")
  end

  it "numbers a label the video already has" do
    create(:video_subtitle, video: video, label: "English")
    create(:video_subtitle, video: video, label: "English 2")

    SubtitleImport.new(video: video, filename: "English.srt", data: srt).save

    expect(video.subtitles.pluck(:label)).to contain_exactly("English", "English 2", "English 3")
  end

  it "refuses a file with no subtitles in it, saying which file and why" do
    import = SubtitleImport.new(video: video, filename: "poster.jpg", data: "\xFF\xD8\xFF\xE0".b)

    expect(import.save).to be(false)
    expect(import.errors.full_messages).to eq(["poster.jpg: no subtitle cues found"])
    expect(video.subtitles).to be_empty
  end

  it "asks for a file when none was chosen" do
    import = SubtitleImport.new(video: video, filename: nil, data: nil)

    expect(import.save).to be(false)
    expect(import.errors.full_messages).to eq(["Choose a subtitle file (.srt or .vtt)"])
  end
end
