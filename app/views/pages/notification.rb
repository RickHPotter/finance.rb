# frozen_string_literal: true

class Views::Pages::Notification < Views::Base
  def view_template
    turbo_frame_tag(:notification) do
      render partial "shared/flash", alert: params[:alert], notice: params[:notice]
    end
  end
end
