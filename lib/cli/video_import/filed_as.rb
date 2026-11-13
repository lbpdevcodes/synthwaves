module VideoImport
  # An importer that files every video it uploads with the same fields, for a
  # folder of one kind: bin/import_videos --type movie --genre comedy.
  class FiledAs
    def initialize(importer, **fields)
      @importer = importer
      @fields = fields
    end

    def call(path, **video) = @importer.call(path, **@fields, **video)
  end
end
