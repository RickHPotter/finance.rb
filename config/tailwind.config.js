module.exports = {
  content: [
    "./public/*.html",
    "./app/helpers/**/*.rb",
    "./app/javascript/**/*.js",
    "./app/components/**/*.rb",
    "./app/components/**/*.html.erb",
    "./app/views/**/*.{erb,haml,html,slim}",
    "./node_modules/flowbite/**/*.js"
  ],
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        meat: "#f9906f",
        lettuce: "#93c560",
        book: "#2f7361",
        urgency: "#555857",
        gift: "#ce2d46",
        honda: "#cc0000",
        money: "#34a853",
        oldmoney: "#b9c58f",
        gold: "#c9a95f",
        fun: "#fbbc05", // [#f6ec95]
        greek: "#5b6794",
      }
    },
  },
  safelist: [
    { pattern: /bg-(meat|lettuce|book|urgency|gift|honda|money|oldmoney|gold|fun|greek)/ },
    { pattern: /bg-(gray|yellow)-(400|600)/ }
  ]
}
