# frozen_string_literal: true

MONTHS_FULL = %w[Janvier Fevrier Mars Avril Mai June Jui Août Septembre Octobre Novembre Decembre].freeze
MONTHS_ABBR = %w[Jan Fev Mars Avril Mai June Jui Août Sept Oct Nov Dec].freeze

COLOURS = ActiveSupport::HashWithIndifferentAccess.new(
  {
    slate: { bg: "bg-slate-500", text: "text-black", from: "from-slate-500", via: "via-slate-500", to: "to-slate-500" },
    zinc: { bg: "bg-zinc-500", text: "text-black", from: "from-zinc-500", via: "via-zinc-500", to: "to-zinc-500" },
    neutral: { bg: "bg-neutral-500", text: "text-black", from: "from-neutral-500", via: "via-neutral-500", to: "to-neutral-500" },
    stone: { bg: "bg-stone-500", text: "text-black", from: "from-stone-500", via: "via-stone-500", to: "to-stone-500" },
    red: { bg: "bg-red-500", text: "text-black", from: "from-red-500", via: "via-red-500", to: "to-red-500" },
    orange: { bg: "bg-orange-500", text: "text-black", from: "from-orange-500", via: "via-orange-500", to: "to-orange-500" },
    amber: { bg: "bg-amber-500", text: "text-black", from: "from-amber-500", via: "via-amber-500", to: "to-amber-500" },
    yellow: { bg: "bg-yellow-400", text: "text-black", from: "from-yellow-400", via: "via-yellow-400", to: "to-yellow-400" },
    gold: { bg: "bg-yellow-500", text: "text-black", from: "from-yellow-500", via: "via-yellow-500", to: "to-yellow-500" },
    dirt: { bg: "bg-yellow-600", text: "text-zinc-300", from: "from-yellow-600", via: "via-yellow-600", to: "to-yellow-600" },
    lime: { bg: "bg-lime-500", text: "text-black", from: "from-lime-500", via: "via-lime-500", to: "to-lime-500" },
    green: { bg: "bg-green-500", text: "text-black", from: "from-green-500", via: "via-green-500", to: "to-green-500" },
    emerald: { bg: "bg-emerald-500", text: "text-black", from: "from-emerald-500", via: "via-emerald-500", to: "to-emerald-500" },
    teal: { bg: "bg-teal-500", text: "text-black", from: "from-teal-500", via: "via-teal-500", to: "to-teal-500" },
    cyan: { bg: "bg-cyan-500", text: "text-black", from: "from-cyan-500", via: "via-cyan-500", to: "to-cyan-500" },
    sky: { bg: "bg-sky-500", text: "text-black", from: "from-sky-500", via: "via-sky-500", to: "to-sky-500" },
    blue: { bg: "bg-blue-500", text: "text-black", from: "from-blue-500", via: "via-blue-500", to: "to-blue-500" },
    indigo: { bg: "bg-indigo-500", text: "text-black", from: "from-indigo-500", via: "via-indigo-500", to: "to-indigo-500" },
    violet: { bg: "bg-violet-500", text: "text-black", from: "from-violet-500", via: "via-violet-500", to: "to-violet-500" },
    purple: { bg: "bg-purple-500", text: "text-black", from: "from-purple-500", via: "via-purple-500", to: "to-purple-500" },
    fuchsia: { bg: "bg-fuchsia-500", text: "text-black", from: "from-fuchsia-500", via: "via-fuchsia-500", to: "to-fuchsia-500" },
    pink: { bg: "bg-pink-500", text: "text-black", from: "from-pink-500", via: "via-pink-500", to: "to-pink-500" },
    rose: { bg: "bg-rose-500", text: "text-black", from: "from-rose-500", via: "via-rose-500", to: "to-rose-500" },
    meat: { bg: "bg-meat", text: "text-black", from: "from-meat", via: "via-meat", to: "to-meat" },
    lettuce: { bg: "bg-lettuce", text: "text-black", from: "from-lettuce", via: "via-lettuce", to: "to-lettuce" },
    book: { bg: "bg-book", text: "text-black", from: "from-book", via: "via-book", to: "to-book" },
    urgency: { bg: "bg-urgency", text: "text-black", from: "from-urgency", via: "via-urgency", to: "to-urgency" },
    gift: { bg: "bg-gift", text: "text-black", from: "from-gift", via: "via-gift", to: "to-gift" },
    honda: { bg: "bg-honda", text: "text-black", from: "from-honda", via: "via-honda", to: "to-honda" },
    money: { bg: "bg-money", text: "text-black", from: "from-money", via: "via-money", to: "to-money" },
    oldmoney: { bg: "bg-oldmoney", text: "text-black", from: "from-oldmoney", via: "via-oldmoney", to: "to-oldmoney" },
    fun: { bg: "bg-fun", text: "text-black", from: "from-fun", via: "via-fun", to: "to-fun" },
    gray: { bg: "bg-gray-400", text: "text-black", from: "from-gray-400", via: "via-gray-400", to: "to-gray-400" },
    silver: { bg: "bg-gray-600", text: "text-zinc-300", from: "from-gray-600", via: "via-gray-600", to: "to-gray-600" },
    bronze: { bg: "bg-bronze", text: "text-black", from: "from-bronze", via: "via-bronze", to: "to-bronze" },
    greek: { bg: "bg-greek", text: "text-black", from: "from-greek", via: "via-greek", to: "to-greek" }
  }
)
