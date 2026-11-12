module VideoImport
  # Hands the source over for upload as it is (bin/import_video --no-encode).
  class PassThrough
    def prepare(source) = yield(source)

    # Nothing: the server reads the file and makes its thumbnail itself.
    def ready_details(_source) = {}
  end
end
