local builtin = require "telescope.builtin"
local entry_display = require "telescope.pickers.entry_display"
local path = require "plenary.path"
local themes = require "telescope.themes"
local theme = themes.get_dropdown

-- https://github.com/NvChad/NvChad/blob/b7a163e232524f1024a59a0a5c6ddf123530085c/lua/nvchad/mappings.lua#L65

local function find_nearest_package_json_dir(start_dir)
  local current_dir = path:new(start_dir)

  while current_dir ~= nil do
    local package_json_path = current_dir:joinpath "package.json"
    if package_json_path:exists() then
      return current_dir
    end
    local parent_dir = current_dir:parent()

    if parent_dir:absolute() == current_dir:absolute() then
      current_dir = nil
    else
      current_dir = parent_dir
    end
  end

  return nil
end

-- Custom function for searching files within the current package
local function find_files_in_current_package()
  local current_file_dir = vim.fn.expand "%:p:h"
  local package_root = find_nearest_package_json_dir(current_file_dir)

  if package_root == nil then
    print "No package found up the tree."
    return
  end

  local split_path = vim.split(package_root.filename, "/")
  local package_name = split_path[#split_path]

  print(package_name)

  builtin.find_files(theme {
    cwd = package_root.filename,
    prompt_title = "Files in " .. package_name,
  })
end

local function find_git_repo_root(starting_path)
  local current_path = path:new(starting_path)
  local git_path = current_path:joinpath ".git"

  while not git_path:exists() do
    local parent_path = current_path:parent()
    if not parent_path or parent_path.filename == current_path.filename then
      return nil
    end
    current_path = parent_path
    git_path = current_path:joinpath ".git"
  end

  return current_path
end

local function find_packages()
  local current_file_dir = vim.fn.expand "%:p:h"
  local repo_root = find_git_repo_root(current_file_dir)

  if repo_root == nil then
    print "Git repository root not found."
    return
  end

  local displayer = entry_display.create {
    separator = " ",
    items = { { width = 50 } },
  }

  local function make_display(entry)
    local package_name = vim.fn.fnamemodify(entry.value, ":h:t")
    return displayer { package_name }
  end

  builtin.find_files(theme {
    prompt_title = "Find Packages",
    cwd = repo_root.filename,
    find_command = {
      "rg",
      "--files",
      "--hidden",
      "--iglob",
      "libs/**/package.json",
      "--iglob",
      "apps/**/package.json",
    },
    entry_maker = function(entry, opts)
      local original_maker = require("telescope.make_entry").gen_from_file(opts)
      local original_entry = original_maker(entry)
      original_entry.display = make_display
      return original_entry
    end,
  })
end

vim.keymap.set("n", "<leader>ll", find_packages)
vim.keymap.set("n", "<leader>fl", find_files_in_current_package)

return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    config = function()
      require "configs.conform"
    end,
  },

  {
    "nvim-telescope/telescope.nvim",
    opts = function()
      local conf = require "nvchad.configs.telescope"

      table.insert(conf.defaults.file_ignore_patterns, "%.jpg")
      table.insert(conf.defaults.file_ignore_patterns, "%.png")
      table.insert(conf.defaults.file_ignore_patterns, "%.ico")

      vim.keymap.set("n", "<leader>ls", function()
        local current_file_dir = vim.fn.expand "%:p:h"
        local package_root = find_nearest_package_json_dir(current_file_dir)

        if package_root == nil then
          return
        end

        local input = vim.fn.input "Search in package > "

        if input == "" then
          return
        end

        builtin.grep_string { search = input, cwd = package_root.filename }
      end, {})

      vim.keymap.set("n", "<leader>ll", find_packages)
      vim.keymap.set("n", "<leader>fl", find_files_in_current_package)

      return conf
    end,
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require("nvchad.configs.lspconfig").defaults()
      require "configs.lspconfig"
    end,
  },
  --
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "lua-language-server",
        "stylua",
        "html-lsp",
        "css-lsp",
        "prettier",
        "typescript-language-server",
        "codelldb",
      },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "vim",
        "lua",
        "vimdoc",
        "typescript",
        "javascript",
        "html",
        "css",
      },
    },
  },

  {
    "tpope/vim-surround",
    lazy = false,
  },

  {
    "jay-babu/mason-nvim-dap.nvim",
    event = "VeryLazy",
    dependencies = {
      "williamboman/mason.nvim",
      "mfussenegger/nvim-dap",
    },
    opts = {
      handlers = {},
    },
  },

  {
    "mfussenegger/nvim-dap",
  },
}
