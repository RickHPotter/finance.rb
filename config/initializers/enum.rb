# frozen_string_literal: true

def rikki = -> { Import::FromRikkiExcel.run }

MONTHS_FULL = %w[Janvier Fevrier Mars Avril Mai June Jui Août Septembre Octobre Novembre Decembre].freeze
MONTHS_ABBR = %w[Jan Fev Mars Avril Mai June Jui Août Sept Oct Nov Dec].freeze

COLOURS = ActiveSupport::HashWithIndifferentAccess.new(
  {
    # GRAYISH
    white: { bg: "bg-slate-100", text: "text-black", from: "from-slate-100", via: "via-slate-100", to: "to-slate-100" },
    gray: { bg: "bg-gray-400", text: "text-black", from: "from-gray-400", via: "via-gray-400", to: "to-gray-400" },
    slate: { bg: "bg-slate-500", text: "text-black", from: "from-slate-500", via: "via-slate-500", to: "to-slate-500" },
    greek: { bg: "bg-greek", text: "text-black", from: "from-greek", via: "via-greek", to: "to-greek" },
    zinc: { bg: "bg-zinc-500", text: "text-black", from: "from-zinc-500", via: "via-zinc-500", to: "to-zinc-500" },
    stone: { bg: "bg-stone-500", text: "text-black", from: "from-stone-500", via: "via-stone-500", to: "to-stone-500" },
    urgency: { bg: "bg-urgency", text: "text-black", from: "from-urgency", via: "via-urgency", to: "to-urgency" },
    silver: { bg: "bg-gray-600", text: "text-black", from: "from-gray-600", via: "via-gray-600", to: "to-gray-600" },

    # YELLOWISH
    fun: { bg: "bg-fun", text: "text-black", from: "from-fun", via: "via-fun", to: "to-fun" },
    yellow: { bg: "bg-yellow-400", text: "text-black", from: "from-yellow-400", via: "via-yellow-400", to: "to-yellow-400" },
    gold: { bg: "bg-yellow-500", text: "text-black", from: "from-yellow-500", via: "via-yellow-500", to: "to-yellow-500" },
    dirt: { bg: "bg-yellow-600", text: "text-zinc-300", from: "from-yellow-600", via: "via-yellow-600", to: "to-yellow-600" },

    # BLUEISH
    cyan: { bg: "bg-cyan-500", text: "text-black", from: "from-cyan-500", via: "via-cyan-500", to: "to-cyan-500" },
    sky: { bg: "bg-sky-500", text: "text-black", from: "from-sky-500", via: "via-sky-500", to: "to-sky-500" },
    blue: { bg: "bg-blue-500", text: "text-black", from: "from-blue-500", via: "via-blue-500", to: "to-blue-500" },
    indigo: { bg: "bg-indigo-500", text: "text-black", from: "from-indigo-500", via: "via-indigo-500", to: "to-indigo-500" },

    # GREENISH
    oldmoney: { bg: "bg-oldmoney", text: "text-black", from: "from-oldmoney", via: "via-oldmoney", to: "to-oldmoney" },
    lettuce: { bg: "bg-lettuce", text: "text-black", from: "from-lettuce", via: "via-lettuce", to: "to-lettuce" },
    money: { bg: "bg-money", text: "text-black", from: "from-money", via: "via-money", to: "to-money" },
    lime: { bg: "bg-lime-500", text: "text-black", from: "from-lime-500", via: "via-lime-500", to: "to-lime-500" },
    green: { bg: "bg-green-500", text: "text-black", from: "from-green-500", via: "via-green-500", to: "to-green-500" },
    emerald: { bg: "bg-emerald-500", text: "text-black", from: "from-emerald-500", via: "via-emerald-500", to: "to-emerald-500" },
    teal: { bg: "bg-teal-500", text: "text-black", from: "from-teal-500", via: "via-teal-500", to: "to-teal-500" },
    book: { bg: "bg-book", text: "text-black", from: "from-book", via: "via-book", to: "to-book" },

    # REDISH
    rose: { bg: "bg-rose-500", text: "text-black", from: "from-rose-500", via: "via-rose-500", to: "to-rose-500" },
    red: { bg: "bg-red-500", text: "text-black", from: "from-red-500", via: "via-red-500", to: "to-red-500" },
    gift: { bg: "bg-gift", text: "text-black", from: "from-gift", via: "via-gift", to: "to-gift" },
    honda: { bg: "bg-honda", text: "text-black", from: "from-honda", via: "via-honda", to: "to-honda" },

    # ORANGEISH
    meat: { bg: "bg-meat", text: "text-black", from: "from-meat", via: "via-meat", to: "to-meat" },
    bronze: { bg: "bg-bronze", text: "text-black", from: "from-bronze", via: "via-bronze", to: "to-bronze" },
    amber: { bg: "bg-amber-500", text: "text-black", from: "from-amber-500", via: "via-amber-500", to: "to-amber-500" },
    orange: { bg: "bg-orange-500", text: "text-black", from: "from-orange-500", via: "via-orange-500", to: "to-orange-500" },

    # PURPLEISH
    pink: { bg: "bg-pink-500", text: "text-black", from: "from-pink-500", via: "via-pink-500", to: "to-pink-500" },
    fuchsia: { bg: "bg-fuchsia-500", text: "text-black", from: "from-fuchsia-500", via: "via-fuchsia-500", to: "to-fuchsia-500" },
    purple: { bg: "bg-purple-500", text: "text-black", from: "from-purple-500", via: "via-purple-500", to: "to-purple-500" },
    violet: { bg: "bg-violet-500", text: "text-black", from: "from-violet-500", via: "via-violet-500", to: "to-violet-500" }
  }.freeze
)

RIKKI_COLOURS = {
  "HEALTH" => :meat,
  "FOOD" => :meat,
  "GROCERY" => :lettuce,
  "EDUCATION" => :book,
  "RENT" => :urgency,
  "NEEDS" => :urgency,
  "MAINTENANCE" => :urgency,
  "GIFT" => :gift,
  "ASSETS" => :gift,
  "TRANSPORT" => :honda,
  "SALARY" => :gold,
  "BENEFITS" => :gold,
  "CARD PAYMENT" => :money,
  "CARD ADVANCE" => :money,
  "CARD DISCOUNT" => :money,
  "CARD REVERSAL" => :money,
  "CARD INSTALLMENT" => :money,
  "DEPOSIT" => :money,
  "PROMO" => :money,
  "LOAN" => :money,
  "INVESTMENT" => :bronze,
  "SELL" => :oldmoney,
  "LEISURE" => :fun,
  "BILL" => :gray,
  "FEES" => :gray,
  "MORAL DEBT" => :gray,
  "BET" => :silver,
  "GODSEND" => :greek,
  "EXCHANGE" => :dirt,
  "EXCHANGE RETURN" => :yellow,
  "MIDDLEWARE" => :gold
}.freeze

RIKKI_ICONS = {
  "GIGI" => "people/1.png",
  "GESABI" => "people/2.png",
  "VIH" => "people/4.png",
  "LALA" => "people/5.png",
  "SOGRINHA" => "people/12.png",
  "TIA" => "people/13.png",
  "MOI" => "people/15.png",
  "SETE TECNOLOGIA" => "people/19.png",
  "SIEDOS" => "people/19.png",
  "SOGRAO" => "people/24.png",
  "NOUS" => "people/29.png",
  "RUBY" => "dogs/3.png",
  "RAVENA" => "dogs/8.png",
  "RECEITA FEDERAL" => "dogs/17.png"
}.freeze
