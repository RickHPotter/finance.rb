# frozen_string_literal: true

class HealthCheck::NamingConventionsController < HealthCheck::BaseController
  def preview
    preview = HealthCheck::NamingConventions::Preview.new(scope: health_check_scope)

    render Views::HealthCheck::NamingConventions::Show.new(preview:)
  end

  def update
    result = HealthCheck::NamingConventions::Apply.new(
      scope: health_check_scope,
      request_id: request.request_id,
      token: params[:apply_token],
      confirmed: params[:naming_confirmation]
    ).call

    render Views::HealthCheck::NamingConventions::Show.new(result:), status: response_status(result)
  end

  private

  def response_status(result)
    return :ok if result.applied?
    return :unprocessable_content if result.rejected?

    :internal_server_error
  end
end
