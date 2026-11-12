module VideoImport
  # The conversion VideoConversionJob would run on a file, chosen the way its
  # #conversion_strategy chooses, with that method's exact ffmpeg arguments.
  # Running it here leaves the server nothing to convert.
  # spec/lib/cli/video_import/server_agreement_spec.rb keeps the two in step.
  module Conversion
    # #convert_to_mp4: a video that is not H.264.
    FULL = [
      "-c:v", "libx264", "-preset", "medium", "-crf", "23",
      "-ac", "2", "-c:a", "aac", "-b:a", "128k",
      "-movflags", "+faststart",
      "-vf", "scale='min(1920,iw)':'min(1080,ih)':force_original_aspect_ratio=decrease"
    ].freeze

    # #transcode_audio_to_mp4: H.264 with surround sound, or sound that is not AAC.
    AUDIO = ["-c:v", "copy", "-ac", "2", "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart"].freeze

    # #remux_to_mp4: H.264 and stereo AAC in a container other than MP4.
    REMUX = ["-c", "copy", "-movflags", "+faststart"].freeze

    # The ffmpeg arguments for the file the probe describes, or nil when the
    # server would keep it as it is.
    def self.for(probe)
      return FULL unless probe.h264?
      return AUDIO if probe.surround? || !probe.aac?

      REMUX unless probe.mp4?
    end
  end
end
