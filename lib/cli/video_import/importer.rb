module VideoImport
  # Uploads a video file to storage, then files it as a Video on the server.
  # The encoder decides what goes up (the source, or a copy it encoded) and
  # what to file it with.
  class Importer
    def initialize(api:, out:, encoder:, limit: UploadLimit.new)
      @api = api
      @out = out
      @encoder = encoder
      @limit = limit
    end

    def call(path, **video)
      @encoder.prepare(SourceFile.at(path)) { |source| upload(source, **video) }
    end

    private

    # Files the video with what the encoder says the server would work out
    # about it (its details and thumbnail), when it says anything.
    def upload(source, **video)
      signed_id = store(source)
      ready = @encoder.ready_details(source) { |thumbnail| store(thumbnail) }
      @api.register_video(signed_id, **video, **ready)
    end

    # Storage would take the whole file before refusing one over the limit.
    def store(source)
      raise Error, @limit.over(source) unless @limit.fits?(source)

      upload = @api.create_direct_upload(source)
      StorageUpload.new(url: upload.url, headers: upload.headers, out: @out).put(source)
      upload.signed_id
    end
  end
end
