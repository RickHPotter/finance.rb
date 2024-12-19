# frozen_string_literal: true

module Import
  class FromHash
    def initialize(hash_collection)
      @hash_collection = hash_collection
    end

    def import
      CardTransaction.new(@hash_collection)

      @hash_collection.each do |card, transactions|
        # puts "#{card} #{transactions.count}"
        create_transactions(card, transactions)
      end
    end

    private

    def create_transactions(card, transactions)
      user = User.create(first_name: "Rikki", last_name: "Potteru", email: "rikki.potteru@mail.com", password: "123123", confirmed_at: Time.zone.now)
      bank = Bank.create(bank_name: card, bank_code: card.upcase)
      card = Card.create(card_name: card, bank:)
      user_card = UserCard.create(user:, card:)

      transactions.each do |transaction|
        test_if_transaction_is_standalone(transaction)

        CardTransaction.create(ct_description: transaction.description,
                               date: transaction.date,
                               starting_price: transaction.price,
                               price: transaction.price,
                               user:,
                               user_card:)
      end
    end

    def test_if_transaction_is_standalone(transaction)
      transaction.description.match(%r{^[0-9][0-2]/[0-9][0-2]})
    end
  end
end

#  ct_description     :string           not null
#  ct_comment         :text
#  date               :date             not null
#  month              :integer          not null
#  year               :integer          not null
#  starting_price     :decimal(, )      not null
#  price              :decimal(, )      not null
#  installments_count :integer          default(0), not null
#  user_id            :bigint           not null
#  user_card_id       :bigint           not null
