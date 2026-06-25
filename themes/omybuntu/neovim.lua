return {
  {
    "bjarneo/aether.nvim",
    branch = "v2",
    name = "aether",
    priority = 1000,
    opts = {
      transparent = false,
      colors = {
        bg           = "#140a05",
        bg_dark      = "#140a05",
        bg_highlight = "#2a1a10",

        -- Foregrounds
        fg           = "#f5e6d3",
        fg_dark      = "#e8d5c4",
        comment      = "#5c4033",

        red          = "#ef4444",
        orange       = "#f59e0b",
        yellow       = "#fbbf24",
        green        = "#84d187",
        cyan         = "#fdba74",
        blue         = "#fb923c",
        purple       = "#c2410c",
        magenta      = "#ea580c",
      },
    },
    config = function(_, opts)
      require("aether").setup(opts)
      vim.cmd.colorscheme("aether")
      require("aether.hotreload").setup()
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "aether",
    },
  },
}
