-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
  {
    'tpope/vim-fugitive',
  },
  {
    'ThePrimeagen/99',
    config = function()
      local _99 = require '99'
      local cwd = vim.uv.cwd()
      local basename = vim.fs.basename(cwd)
      _99.setup {
        logger = {
          level = _99.DEBUG,
          path = '/tmp/' .. basename .. '.99.debug',
          print_on_error = true,
        },
        tmp_dir = './tmp',
        md_files = { 'AGENT.md' },
      }

      vim.keymap.set('v', '<leader>9v', function() _99.visual() end, { desc = '99: Visual replace' })
      vim.keymap.set('n', '<leader>9x', function() _99.stop_all_requests() end, { desc = '99: Stop all' })
      vim.keymap.set('n', '<leader>9s', function() _99.search() end, { desc = '99: Search' })
    end,
  },
}
