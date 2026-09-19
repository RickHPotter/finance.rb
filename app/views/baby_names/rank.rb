# frozen_string_literal: true

class Views::BabyNames::Rank < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::LinkTo

  attr_reader :flow, :names, :current_user

  def initialize(flow:, names:, current_user:)
    @flow = flow
    @names = names
    @current_user = current_user
  end

  def view_template
    main(
      class: "relative mx-auto flex min-h-dvh w-full max-w-lg flex-col overflow-hidden bg-linear-to-b from-blue-950 via-slate-950 to-slate-900 " \
             "px-4 pb-[max(1rem,env(safe-area-inset-bottom))] pt-[max(1rem,env(safe-area-inset-top))] sm:px-6"
    ) do
      decorative_background

      if flow.current_phase == "completed"
        results_view
      elsif flow.phase_completed?
        waiting_partner_view
      else
        ranking_form_view
      end
    end
  end

  private

  def decorative_background
    div(class: "pointer-events-none absolute -left-24 top-24 size-64 rounded-full bg-blue-500/10 blur-3xl")
    div(class: "pointer-events-none absolute -right-24 bottom-20 size-72 rounded-full bg-amber-300/10 blur-3xl")
  end

  def ranking_form_view
    header(class: "relative z-10 shrink-0") do
      div(class: "flex items-center justify-between") do
        link_to(review_baby_names_path, class: "flex size-11 items-center justify-center rounded-full bg-white/10 text-xl text-white backdrop-blur active:scale-95",
                                        aria_label: I18n.t("baby_names.review.button")) do
          "‹"
        end

        div(class: "text-center") do
          h1(class: "text-lg font-bold tracking-tight text-white") { I18n.t("baby_names.rank.#{flow.current_phase}.title") }
          p(class: "mt-0.5 text-xs text-slate-400 max-w-xs") { I18n.t("baby_names.rank.#{flow.current_phase}.subtitle") }
        end

        div(class: "size-11")
      end

      if flow.current_phase == "phase3"
        div(class: "mt-3 rounded-xl border border-amber-400/30 bg-amber-500/10 px-3.5 py-2 text-center text-xs font-semibold text-amber-200") do
          I18n.t("baby_names.rank.phase3.quota", n: flow.calculate_n)
        end
      end
    end

    form_with(url: rank_baby_names_path, method: :post, class: "relative z-10 mt-4 flex flex-1 flex-col overflow-hidden",
              data: { controller: "baby-name-sort" }) do |form|
      div(class: "flex-1 overflow-y-auto space-y-2.5 pb-6 pr-1", data: { baby_name_sort_target: "list" }) do
        names.each do |baby_name|
          name_sort_card(baby_name)
        end
      end

      div(class: "pt-2 shrink-0") do
        form.submit I18n.t("baby_names.rank.save"),
                    class: "w-full rounded-2xl bg-white px-6 py-4 text-base font-bold text-slate-900 shadow-xl transition active:scale-[0.98]"
      end
    end
  end

  def name_sort_card(baby_name)
    div(
      class: "flex items-center justify-between rounded-2xl border border-white/10 bg-white/5 p-3.5 backdrop-blur transition cursor-grab active:cursor-grabbing",
      draggable: "true",
      data: {
        baby_name_sort_target: "item",
        action: "dragstart->baby-name-sort#dragStart dragover->baby-name-sort#dragOver dragend->baby-name-sort#dragEnd"
      }
    ) do
      input(type: "hidden", name: "name_ids[]", value: baby_name.id)

      div(class: "flex items-center gap-3.5 min-w-0") do
        span(class: "flex size-8 shrink-0 items-center justify-center rounded-xl bg-white/10 text-xs font-bold text-slate-300",
             data: { baby_name_sort_target: "badge" }) do
          "#"
        end
        h2(class: "font-garamond text-xl font-bold tracking-tight text-white truncate") { baby_name.name }
      end

      div(class: "flex items-center gap-1.5 shrink-0") do
        button(type: "button",
               class: "flex size-8 items-center justify-center rounded-lg bg-white/10 text-sm text-slate-300 hover:bg-white/20 active:scale-95",
               data: { action: "click->baby-name-sort#moveUp" },
               aria_label: "Move up") { "▲" }
        button(type: "button",
               class: "flex size-8 items-center justify-center rounded-lg bg-white/10 text-sm text-slate-300 hover:bg-white/20 active:scale-95",
               data: { action: "click->baby-name-sort#moveDown" },
               aria_label: "Move down") { "▼" }
      end
    end
  end

  def waiting_partner_view
    section(class: "relative z-10 flex flex-1 flex-col items-center justify-center px-5 text-center") do
      div(class: "flex size-24 items-center justify-center rounded-full bg-blue-500/15 text-5xl") { "⏳" }
      h2(class: "mt-7 font-garamond text-4xl font-bold text-white") { I18n.t("baby_names.rank.waiting_partner_title") }
      p(class: "mt-4 max-w-sm leading-relaxed text-slate-300") do
        I18n.t("baby_names.rank.waiting_partner_body")
      end
      div(class: "mt-8 flex flex-col gap-3 w-full max-w-xs") do
        link_to(I18n.t("baby_names.review.button"), review_baby_names_path,
                class: "w-full rounded-2xl border border-white/20 bg-white/10 px-6 py-3 font-semibold text-white backdrop-blur active:scale-95")
        link_to(I18n.t("baby_names.finished.back"), root_path,
                class: "w-full rounded-2xl bg-white px-6 py-3 font-bold text-slate-900 active:scale-95")
      end
    end
  end

  def results_view
    section(class: "relative z-10 flex flex-1 flex-col overflow-hidden") do
      header(class: "shrink-0 text-center pt-2 pb-4") do
        div(class: "mx-auto flex size-16 items-center justify-center rounded-full bg-emerald-400/20 text-3xl mb-3") { "🎉" }
        h1(class: "font-garamond text-3xl font-bold text-white") { I18n.t("baby_names.rank.completed.title") }
        p(class: "mt-1 text-xs text-slate-400") { I18n.t("baby_names.rank.completed.subtitle") }
      end

      div(class: "flex-1 overflow-y-auto space-y-3 pb-6 pr-1") do
        flow.final_rankings.each_with_index do |item, index|
          result_card(item, index + 1)
        end
      end

      div(class: "pt-2 shrink-0") do
        link_to(I18n.t("baby_names.finished.back"), root_path,
                class: "block w-full text-center rounded-2xl bg-white px-6 py-3.5 font-bold text-slate-900 active:scale-95")
      end
    end
  end

  def result_card(item, rank)
    medal = case rank
            when 1 then "🥇"
            when 2 then "🥈"
            when 3 then "🥉"
            else "##{rank}"
            end

    user_pos = item[:user_position] ? "##{item[:user_position]}" : "-"
    partner_pos = item[:partner_position] ? "##{item[:partner_position]}" : "-"

    div(class: "flex items-center justify-between rounded-2xl border border-white/10 bg-white/5 p-4 backdrop-blur") do
      div(class: "flex items-center gap-3.5 min-w-0") do
        span(class: "text-2xl shrink-0") { medal }
        div(class: "min-w-0") do
          h2(class: "font-garamond text-2xl font-bold text-white truncate") { item[:baby_name].name }
          p(class: "mt-0.5 text-xs text-slate-300") do
            "#{item[:user_name]}: #{user_pos} · #{item[:partner_name]}: #{partner_pos}"
          end
        end
      end

      div(class: "text-right shrink-0 pl-3") do
        p(class: "text-2xs font-semibold uppercase tracking-wider text-slate-400") do
          I18n.t("baby_names.rank.completed.score_label")
        end
        p(class: "text-lg font-bold tabular-nums text-emerald-300") do
          I18n.t("baby_names.rank.completed.points", count: item[:score])
        end
      end
    end
  end
end
