{ pkgs, ... }:
{
  extraPlugins = [
    (pkgs.vimUtils.buildVimPlugin {
      name = "window-picker";
      src = pkgs.fetchFromGitHub {
        owner = "s1n7ax";
        repo = "nvim-window-picker";
        rev = "main";
        hash = "sha256-ZavIPpQXLSRpJXJVJZp3N6QWHoTKRvVrFAw7jekNmX4=";
      };
    })
  ];
  extraConfigLua = ''
    require('window-picker').setup()
    function open_path_in_win()
        local path = nil
        local line_num = nil
        local file_dir = vim.fn.expand('%:p:h')

        -- Try to extract markdown link under cursor: [text](path#Lnum)
        local line = vim.fn.getline('.')
        local col = vim.fn.col('.')

        -- Find all markdown links in the line and check if cursor is within one
        local start_pos = 1
        while true do
            local link_start, link_end, link_path, link_anchor = line:find('%[.-%]%(([^)#]+)#?([^)]*)%)', start_pos)
            if not link_start then break end

            if col >= link_start and col <= link_end then
                path = link_path
                -- Extract line number from anchor like "L95" or "L95-L100"
                if link_anchor and link_anchor:match('^L(%d+)') then
                    line_num = tonumber(link_anchor:match('^L(%d+)'))
                end
                break
            end
            start_pos = link_end + 1
        end

        -- Fall back to <cfile> if no markdown link found
        if not path then
            path = vim.fn.expand(vim.fn.expand('<cfile>'))
        end

        -- Resolve relative paths
        local full_path = path
        if vim.fn.filereadable(path) == 0 then
            full_path = file_dir .. '/' .. path
        end

        if vim.fn.filereadable(full_path) == 0 then
            print(path .. " is not a valid path")
            return
        end

        -- Let the user pick a window
        local picked_win = require('window-picker').pick_window({
            hint = 'floating-big-letter',
            filter_rules = {
                autoselect_one = false,
                include_current_win = true
            }
        })

        if not picked_win then
            print("No window selected")
            return
        end

        -- Focus the picked window, open file, and jump to line
        vim.api.nvim_set_current_win(picked_win)
        vim.cmd('edit ' .. vim.fn.fnameescape(full_path))
        if line_num then
            vim.api.nvim_win_set_cursor(picked_win, {line_num, 0})
        end
    end
  '';
  keymaps = [
    {
      action = "<CMD>lua open_path_in_win()<CR>";
      key = "gf";
      options = {
        noremap = true;
        silent = true;
      };
    }
  ];
}
