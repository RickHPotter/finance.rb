# frozen_string_literal: true

MONTHS_FULL = %w[Janvier Fevrier Mars Avril Mai June Jui Août Septembre Octobre Novembre Decembre].freeze
MONTHS_ABBR = %w[Jan Fev Mars Avril Mai June Jui Août Sept Oct Nov Dec].freeze

COLOURS = ActiveSupport::HashWithIndifferentAccess.new(
  {
    slate: { bg: "bg-slate-500", text: "text-black" },
    zinc: { bg: "bg-zinc-500", text: "text-black" },
    neutral: { bg: "bg-neutral-500", text: "text-black" },
    stone: { bg: "bg-stone-500", text: "text-black" },
    red: { bg: "bg-red-500", text: "text-black" },
    orange: { bg: "bg-orange-500", text: "text-black" },
    amber: { bg: "bg-amber-500", text: "text-black" },
    yellow: { bg: "bg-yellow-400", text: "text-black" },
    gold: { bg: "bg-yellow-500", text: "text-black" },
    dirt: { bg: "bg-yellow-600", text: "text-zinc-300" },
    lime: { bg: "bg-lime-500", text: "text-black" },
    green: { bg: "bg-green-500", text: "text-black" },
    emerald: { bg: "bg-emerald-500", text: "text-black" },
    teal: { bg: "bg-teal-500", text: "text-black" },
    cyan: { bg: "bg-cyan-500", text: "text-black" },
    sky: { bg: "bg-sky-500", text: "text-black" },
    blue: { bg: "bg-blue-500", text: "text-black" },
    indigo: { bg: "bg-indigo-500", text: "text-black" },
    violet: { bg: "bg-violet-500", text: "text-black" },
    purple: { bg: "bg-purple-500", text: "text-black" },
    fuchsia: { bg: "bg-fuchsia-500", text: "text-black" },
    pink: { bg: "bg-pink-500", text: "text-black" },
    rose: { bg: "bg-rose-500", text: "text-black" },
    meat: { bg: "bg-meat", text: "text-black" },
    lettuce: { bg: "bg-lettuce", text: "text-black" },
    book: { bg: "bg-book", text: "text-black" },
    urgency: { bg: "bg-urgency", text: "text-black" },
    gift: { bg: "bg-gift", text: "text-black" },
    honda: { bg: "bg-honda", text: "text-black" },
    money: { bg: "bg-money", text: "text-black" },
    oldmoney: { bg: "bg-oldmoney", text: "text-black" },
    fun: { bg: "bg-fun", text: "text-black" },
    gray: { bg: "bg-gray-400", text: "text-black" },
    silver: { bg: "bg-gray-600", text: "text-zinc-300" },
    bronze: { bg: "bg-bronze", text: "text-black" },
    greek: { bg: "bg-greek", text: "text-black" }
  }
)
