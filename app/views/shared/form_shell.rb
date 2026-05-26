# frozen_string_literal: true

class Views::Shared::FormShell < Views::Base
  attr_reader :badge_text, :badge_class, :skeleton_view

  def initialize(badge_text: nil, badge_class: nil, skeleton_view: Views::Shared::FormSubmissionSkeleton)
    @badge_text = badge_text
    @badge_class = badge_class
    @skeleton_view = skeleton_view
  end

  def view_template(&)
    div(
      class: "relative rounded-lg bg-white p-4 shadow-md",
      data: {
        controller: "form-loading",
        form_loading_preview_value: skeleton_preview?.to_s,
        action: "turbo:submit-start->form-loading#start turbo:submit-end->form-loading#stop"
      }
    ) do
      skeleton_preview_toggle

      div(data: { form_loading_target: "content" }) do
        span(class: badge_class) { badge_text } if badge_text.present?
        yield
      end

      div(
        class: "absolute inset-0 z-10 hidden rounded-lg bg-white/95 p-4",
        data: { form_loading_target: "skeleton" },
        aria: { hidden: true }
      ) do
        render skeleton_view.new
      end
    end
  end

  private

  def skeleton_preview?
    Rails.env.development? && params[:skeleton].present?
  end

  def skeleton_preview_toggle
    return unless Rails.env.development?

    button(
      type: :button,
      class: "absolute right-3 top-3 z-20 rounded-sm border border-slate-300 bg-white px-2 py-1 text-xs font-semibold text-slate-700 shadow-sm hover:bg-slate-100",
      data: { action: "form-loading#togglePreview" }
    ) { "Toggle skeleton" }
  end
end
