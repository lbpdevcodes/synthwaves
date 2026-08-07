module AgentGateway
  module Tools
    # Uploads an audio file as a new track, mirroring the multipart branch of
    # POST /api/v1/tracks. Base64 is the only way to ship bytes through MCP's
    # JSON tool arguments.
    class UploadTrack < AgentGateway::Tool
      MAX_UPLOAD_BYTES = 50.megabytes
      AUDIO_EXTENSION = /\.\w+\z/

      tool_name "upload_track"
      description "Upload an audio file as a new track. audio_base64 must be the base64-encoded " \
        "file bytes (max ~50 MB decoded). Embedded tags (title/artist/album/year/genre/track/disc) " \
        "are read automatically; any metadata argument you pass overrides the embedded tag. " \
        "Conversion, loudness analysis, search indexing, and MusicBrainz enrichment run in the background."
      annotations(read_only_hint: false, destructive_hint: false)
      input_schema(
        properties: {
          filename: {type: "string", description: "Original filename with extension, e.g. song.mp3"},
          audio_base64: {type: "string", description: "Base64-encoded audio bytes"},
          title: {type: "string"},
          artist_name: {type: "string"},
          album_title: {type: "string"},
          year: {type: "integer"},
          genre: {type: "string"},
          track_number: {type: "integer"},
          disc_number: {type: "integer"}
        },
        required: %w[filename audio_base64]
      )

      def self.perform(filename:, audio_base64:, server_context:, title: nil, artist_name: nil,
        album_title: nil, year: nil, genre: nil, track_number: nil, disc_number: nil)
        data = decode(audio_base64)
        return error_response("audio_base64 is not valid base64") if data.nil?
        if data.bytesize > MAX_UPLOAD_BYTES
          return error_response("Audio exceeds the #{MAX_UPLOAD_BYTES / 1.megabyte} MB limit")
        end
        extension = filename[AUDIO_EXTENSION]
        return error_response("filename must include an extension (e.g. song.mp3)") if extension.nil?

        create_track(data:, filename:, extension:, overrides: {
          title: title, artist_name: artist_name, album_title: album_title, year: year,
          genre: genre, track_number: track_number, disc_number: disc_number
        }, user: user(server_context))
      end

      def self.decode(audio_base64)
        Base64.strict_decode64(audio_base64)
      rescue ArgumentError
        nil
      end

      def self.create_track(data:, filename:, extension:, overrides:, user:)
        Tempfile.create(["mcp-upload", extension], binmode: true) do |file|
          file.write(data)
          file.flush
          metadata = extract_metadata(file.path)

          artist, album = ArtistAlbumResolver.call(
            user: user,
            artist_name: overrides[:artist_name].presence || metadata[:artist],
            album_title: overrides[:album_title].presence || metadata[:album],
            year: overrides[:year] || metadata[:year],
            genre: overrides[:genre].presence || metadata[:genre]
          )

          track = build_track(user, data, filename, extension, metadata, overrides, artist, album)
          return error_response(track.errors.full_messages.join(", ")) unless track.save

          json_response(API::V1::TrackSerializer.render_as_hash(track, view: :full).merge(created: true))
        end
      end

      def self.build_track(user, data, filename, extension, metadata, overrides, artist, album)
        track = user.tracks.build(
          title: overrides[:title].presence || metadata[:title] || filename.sub(AUDIO_EXTENSION, ""),
          artist: artist,
          album: album,
          track_number: overrides[:track_number] || metadata[:track_number],
          disc_number: overrides[:disc_number] || metadata[:disc_number] || 1,
          duration: metadata[:duration],
          bitrate: metadata[:bitrate],
          file_format: extension.delete("."),
          file_size: data.bytesize
        )
        track.audio_file.attach(
          io: StringIO.new(data),
          filename: filename,
          content_type: Marcel::MimeType.for(name: filename)
        )
        track
      end

      def self.extract_metadata(path)
        MetadataExtractor.call(path)
      rescue WahWah::WahWahArgumentError
        {}
      end
    end
  end
end
