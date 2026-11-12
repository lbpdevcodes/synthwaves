module VideoImport
  # Hands the source over for upload as it is (bin/import_video --no-encode).
  class PassThrough
    def prepare(source) = yield(source)
  end
end
