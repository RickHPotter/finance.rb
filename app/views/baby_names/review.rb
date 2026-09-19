# frozen_string_literal: true

class Views::BabyNames::Review < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::LinkTo

  attr_reader :names, :user_decisions, :current_filter, :current_user

  def initialize(names:, user_decisions:, current_filter:, current_user:)
    @names = names
    @user_decisions = user_decisions
    @current_filter = current_filter
    @current_user = current_user
  end

  def view_template
    main(
      class: "relative mx-auto flex min-h-dvh w-full max-w-lg flex-col overflow-hidden bg-linear-to-b from-blue-950 via-slate-950 to-slate-900 " \
             "px-4 pb-[max(1rem,env(safe-area-inset-bottom))] pt-[max(1rem,env(safe-area-inset-top))] sm:px-6"
    ) do
      decorative_background
      render_header
      filter_tabs
      names_list
    end
  end

  private

  def decorative_background
    div(class: "pointer-events-none absolute -left-24 top-24 size-64 rounded-full bg-blue-500/10 blur-3xl")
    div(class: "pointer-events-none absolute -right-24 bottom-20 size-72 rounded-full bg-amber-300/10 blur-3xl")
  end

  def render_header
    header(class: "relative z-10 shrink-0") do
      div(class: "flex items-center justify-between") do
        link_to(baby_names_path, class: "flex size-11 items-center justify-center rounded-full bg-white/10 text-xl text-white backdrop-blur active:scale-95",
                                 aria_label: I18n.t("baby_names.review.back")) do
          "‹"
        end

        h1(class: "text-lg font-bold tracking-tight text-white") { I18n.t("baby_names.review.title") }

        div(class: "size-11")
      end
    end
  end

  def filter_tabs
    nav(class: "relative z-10 mt-4 flex gap-1.5 rounded-2xl border border-white/10 bg-white/5 p-1.5 backdrop-blur", aria_label: "Filter names") do
      filter_pill("all", I18n.t("baby_names.review.all"))
      filter_pill("accepted", I18n.t("baby_names.review.accepted"))
      filter_pill("rejected", I18n.t("baby_names.review.rejected"))
      filter_pill("later", I18n.t("baby_names.review.later"))
    end
  end

  def filter_pill(filter_key, label)
    active = current_filter == filter_key
    classes = if active
                "flex-1 rounded-xl bg-white py-2 text-center text-xs font-bold text-slate-900 shadow-sm transition"
              else
                "flex-1 rounded-xl py-2 text-center text-xs font-semibold text-slate-300 hover:bg-white/10 transition active:scale-95"
              end

    url = filter_key == "all" ? review_baby_names_path : review_baby_names_path(filter: filter_key)
    link_to(url, class: classes) { label }
  end

  def names_list
    section(class: "relative z-10 mt-4 flex-1 overflow-y-auto space-y-3 pb-8", aria_label: "Names list") do
      if names.empty?
        empty_state
      else
        names.each do |baby_name|
          name_row(baby_name)
        end
      end
    end
  end

  def name_row(baby_name)
    decision = user_decisions[baby_name.id]
    current_choice = decision&.choice

    article(class: "rounded-2xl border border-white/10 bg-white/5 p-4 backdrop-blur transition") do
      div(class: "flex items-center justify-between") do
        h2(class: "font-garamond text-2xl font-bold tracking-tight text-white") { baby_name.name }
        status_badge(current_choice)
      end

      div(class: "mt-3 grid grid-cols-3 gap-2") do
        decision_button(baby_name, "rejected", I18n.t("baby_names.actions.rejected"), current_choice == "rejected", "rose")
        decision_button(baby_name, "later", I18n.t("baby_names.actions.later"), current_choice == "later", "slate")
        decision_button(baby_name, "accepted", I18n.t("baby_names.actions.accepted"), current_choice == "accepted", "emerald")
      end
    end
  end

  def status_badge(choice)
    case choice
    when "accepted"
      span(class: "inline-flex items-center gap-1 rounded-full bg-emerald-500/20 px-2.5 py-1 text-xs font-semibold text-emerald-300 border border-emerald-500/30") do
        plain "♥ #{I18n.t('baby_names.review.accepted')}"
      end
    when "rejected"
      span(class: "inline-flex items-center gap-1 rounded-full bg-rose-500/20 px-2.5 py-1 text-xs font-semibold text-rose-300 border border-rose-500/30") do
        plain "✕ #{I18n.t('baby_names.review.rejected')}"
      end
    when "later"
      span(class: "inline-flex items-center gap-1 rounded-full bg-amber-500/20 px-2.5 py-1 text-xs font-semibold text-amber-300 border border-amber-500/30") do
        plain I18n.t("baby_names.review.later")
      end
    else
      span(class: "inline-flex items-center gap-1 rounded-full bg-white/10 px-2.5 py-1 text-xs font-medium text-slate-400") do
        plain I18n.t("baby_names.review.unreviewed")
      end
    end
  end

  def decision_button(baby_name, choice, label, is_active, color)
    active_style = is_active ? "ring-2 ring-white/60 font-bold" : "opacity-75 hover:opacity-100"
    color_classes = case color
                    when "rose"
                      "bg-rose-500/20 text-rose-200 border-rose-400/30 hover:bg-rose-500/30"
                    when "emerald"
                      "bg-emerald-500/20 text-emerald-200 border-emerald-400/30 hover:bg-emerald-500/30"
                    else
                      "bg-white/10 text-slate-300 border-white/15 hover:bg-white/15"
                    end

    form_with(url: baby_name_decision_path(baby_name), method: :post) do |f|
      f.hidden_field :choice, value: choice
      f.hidden_field :return_to, value: "review"
      f.hidden_field :filter, value: current_filter unless current_filter == "all"
      f.submit label, class: "w-full rounded-xl border py-2 text-xs font-semibold transition active:scale-95 #{color_classes} #{active_style}"
    end
  end

  def empty_state
    div(class: "py-16 text-center text-slate-400") do
      p(class: "text-sm") { I18n.t("baby_names.review.empty") }
    end
  end
end
