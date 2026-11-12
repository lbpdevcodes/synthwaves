require "rails_helper"

RSpec.describe SubtitleText do
  def webvtt(source) = described_class.to_webvtt(source)

  it "turns SRT cue timings into WebVTT under a WEBVTT header" do
    srt = "1\n00:00:02,000 --> 00:00:07,500\nWell, hello there\n"

    expect(webvtt(srt)).to eq("WEBVTT\n\n1\n00:00:02.000 --> 00:00:07.500\nWell, hello there\n")
  end

  it "passes WebVTT through as it is" do
    vtt = "WEBVTT\n\n00:00:02.000 --> 00:00:07.500\nHello\n"

    expect(webvtt(vtt)).to eq(vtt)
  end

  it "drops a UTF-8 byte order mark" do
    srt = "\xEF\xBB\xBF1\n00:00:02,000 --> 00:00:07,500\nHello\n".b

    expect(webvtt(srt)).to start_with("WEBVTT\n\n1\n")
  end

  it "ends every line with a bare line feed" do
    srt = "1\r\n00:00:02,000 --> 00:00:07,500\r\nHello\r\n"

    expect(webvtt(srt)).to eq("WEBVTT\n\n1\n00:00:02.000 --> 00:00:07.500\nHello\n")
  end

  it "reads text that is not UTF-8 as Windows-1252" do
    srt = "1\n00:00:02,000 --> 00:00:07,500\nD\xE9j\xE0 vu \x96 encore\n".b

    expect(webvtt(srt)).to end_with("Déjà vu – encore\n")
  end

  it "replaces a byte Windows-1252 leaves undefined instead of rejecting the file" do
    srt = "1\n00:00:02,000 --> 00:00:07,500\nCaf\xE9 \x81\n".b

    expect(webvtt(srt)).to end_with("Café �\n")
  end

  it "keeps italic, bold and underline but drops font tags and ASS overrides WebVTT would print" do
    srt = %(1\n00:00:02,000 --> 00:00:07,500\n{\\an8}<font color="#ffff00"><i>Look</i></font> <b>up</b> <u>now</u>\n)

    expect(webvtt(srt)).to end_with("<i>Look</i> <b>up</b> <u>now</u>\n")
  end

  it "escapes a bare ampersand and a less-than sign that opens no tag" do
    srt = "1\n00:00:02,000 --> 00:00:07,500\nTom & Jerry <3 <i>you</i> &amp; me\n"

    expect(webvtt(srt)).to end_with("Tom &amp; Jerry &lt;3 <i>you</i> &amp; me\n")
  end

  it "rejects text with no cue timings" do
    expect { webvtt("Downloaded from somewhere\n") }
      .to raise_error(SubtitleText::Unreadable, "no subtitle cues found")
  end

  it "reads UTF-16 marked by a byte order mark" do
    srt = "﻿1\n00:00:02,000 --> 00:00:07,500\nHéllo\n".encode(Encoding::UTF_16LE).b

    expect(webvtt(srt)).to eq("WEBVTT\n\n1\n00:00:02.000 --> 00:00:07.500\nHéllo\n")
  end
end
