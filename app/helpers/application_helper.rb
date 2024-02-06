# frozen_string_literal: true

# God Helper
module ApplicationHelper
  def notice_stream
    turbo_stream.append(:notification, partial: "shared/flash")
  end
end
