{ lib, pkgs, ... }:
let
  opencode2 = lib.getExe pkgs.opencode2;
in
{
  plugins = {
    claude-code = {
      enable = true;
      settings = {
        command = lib.getExe pkgs.claude-code;
        keymaps = {
          toggle = {
            normal = "<leader>a,";
            terminal = "<leader>a,";
            variants = {
              continue = "<leader>ac";
            };
          };
          window_navigation = true;
          scrolling = true;
        };
      };
    };
    opencode = {
      enable = true;
      package = pkgs.vimUtils.buildVimPlugin {
        name = "opencode.nvim";
        src = pkgs.fetchFromGitHub {
          owner = "dtvillafana";
          repo = "opencode.nvim";
          rev = "9cb15b1dad29d9769ff1dcd44b0194e82aeb5170";
          hash = "sha256-Kdn/Qk0y3Grtz2xq/o5EQkYgoSIh5Kv+pIuqp/tiOtY=";
        };
      };
      settings.server.start = lib.nixvim.mkRaw "function() _G.__opencode_ai.ensure_service() end";
    };
  };

  extraConfigLua = ''
    _G.__opencode_ai = {
      ensure_service = function()
        vim.system({ "${opencode2}", "api", "get", "/api/server" }, { text = true })
      end,
      terminal = function(id)
        id = id or 99
        local key = "_term_" .. id
        local term = _G.__opencode_ai[key]
        if term and (not term.bufnr or vim.api.nvim_buf_is_valid(term.bufnr)) then
          return term
        end

        local registered = require("toggleterm.terminal").get(id, true)
        if registered then
          _G.__opencode_ai[key] = registered
          return registered
        end

        _G.__opencode_ai[key] = require("toggleterm.terminal").Terminal:new({
          cmd = "${opencode2}",
          hidden = true,
          direction = "horizontal",
          display_name = "opencode " .. id,
          id = id,
        })
        return _G.__opencode_ai[key]
      end,
    }
  '';

  keymaps = [
    {
      mode = [
        "n"
        "x"
      ];
      key = "<leader>aa";
      action.__raw = ''function() require("opencode").ask("@this: ", { submit = true }) end'';
      options.desc = "Ask opencode…";
    }
    {
      mode = [
        "n"
        "x"
      ];
      key = "<leader>ax";
      action.__raw = ''function() require("opencode").select() end'';
      options.desc = "Execute opencode action…";
    }
    {
      mode = [
        "n"
        "t"
      ];
      key = "<leader>a.";
      action.__raw = "function() _G.__opencode_ai.terminal(99 + vim.v.count):toggle() end";
      options.desc = "Toggle opencode (count = extra instance)";
    }
    {
      mode = [
        "n"
        "x"
      ];
      key = "go";
      action.__raw = ''function() return require("opencode").operator("@this ") end'';
      options = {
        desc = "Add range to opencode";
        expr = true;
      };
    }
    {
      mode = "n";
      key = "goo";
      action.__raw = ''function() return require("opencode").operator("@this ") .. "_" end'';
      options = {
        desc = "Add line to opencode";
        expr = true;
      };
    }
    {
      mode = "n";
      key = "<S-C-u>";
      action.__raw = ''function() require("opencode").command("session.half.page.up") end'';
      options.desc = "Scroll opencode up";
    }
    {
      mode = "n";
      key = "<S-C-d>";
      action.__raw = ''function() require("opencode").command("session.half.page.down") end'';
      options.desc = "Scroll opencode down";
    }
  ];
}
