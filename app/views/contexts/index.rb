# frozen_string_literal: true

class Views::Contexts::Index < Views::Base
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper

  attr_reader :contexts, :current_context

  def initialize(contexts:, current_context:)
    @contexts = contexts
    @current_context = current_context
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: "m-1 min-h-[calc(100svh-16rem)] rounded-lg bg-white shadow-md shadow-red-50") do
        div(class: "flex items-start justify-between border-b border-stone-200 px-4 py-3") do
          div(class: "flex flex-col items-start") do
            h1(class: "text-sm font-semibold uppercase tracking-[0.2em] text-stone-700") { action_model(:index, Context, count: 2) }
            render_scenario_badge
          end
        end

        div(class: "border-b border-stone-100 px-3 py-3 md:px-4 space-y-6") do
          render_tree_node(main_context, root: true)
        end
      end

      turbo_frame_tag :context_overlay
    end
  end

  private

  def main_context
    @main_context ||= contexts.find(&:main?)
  end

  def child_contexts_for(context)
    contexts.select { |candidate| candidate.source_context_id == context.id }.sort_by(&:created_at)
  end

  def render_tree_node(context, root: false)
    return if context.nil?

    div(class: root ? "space-y-4" : "ml-4 space-y-4 border-l border-stone-200 pl-4 md:ml-6 md:pl-6") do
      render_context_card(context, root:)
      render_create_child_button(context)

      children = child_contexts_for(context)
      next if children.blank?

      div(class: "space-y-5") do
        children.each do |child_context|
          render_tree_node(child_context)
        end
      end
    end
  end

  def render_context_card(context, root:)
    if root
      div(class: "rounded-3xl border border-sky-300 bg-linear-to-br from-sky-100 via-white to-cyan-50 p-5 shadow-sm") do
        render_context_card_content(context, root:)
      end
      return
    end

    link_to(
      context_path(context),
      class: [
        "block rounded-3xl border p-4 transition",
        if context.archived?
          "border-stone-300 bg-stone-100 opacity-80"
        else
          "border-stone-200 bg-stone-50 hover:border-sky-300 hover:bg-sky-50"
        end
      ].join(" "),
      data: { turbo_frame: :context_overlay, turbo_prefetch: false }
    ) do
      render_context_card_content(context, root:)
    end
  end

  def render_context_card_content(context, root:)
    div(class: "flex items-start justify-between gap-3") do
      div(class: "min-w-0") do
        p(class: "text-xs font-semibold uppercase tracking-[0.2em] #{root ? 'text-sky-700' : 'text-stone-500'}") do
          root ? I18n.t("contexts.index.main_label") : I18n.t("contexts.index.derived_label")
        end
        h2(class: "mt-1 truncate text-lg font-semibold text-stone-900") { context.name }
        p(class: "mt-2 text-sm text-stone-600") { context.description.presence || I18n.t("contexts.index.no_description") }
      end

      if current_context == context
        span(class: "inline-flex rounded-full bg-emerald-500 px-3 py-1 text-2xs font-semibold uppercase tracking-[0.18em] text-white") do
          I18n.t("contexts.index.current")
        end
      elsif context.archived?
        span(class: "inline-flex rounded-full bg-stone-500 px-3 py-1 text-2xs font-semibold uppercase tracking-[0.18em] text-white") do
          I18n.t("contexts.index.archived")
        end
      end
    end
  end

  def render_create_child_button(context)
    return if context.archived?

    div(class: "pl-2") do
      link_to(
        new_context_path(source_context_id: context.id),
        class: "inline-flex size-9 items-center justify-center rounded-full border border-dashed border-sky-400 bg-white text-sky-600 transition hover:bg-sky-50",
        title: I18n.t("contexts.index.create_child"),
        data: { turbo_frame: :context_overlay, turbo_prefetch: false }
      ) do
        "+"
      end
    end
  end
end
