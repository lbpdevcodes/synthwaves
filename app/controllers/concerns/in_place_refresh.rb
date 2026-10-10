# Answers a change made from the page the user is on: a Turbo request gets a
# page refresh, which morphs that page to show the change and its flash; a
# plain form post goes back to where it came from.
#
# The refresh carries no request id. Turbo ignores a refresh whose id matches
# a request it sent itself, and by default turbo-rails stamps the id of the
# request that is being answered.
module InPlaceRefresh
  extend ActiveSupport::Concern

  private

  def respond_in_place(notice, fallback:)
    respond_to do |format|
      format.turbo_stream { refresh_with_notice(notice) }
      format.html { redirect_back_or_to fallback, notice: notice }
    end
  end

  def refresh_with_notice(notice)
    flash[:notice] = notice
    render turbo_stream: turbo_stream.refresh(request_id: nil)
  end
end
