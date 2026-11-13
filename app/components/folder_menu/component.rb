module FolderMenu
  # A video's folder menu: move it into one of the owner's folders, into a
  # folder named in place, or out of the folder it is in. folders is the
  # owner's FolderTree, which lists them in order and labels each by path.
  class Component < ViewComponent::Base
    def initialize(video:, folders:)
      @video = video
      @folders = folders
    end

    private

    attr_reader :video, :folders

    def current?(folder)
      folder.id == video.folder_id
    end

    def current_folder
      folders.find { |folder| current?(folder) }
    end

    def item_classes
      "block w-full text-left px-4 py-2 text-sm text-white hover:bg-gray-700 hover:text-neon-cyan truncate"
    end
  end
end
