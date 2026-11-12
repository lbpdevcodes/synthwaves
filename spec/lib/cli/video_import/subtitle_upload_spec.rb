require "webmock/rspec"
require "tmpdir"
require "stringio"
require_relative "../../../../lib/cli/video_import"

RSpec.describe VideoImport::SubtitleUpload do
  let(:host) { "https://synthwaves.test" }
  let(:subtitles_url) { "#{host}/api/import/videos/15/subtitles" }
  let(:out) { StringIO.new }
  let(:api) { VideoImport::API.new(host: host, client_id: "bc_id", secret_key: "secret") }
  let(:upload) { described_class.new(api: api, out: out) }

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  def subtitle_file(name, contents)
    File.join(@dir, name).tap { |path| File.binwrite(path, contents) }
  end

  def stub_auth(*tokens)
    stub_request(:post, "#{host}/api/v1/auth/token")
      .to_return(*tokens.map { |token| {status: 200, body: JSON.generate(token: token)} })
  end

  def added(label) = {status: 201, body: JSON.generate(id: 1, label: label, language: "fr", kind: "subtitles")}

  it "sends each file to the video, base64-encoded under its own name" do
    stub_auth("token-1")
    stub_request(:post, subtitles_url).to_return(added("French (Canadian)"))
    french = subtitle_file("Canadian.fre.srt", "D\xE9j\xE0 vu".b)

    upload.call(15, [french])

    expect(WebMock).to have_requested(:post, subtitles_url)
      .with(body: {filename: "Canadian.fre.srt", content_base64: ["D\xE9j\xE0 vu".b].pack("m0")})
  end

  it "reports each subtitle the server added, by the label it gave it" do
    stub_auth("token-1", "token-2")
    stub_request(:post, subtitles_url).to_return(added("English (SDH)"), added("French (Canadian)"))

    upload.call(15, [subtitle_file("SDH.eng.HI.srt", "a"), subtitle_file("Canadian.fre.srt", "b")])

    expect(out.string).to eq("Added subtitles: English (SDH)\nAdded subtitles: French (Canadian)\n")
  end

  it "sends the rest when the server refuses one, and returns what it refused and why" do
    stub_auth("token-1", "token-2")
    stub_request(:post, subtitles_url).to_return(
      {status: 422, body: JSON.generate(error: "notes.srt: no subtitle cues found")}, added("French (Canadian)")
    )

    failures = upload.call(15, [subtitle_file("notes.srt", "a"), subtitle_file("Canadian.fre.srt", "b")])

    expect(failures).to eq(["notes.srt: subtitle rejected (422): notes.srt: no subtitle cues found"])
    expect(out.string).to eq("Added subtitles: French (Canadian)\n")
  end
end
