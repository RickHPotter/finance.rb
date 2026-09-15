# frozen_string_literal: true

class Views::BabyNames::Index < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::LinkTo

  attr_reader :baby_name, :stats, :total, :current_user

  def initialize(baby_name:, stats:, total:, current_user:)
    @baby_name = baby_name
    @stats = stats
    @total = total
    @current_user = current_user
  end

  def view_template
    main(
      class: "relative mx-auto flex min-h-dvh w-full max-w-lg flex-col overflow-hidden bg-linear-to-b from-blue-950 via-slate-950 to-slate-900 " \
             "px-4 pb-[max(1rem,env(safe-area-inset-bottom))] pt-[max(1rem,env(safe-area-inset-top))] sm:px-6",
      data: swipe_controller_data
    ) do
      decorative_background
      render_header

      if baby_name
        name_card
        actions
      else
        finished_state
      end
    end
  end

  private

  def swipe_controller_data
    return {} unless baby_name

    {
      controller: "baby-name-swipe",
      baby_name_swipe_timeout_value: 20_000,
      baby_name_swipe_later_label_value: I18n.t("baby_names.actions.later"),
      action: "keydown.left@window->baby-name-swipe#reject keydown.right@window->baby-name-swipe#accept keydown.down@window->baby-name-swipe#later"
    }
  end

  def decorative_background
    div(class: "pointer-events-none absolute -left-24 top-24 size-64 rounded-full bg-blue-500/10 blur-3xl")
    div(class: "pointer-events-none absolute -right-24 bottom-20 size-72 rounded-full bg-amber-300/10 blur-3xl")
  end

  def render_header
    header(class: "relative z-10 shrink-0") do
      div(class: "flex items-center justify-between") do
        link_to(root_path, class: "flex size-11 items-center justify-center rounded-full bg-white/10 text-xl text-white backdrop-blur active:scale-95",
                           aria_label: I18n.t("baby_names.back_to_finance")) do
          "‹"
        end

        div(class: "text-center") do
          p(class: "text-xs font-semibold uppercase tracking-[0.28em] text-blue-200") { I18n.t("baby_names.couple") }
          h1(class: "mt-1 text-lg font-bold tracking-tight") { I18n.t("baby_names.question") }
        end

        div(class: "size-11")
      end

      div(class: "mt-4 grid grid-cols-[1fr_auto_1fr] items-center gap-3 rounded-2xl border border-white/10 bg-white/5 px-4 py-3 backdrop-blur") do
        stat(label: I18n.t("baby_names.stats.rejected"), value: rejected_count, alignment: "text-right", colour: "text-rose-300",
             direction: I18n.t("baby_names.stats.swipe_left"))
        div(class: "text-center") do
          p(class: "text-2xs uppercase tracking-[0.2em] text-slate-400") { I18n.t("baby_names.stats.ratio") }
          p(class: "mt-0.5 text-xl font-bold tabular-nums text-white") { "#{rejected_count} / #{accepted_count}" }
        end
        stat(label: I18n.t("baby_names.stats.accepted"), value: accepted_count, alignment: "text-left", colour: "text-emerald-300",
             direction: I18n.t("baby_names.stats.swipe_right"))
      end

      div(class: "mt-3 flex items-center justify-between px-1 text-xs text-slate-400") do
        span { I18n.t("baby_names.stats.progress", decided: decided_count, total:) }
        span { I18n.t("baby_names.stats.later", count: later_count) }
      end
    end
  end

  def stat(label:, value:, alignment:, colour:, direction:)
    div(class: alignment) do
      p(class: "text-2xs font-semibold uppercase tracking-[0.18em] text-slate-500") { label }
      p(class: "sr-only") { value.to_s }
      p(class: "mt-0.5 text-sm font-semibold #{colour}") { direction }
    end
  end

  def name_card
    section(class: "relative z-10 flex min-h-0 flex-1 items-center justify-center py-4") do
      article(
        class: "relative flex aspect-[4/5] max-h-[52dvh] w-full touch-none select-none flex-col items-center justify-center overflow-hidden rounded-[2rem] " \
               "border border-white/20 bg-linear-to-br from-white via-blue-50 to-amber-50 px-6 text-center text-slate-900 shadow-2xl " \
               "shadow-black/40 will-change-transform",
        data: {
          baby_name_swipe_target: "card",
          action: "pointerdown->baby-name-swipe#start pointermove->baby-name-swipe#move pointerup->baby-name-swipe#end pointercancel->baby-name-swipe#cancel"
        }
      ) do
        div(class: "absolute inset-x-8 top-8 flex justify-between") do
          choice_stamp(I18n.t("baby_names.card.rejected_stamp"), "rejectStamp", "-rotate-12 border-rose-500 text-rose-500")
          choice_stamp(I18n.t("baby_names.card.accepted_stamp"), "acceptStamp", "rotate-12 border-emerald-500 text-emerald-600")
        end

        p(class: "text-xs font-semibold uppercase tracking-[0.35em] text-blue-500") { I18n.t("baby_names.card.greeting") }
        h2(class: "mt-4 font-garamond text-6xl font-bold tracking-tight sm:text-7xl") { baby_name.name }
        div(class: "mt-5 h-px w-12 bg-amber-400")
        p(class: "mt-5 max-w-64 text-sm leading-relaxed text-slate-500") { I18n.t("baby_names.card.story") }
        p(class: "absolute bottom-6 text-2xs font-semibold uppercase tracking-[0.22em] text-slate-400") { I18n.t("baby_names.card.hint") }
      end
    end
  end

  def choice_stamp(text, target, classes)
    span(class: "rounded-lg border-4 px-3 py-1 text-xl font-black opacity-0 #{classes}", data: { baby_name_swipe_target: target }) { text }
  end

  def actions
    section(class: "relative z-10 shrink-0", aria_label: I18n.t("baby_names.actions.label")) do
      div(class: "grid grid-cols-2 gap-3") do
        decision_form("rejected", "rejectForm") do |form|
          form.submit I18n.t("baby_names.actions.rejected"),
                      class: "min-h-16 w-full rounded-2xl border border-rose-400/30 bg-rose-500/15 px-6 text-lg font-bold text-rose-200 " \
                             "transition active:scale-95 active:bg-rose-500/30",
                      data: { action: "click->baby-name-swipe#choose", direction: "left" }
        end

        decision_form("accepted", "acceptForm") do |form|
          form.submit I18n.t("baby_names.actions.accepted"),
                      class: "min-h-16 w-full rounded-2xl border border-emerald-400/30 bg-emerald-500/15 px-6 text-lg font-bold " \
                             "text-emerald-200 transition active:scale-95 active:bg-emerald-500/30",
                      data: { action: "click->baby-name-swipe#choose", direction: "right" }
        end
      end

      decision_form("later", "laterForm", class: "mt-3") do |form|
        form.submit "#{I18n.t('baby_names.actions.later')} · 5.0s",
                    class: "min-h-16 w-full rounded-2xl bg-white/8 px-6 text-base font-semibold text-slate-300 transition active:scale-[0.98] active:bg-white/15",
                    data: { action: "click->baby-name-swipe#choose", direction: "down", baby_name_swipe_target: "laterButton" }
      end
    end
  end

  def decision_form(choice, target, class: nil, &)
    form_with(
      url: baby_name_decision_path(baby_name),
      method: :post,
      class:,
      data: { baby_name_swipe_target: target }
    ) do |form|
      form.hidden_field :choice, value: choice
      yield form
    end
  end

  def finished_state
    section(class: "relative z-10 flex flex-1 flex-col items-center justify-center px-5 text-center") do
      div(class: "flex size-24 items-center justify-center rounded-full bg-emerald-400/15 text-5xl") { "♥" }
      h2(class: "mt-7 font-garamond text-5xl font-bold") { I18n.t("baby_names.finished.title") }
      p(class: "mt-4 max-w-sm leading-relaxed text-slate-300") do
        I18n.t("baby_names.finished.body", count: total)
      end
      link_to(I18n.t("baby_names.finished.back"), root_path, class: "mt-8 rounded-2xl bg-white px-6 py-3 font-bold text-slate-900 active:scale-95")
    end
  end

  def rejected_count
    stats.fetch("rejected", 0)
  end

  def accepted_count
    stats.fetch("accepted", 0)
  end

  def later_count
    stats.fetch("later", 0)
  end

  def decided_count
    rejected_count + accepted_count
  end
end
