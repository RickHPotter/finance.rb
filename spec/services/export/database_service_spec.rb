# frozen_string_literal: true

require "rails_helper"
RSpec.describe Export::DatabaseService do
  around do |example|
    FileUtils.mkdir_p(Rails.root.join("tmp"))
    FileUtils.rm_f(Dir[Rails.root.join("tmp", "backup_*.sql*").to_s])
    ActionMailer::Base.deliveries.clear

    example.run

    ActionMailer::Base.deliveries.clear
    FileUtils.rm_f(Dir[Rails.root.join("tmp", "backup_*.sql*").to_s])
  end

  let(:dump_sql) do
    <<~SQL
      CREATE TABLE widgets(id integer);
      INSERT INTO widgets(id) VALUES (1);
    SQL
  end
  let(:status) { instance_double(Process::Status, success?: true) }

  before do
    allow(Open3).to receive(:capture3).and_return([ dump_sql, "", status ])
  end

  describe "#backup" do
    it "emails a compressed backup attachment when it fits" do
      stub_const("#{described_class}::BACKUP_EMAIL_MAX_ATTACHMENT_BYTES", 10.megabytes)

      described_class.new.backup

      mail = ActionMailer::Base.deliveries.last

      expect(mail).to be_present
      expect(mail.attachments.map(&:filename)).to all(end_with(".sql.gz"))
      expect(mail.body.encoded).to include("Raw backup file on server:")
      expect(Dir[Rails.root.join("tmp", "*.sql").to_s]).not_to be_empty
      expect(Dir[Rails.root.join("tmp", "*.sql.gz").to_s]).not_to be_empty
    end

    it "sends the backup email without attachment when the compressed backup is too large" do
      stub_const("#{described_class}::BACKUP_EMAIL_MAX_ATTACHMENT_BYTES", 1)

      described_class.new.backup

      mail = ActionMailer::Base.deliveries.last

      expect(mail).to be_present
      expect(mail.attachments).to be_empty
      expect(mail.body.encoded).to include("attachment was skipped")
    end

    it "does not fail the backup after the file is created when smtp delivery times out" do
      delivery = instance_double(ActionMailer::MessageDelivery)

      allow(BackupMailer).to receive(:send_backup).and_return(delivery)
      allow(delivery).to receive(:deliver_now).and_raise(Net::ReadTimeout.new("timed out"))

      expect { described_class.new.backup }.not_to raise_error
      expect(Dir[Rails.root.join("tmp", "*.sql").to_s]).not_to be_empty
    end
  end
end
