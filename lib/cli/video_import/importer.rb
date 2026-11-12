module VideoImport
  # Uploads a video file to storage, then files it as a Video on the server.
  # The encoder decides what goes up: the source, or a copy it encoded.
  class Importer
    def initialize(api:, out:, encoder:)
      @api = api
      @out = out
      @encoder = encoder
    end

    def call(path, **video)
      @encoder.prepare(SourceFile.at(path)) { |source| upload(source, **video) }
    end

    private

    def upload(source, **video)
      upload = @api.create_direct_upload(source)
      StorageUpload.new(url: upload.url, headers: upload.headers, out: @out).put(source)
      @api.register_video(upload.signed_id, **video)
    end
  end
end
