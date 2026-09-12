# frozen_string_literal: true

class Views::Ledgers::Header < Views::Base
  include Phlex::Rails::Helpers::AssetPath
  include Phlex::Rails::Helpers::ImageTag

  attr_reader :presentation

  def initialize(header:)
    @presentation = header
  end

  def view_template
    header(class: "mb-5 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm dark:border-slate-800 dark:bg-slate-900") do
      div(class: "flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between") do
        div(class: "flex min-w-0 items-center gap-3") do
          image_tag(
            asset_path("avatars/#{presentation.entity_avatar_name}"),
            alt: "",
            class: "size-12 shrink-0 rounded-full border border-slate-200 bg-white object-cover dark:border-slate-700"
          )
          div(class: "min-w-0 text-left") do
            p(class: "text-xs font-semibold uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400") do
              I18n.t(presentation.external? ? "ledgers.external.eyebrow" : "ledgers.internal.eyebrow")
            end
            h1(class: "truncate text-xl font-bold text-slate-950 dark:text-white") { presentation.entity_name }
            p(class: "truncate text-sm text-slate-600 dark:text-slate-300") { presentation.owner_name }
          end
        end

        div(class: "grid grid-cols-2 gap-2 text-left text-xs sm:text-right") do
          identity_item(I18n.t("ledgers.header.scope"), presentation.context_name)
          identity_item(I18n.t("ledgers.header.updated"), formatted_updated_at)
        end
      end
    end
  end

  private

  def identity_item(label, value)
    div(class: "rounded-lg bg-slate-50 px-3 py-2 dark:bg-slate-950") do
      p(class: "font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400") { label }
      p(class: "mt-1 font-medium text-slate-900 dark:text-slate-100") { value }
    end
  end

  def formatted_updated_at
    return I18n.t("ledgers.header.never") unless presentation.last_updated_at

    I18n.l(presentation.last_updated_at, format: :short)
  end
end
