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
        action: "turbo:submit-start->form-loading#start turbo:submit-end->form-loading#stop"
      }
    ) do
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
end
