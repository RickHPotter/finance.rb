# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuditVersion, type: :model do
  let(:operation) { AuditOperation.create!(source: :web, result: :committed) }
  let(:snapshot) do
    {
      "id" => 91,
      "installment_type" => "CashInstallment",
      "number" => 1,
      "date" => "2026-07-19T15:30:00.000Z",
      "month" => 7,
      "year" => 2026,
      "price" => 5_000,
      "starting_price" => 5_000,
      "paid" => false,
      "balance" => nil,
      "cash_installments_count" => 1,
      "card_installments_count" => 0
    }
  end
  let(:changeset) do
    {
      "price" => [ 4_000, 5_000 ],
      "paid" => [ false, true ],
      "balance" => [ nil, 500 ]
    }
  end
  let(:version_attributes) do
    {
      item_type: "Installment",
      item_subtype: "CashInstallment",
      item_id: snapshot.fetch("id"),
      event: :destroy,
      operation:,
      owner_id: 17,
      context_id: 23,
      mutation_source: :web,
      object: snapshot,
      object_changes: changeset,
      metadata: { "route" => "cash_transactions#destroy" }
    }
  end
  subject(:version) { described_class.create!(version_attributes) }

  describe "[ PaperTrail contract ]" do
    it "uses the custom version class without retention pruning" do
      expect(PaperTrail.config.has_paper_trail_defaults.dig(:versions, :class_name)).to eq("AuditVersion")
      expect(PaperTrail.config.has_paper_trail_defaults.dig(:versions, :autosave)).to be(false)
      expect(PaperTrail.config.version_error_behavior).to eq(:exception)
      expect(PaperTrail.config.version_limit).to be_nil
    end

    it "round trips typed JSONB snapshots and changesets" do
      persisted_version = version.reload

      expect(persisted_version.object).to include(
        "price" => 5_000,
        "paid" => false,
        "balance" => nil,
        "date" => "2026-07-19T15:30:00.000Z"
      )
      expect(persisted_version.object_changes).to eq(changeset)
      expect(persisted_version.changeset).to eq(changeset.with_indifferent_access)
    end

    it "reifies the stored installment subtype and casts its attributes" do
      installment = version.reify

      expect(installment).to be_a(CashInstallment)
      expect(installment.installment_type).to eq("CashInstallment")
      expect(installment.price).to eq(5_000)
      expect(installment.paid).to be(false)
      expect(installment.balance).to be_nil
      expect(installment.date).to eq(Time.zone.parse("2026-07-19 15:30:00 UTC"))
      expect(installment.version).to eq(version)
    end

    it "reifies card installments from their stored subtype" do
      card_version = described_class.create!(
        version_attributes.merge(
          item_subtype: "CardInstallment",
          object: snapshot.merge("installment_type" => "CardInstallment")
        )
      )

      expect(card_version.reify).to be_a(CardInstallment)
    end

    it "enables installment graph recording with derived fields excluded" do
      expect(Installment.paper_trail_options.fetch(:on)).to match_array(%i[create update destroy])
      expect(Installment.paper_trail_options.fetch(:skip)).to include("balance", "order_id", "cash_installments_count", "card_installments_count")
    end

    it "does not create synthetic versions for records that predate deployment" do
      transaction = PaperTrail.request(enabled: false) { create(:cash_transaction) }

      expect(described_class.where(item: transaction)).to be_empty
    end
  end

  describe "[ validation and transaction contract ]" do
    it "rejects unowned financial versions" do
      invalid_version = described_class.new(version_attributes.except(:owner_id))

      expect(invalid_version).not_to be_valid
      expect(invalid_version.errors).to include(:owner_id)
    end

    it "rejects oversized JSON payloads" do
      invalid_version = described_class.new(version_attributes.merge(object: { "value" => "a" * 257.kilobytes }))

      expect(invalid_version).not_to be_valid
      expect(invalid_version.errors).to include(:object)
    end

    it "aborts the surrounding business transaction when audit persistence fails" do
      expect do
        expect do
          User.transaction do
            User.create!(
              first_name: "Audit",
              last_name: "Rollback",
              locale: :en,
              email: "audit-rollback@example.com",
              password: "123123",
              password_confirmation: "123123",
              confirmed_at: Time.zone.today
            )
            described_class.create!(version_attributes.except(:owner_id))
          end
        end.to raise_error(ActiveRecord::RecordInvalid)
      end.not_to change(User, :count)
    end
  end

  describe "[ append-only contract ]" do
    it "rejects updates and destruction through Active Record" do
      expect { version.update!(mutation_source: :import) }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { version.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "rejects direct SQL updates" do
      version

      expect { described_class.where(id: version.id).update_all(mutation_source: "import") }
        .to raise_error(ActiveRecord::StatementInvalid, /audit_versions is append-only/)
    end

    it "rejects direct SQL deletes" do
      version

      expect { described_class.where(id: version.id).delete_all }
        .to raise_error(ActiveRecord::StatementInvalid, /audit_versions is append-only/)
    end
  end
end

# == Schema Information
#
# Table name: audit_versions
# Database name: primary
#
#  id              :bigint           not null, primary key, indexed => [operation_id]
#  event           :string           not null, indexed => [created_at]
#  item_subtype    :string
#  item_type       :string           not null, indexed => [item_id, created_at]
#  metadata        :jsonb            not null
#  mutation_source :string           not null, indexed => [created_at]
#  object          :jsonb
#  object_changes  :jsonb
#  whodunnit       :string
#  created_at      :datetime         not null, indexed => [context_id], indexed => [event], indexed => [item_type, item_id], indexed => [mutation_source], indexed => [owner_id]
#  context_id      :bigint           indexed => [created_at]
#  item_id         :bigint           not null, indexed => [item_type, created_at]
#  operation_id    :uuid             not null, indexed => [id]
#  owner_id        :bigint           not null, indexed => [created_at]
#
# Indexes
#
#  index_audit_versions_on_context_id_and_created_at             (context_id,created_at)
#  index_audit_versions_on_event_and_created_at                  (event,created_at)
#  index_audit_versions_on_item_type_and_item_id_and_created_at  (item_type,item_id,created_at)
#  index_audit_versions_on_mutation_source_and_created_at        (mutation_source,created_at)
#  index_audit_versions_on_operation_id_and_id                   (operation_id,id)
#  index_audit_versions_on_owner_id_and_created_at               (owner_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (operation_id => audit_operations.id) ON DELETE => restrict
#
