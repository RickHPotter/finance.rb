# frozen_string_literal: true

class Views::Static::Notification < Views::Base
  def view_template
    turbo_frame_tag(
      :notification,
      class: "fixed inset-x-0 bottom-0 z-50 flex flex-col gap-3 px-4 py-6 pointer-events-none
              sm:inset-x-auto sm:bottom-auto sm:right-0 sm:top-0 sm:w-full sm:max-w-md sm:items-end sm:p-6 sm:pt-16".squish
    ) do
      render partial "shared/flash", alert: params[:alert], notice: params[:notice]
    end
  end
end
