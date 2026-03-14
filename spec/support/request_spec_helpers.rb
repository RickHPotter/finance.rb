# frozen_string_literal: true

module RequestSpecHelpers
  def turbo_stream_headers
    { "ACCEPT" => Mime[:turbo_stream].to_s }
  end
end
