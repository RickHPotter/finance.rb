# frozen_string_literal: true

class ReferenceMerges::ReallocationPlan
  Issue = Data.define(:code, :details)
  Bucket = Data.define(
    :source_date,
    :destination_date,
    :installment_ids,
    :exchange_ids,
    :source_invoice_ids,
    :destination_invoice_id,
    :destination_reference_id
  ) do
    def occupied?
      installment_ids.present? || exchange_ids.present?
    end

    def destination_reference_required?
      occupied? && destination_reference_id.nil?
    end

    def destination_invoice_required?
      installment_ids.present? && destination_invoice_id.nil?
    end
  end

  attr_reader :user_card, :context, :source_date, :target_date, :buckets, :issues, :lock_keys, :state_rows

  def initialize(user_card:, context:, source_date:, target_date:, buckets:, issues:, lock_keys:, state_rows:)
    @user_card = user_card
    @context = context
    @source_date = source_date
    @target_date = target_date
    @buckets = buckets.freeze
    @issues = issues.freeze
    @lock_keys = lock_keys.freeze
    @state_rows = state_rows.freeze
  end

  def eligible?
    issues.empty?
  end

  def conflict?
    !eligible?
  end

  def installment_ids
    buckets.flat_map(&:installment_ids).uniq.sort
  end

  def exchange_ids
    buckets.flat_map(&:exchange_ids).uniq.sort
  end

  def earliest_affected_date
    buckets.find(&:occupied?)&.source_date
  end

  def latest_affected_date
    buckets.rfind(&:occupied?)&.source_date
  end

  def tail_date
    latest_affected_date&.next_month
  end

  def digest
    @digest ||= Digest::SHA256.hexdigest(Audit::Rollback::State.canonical_json(digest_payload))
  end

  private

  def digest_payload
    {
      user_card_id: user_card.id,
      context_id: context.id,
      source_date: source_date&.iso8601,
      target_date: target_date&.iso8601,
      issues: issues.map { |issue| { code: issue.code, details: issue.details } },
      buckets: buckets.map do |bucket|
        {
          source_date: bucket.source_date.iso8601,
          destination_date: bucket.destination_date.iso8601,
          installment_ids: bucket.installment_ids,
          exchange_ids: bucket.exchange_ids,
          source_invoice_ids: bucket.source_invoice_ids,
          destination_invoice_id: bucket.destination_invoice_id,
          destination_reference_id: bucket.destination_reference_id
        }
      end,
      lock_keys:,
      state_rows:
    }
  end
end
