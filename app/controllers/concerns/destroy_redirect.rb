# Sends the browser back to the page a delete came from, unless that page
# belonged to the deleted record. Then it goes to the record's parent page.
module DestroyRedirect
  extend ActiveSupport::Concern

  private

  def redirect_after_destroy(deleted_path, parent:, notice:)
    if referred_from?(deleted_path)
      redirect_to parent, notice: notice
    else
      redirect_back_or_to parent, notice: notice
    end
  end

  def referred_from?(path)
    referer_path = URI(request.referer.to_s).path
    referer_path == path || referer_path.start_with?("#{path}/")
  rescue URI::InvalidURIError
    false
  end
end
