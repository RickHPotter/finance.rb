# frozen_string_literal: true

class Views::CardTransactions::FormInstallmentsSection < Views::Base
  attr_reader :form, :card_transaction

  def initialize(form:, card_transaction:)
    @form = form
    @card_transaction = card_transaction
  end

  def view_template
    render Views::Installments::Section.new(
      form:,
      association_name: :card_installments,
      installments: ordered_card_installments,
      record_class: CardInstallment
    )
  end

  private

  def ordered_card_installments
    if card_transaction.new_record?
      card_transaction.card_installments
    elsif card_transaction.edit_phase || card_transaction.errors.any?
      card_transaction.card_installments.sort_by(&:number)
    else
      card_transaction.card_installments.order(:number)
    end
  end
end
