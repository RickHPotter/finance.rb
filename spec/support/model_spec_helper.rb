# frozen_string_literal: true

# Model Helpers for Validations that go accross most models
module ModelSpecHelper
  RSpec.shared_examples 'validate_nil' do |model, attribute|
    let(:subject) { FactoryBot.build(model, attribute => nil) }

    it "is not valid with a nil #{attribute}" do
      expect(subject).to_not be_valid
      expect(subject.errors[attribute]).to include("can't be blank")
    end
  end

  RSpec.shared_examples 'validate_blank' do |model, attribute|
    let(:subject) { FactoryBot.build(model, attribute => ' ' * 3) }

    it "is not valid with a blank #{attribute}" do
      expect(subject).to_not be_valid
      expect(subject.errors[attribute]).to include("can't be blank")
    end
  end

  RSpec.shared_examples 'validate_uniqueness' do |model, attribute|
    let(:helper) { FactoryBot.create model }
    let(:subject) { FactoryBot.build(model, attribute => helper.public_send(attribute)) }

    it "is not valid with an existing #{attribute}" do
      expect(helper).to be_valid
      expect(subject).to_not be_valid
      expect(subject.errors[attribute]).to include('has already been taken')
    end
  end

  RSpec.shared_examples 'validate_min_lenght' do |model, attribute, min|
    let(:subject) { FactoryBot.build(model, attribute => '2' * (min - 1)) }

    it "is not valid with #{attribute} with an shorter length than the minimum" do
      expect(subject).to_not be_valid
      expect(subject.errors[attribute]).to include('is too short (minimum is 6 characters)')
    end
  end

  RSpec.shared_examples 'validate_max_lenght' do |model, attribute, max|
    let(:subject) { FactoryBot.build(model, attribute => '2' * (max + 1)) }

    it "is not valid with #{attribute} with longer length than the maximum" do
      expect(subject).to_not be_valid
      expect(subject.errors[attribute]).to include('is too long (maximum is 22 characters)')
    end
  end

  RSpec.shared_examples 'validate_invalid' do |model, attribute|
    let(:subject) { FactoryBot.build(model, "with_invalid_#{attribute}") }

    it "is not valid with invalid #{attribute}" do
      expect(subject).to_not be_valid
      expect(subject.errors[attribute]).to include('is invalid')
    end
  end
end

RSpec.configure do |config|
  config.include ModelSpecHelper, type: :model
end
