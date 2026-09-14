# frozen_string_literal: true

class Views::Ledgers::RateLimited < Views::Base
  attr_reader :frame_id

  def initialize(frame_id: nil)
    @frame_id = frame_id
  end

  def view_template
    if frame_id
      turbo_frame_tag(frame_id) { message(compact: true) }
    else
      message
    end
  end

  private

  def message(compact: false)
    section(class: container_classes(compact:)) do
      h1(class: "text-xl font-bold text-slate-950 dark:text-white") { I18n.t("ledgers.rate_limited.title") }
      p(class: "mt-2 text-sm text-slate-600 dark:text-slate-300") { I18n.t("ledgers.rate_limited.description") }
    end
  end

  def container_classes(compact:)
    spacing = compact ? "my-5 px-4 py-6" : "mx-auto mt-16 max-w-lg px-6 py-12"
    "#{spacing} rounded-2xl border border-amber-200 bg-amber-50 text-center shadow-sm " \
      "dark:border-amber-900/70 dark:bg-amber-950/30"
  end
end
