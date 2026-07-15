# frozen_string_literal: true

class Views::Admin::Settings::PiggyBankAudit < Views::Base
  include TranslateHelper

  attr_reader :rows

  def initialize(rows:)
    @rows = rows
  end

  def view_template
    turbo_frame_tag :settings_piggy_bank_audit_content do
      div(class: "space-y-4 text-left text-black dark:text-slate-100") do
        div(class: "rounded-md border border-slate-200 bg-white p-4 dark:border-slate-700 dark:bg-slate-950") do
          h2(class: "text-lg font-bold") { I18n.t("settings.piggy_bank_audit.title") }
          p(class: "mt-1 text-sm text-slate-600 dark:text-slate-400") { I18n.t("settings.piggy_bank_audit.description") }
        end

        if rows.empty?
          empty_class = "rounded-md border border-dashed border-slate-300 bg-white px-4 py-8 text-center text-sm text-slate-500 " \
                        "dark:border-slate-700 dark:bg-slate-950"
          div(class: empty_class) do
            I18n.t("settings.piggy_bank_audit.empty")
          end
        else
          rows.each { |row| audit_row(row) }
        end
      end
    end
  end

  private

  def audit_row(row)
    div(class: "rounded-md border border-rose-200 bg-white p-4 dark:border-rose-900 dark:bg-slate-950") do
      div(class: "flex flex-wrap items-start justify-between gap-2") do
        div do
          h3(class: "font-bold") { row[:id] ? "##{row[:id]} - #{row[:description]}" : row[:description] }
          p(class: "mt-1 text-xs text-slate-500") { I18n.l(row[:date], format: :short) }
        end

        if row[:id]
          a(href: cash_transaction_path(row[:id]), class: "text-sm font-semibold text-sky-700 hover:underline", data: { turbo_frame: "_top" }) do
            I18n.t("settings.piggy_bank_audit.open")
          end
        end
      end

      div(class: "mt-3 flex flex-wrap gap-2") do
        row[:issues].each do |issue|
          span(class: "rounded-full bg-rose-100 px-2 py-1 text-xs font-semibold text-rose-900") do
            I18n.t("settings.piggy_bank_audit.issues.#{issue}")
          end
        end
      end
    end
  end
end
