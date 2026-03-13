# frozen_string_literal: true

class NamingConventionsController < ApplicationController
  def preview
    @results = naming_results(dry_run: true)

    render Views::NamingConventions::Result.new(results: @results, dry_run: true)
  end

  def update
    @results = naming_results(dry_run: false)

    respond_to do |format|
      format.html { render Views::NamingConventions::Result.new(results: @results, dry_run: false) }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(:naming_convention_content, Views::NamingConventions::Result.new(results: @results, dry_run: false)),
          turbo_stream.update(:notification, partial: "shared/flash", locals: flash_payload)
        ]
      end
    end
  end

  private

  def flash_payload
    changed_count = @results.count { |result| result[:changes].present? }

    if changed_count.zero?
      { notice: I18n.t("naming_conventions.no_changes_needed") }
    else
      { notice: I18n.t("naming_conventions.updated", count: changed_count) }
    end
  end

  def naming_results(dry_run:)
    Linter::NamingService.new(cash_transactions: naming_scope, user: current_user, dry_run:).call
  end

  def naming_scope
    current_user.cash_transactions.includes(
      :user,
      :categories,
      :investments,
      :card_installments,
      exchanges: { entity_transaction: :transactable }
    )
  end
end
