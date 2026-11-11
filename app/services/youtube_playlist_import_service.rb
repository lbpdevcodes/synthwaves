class YoutubePlaylistImportService
  class Error < StandardError; end

  def self.call(url, api_key:, user:, category: "music")
    new(url, category: category, api_key: api_key, user: user).call
  end

  def initialize(url, api_key:, user:, category: "music")
    @url = url
    @category = category
    @api_key = api_key
    @user = user
    @playlist_id = YoutubeUrlParser.extract_playlist_id(url)
    raise Error, "Invalid YouTube playlist URL" if @playlist_id.blank?
  end

  # Returns a YoutubeImport, or nil when the playlist holds no videos.
  def call
    playlist_info, items = fetch_playlist_data
    return nil if items.empty?

    filing = filing_for(playlist_info)
    YoutubeImport.new(title: playlist_info[:title], tracks: items.map { |item| filing.file(item) })
  end

  private

  def filing_for(playlist_info)
    filing = (@category == "podcast") ? YoutubePodcastFiling : YoutubeMusicFiling
    filing.new(user: @user, url: @url, playlist_info: playlist_info)
  end

  def fetch_playlist_data
    if @api_key.present?
      fetch_playlist_data_via_api
    else
      fetch_playlist_data_via_ytdlp
    end
  end

  def fetch_playlist_data_via_api
    api = YoutubeAPIService.new(api_key: @api_key)

    playlist_info = api.fetch_playlist_info(@playlist_id)
    playlist_items = api.fetch_playlist_items(@playlist_id)

    video_ids = playlist_items.map { |item| item[:video_id] }
    video_details = api.fetch_video_details(video_ids)
    details_by_id = video_details.index_by { |v| v[:video_id] }

    items = playlist_items.map do |item|
      details = details_by_id[item[:video_id]] || {}
      {
        video_id: item[:video_id],
        title: item[:title],
        position: item[:position],
        duration: details[:duration],
        channel_name: details[:channel_name],
        description: details[:description]
      }
    end

    [playlist_info, items]
  end

  def fetch_playlist_data_via_ytdlp
    metadata = MediaDownloadService.fetch_playlist_metadata(@url)

    playlist_info = {
      title: metadata[:title],
      channel_name: metadata[:channel_name],
      thumbnail_url: metadata[:thumbnail_url]
    }

    [playlist_info, metadata[:entries]]
  end
end
