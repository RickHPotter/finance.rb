# frozen_string_literal: true

module NavigationContractHelpers
  def html_headers
    { "ACCEPT" => Mime[:html].to_s }
  end

  def turbo_frame_headers(frame_id)
    turbo_stream_headers.merge("TURBO_FRAME" => frame_id)
  end
end

RSpec.shared_examples "a canonical top-level mutation redirect" do
  it "redirects with 303 to an HTML GET destination" do
    perform_request

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(expected_destination)

    follow_redirect!(headers: html_headers)

    expect(response).to have_http_status(:success)
    expect(response.media_type).to eq(Mime[:html].to_s)
    expect(response.body).not_to include("<turbo-stream")
  end
end

RSpec.shared_examples "a canonical top-level validation failure" do
  it "returns 422 without redirecting away from the form resource" do
    perform_request

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.location).to be_nil
    expect(response.body).to include(expected_form_marker) if respond_to?(:expected_form_marker)
  end
end

RSpec.shared_examples "a bounded Turbo response" do
  it "does not send a full application document into the frame" do
    perform_request

    expect(response).to have_http_status(expected_status)
    expect(response.body).not_to match(/<!doctype|<html/i)
    expect(response.body).to include(expected_target)
  end
end

RSpec.configure do |config|
  config.include NavigationContractHelpers, type: :request
end
