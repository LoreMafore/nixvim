{ pkgs, ... }:
let
  codelldb = "${pkgs.vscode-extensions.vadimcn.vscode-lldb}/share/vscode/extensions/vadimcn.vscode-lldb/adapter/codelldb";
in
{
  plugins.dap = {
    enable = true;

    extensions.dap-ui.enable = true;

    adapters.servers.codelldb = {
      port = "\${port}";
      executable = {
        command = codelldb;
        args = [
          "--port"
          "\${port}"
        ];
      };
    };

    configurations.rust = [
      {
        name = "Launch debug binary";
        type = "codelldb";
        request = "launch";
        program.__raw = ''
          function()
            return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/target/debug/', 'file')
          end
        '';
        cwd = "\${workspaceFolder}";
        stopOnEntry = false;
      }
    ];
  };

  extraConfigLua = ''
    local dap, dapui = require('dap'), require('dapui')
    dap.listeners.after.event_initialized['dapui_config'] = function() dapui.open() end
    dap.listeners.before.event_terminated['dapui_config'] = function() dapui.close() end
    dap.listeners.before.event_exited['dapui_config'] = function() dapui.close() end
  '';

  keymaps = [
    {
      mode = "n";
      key = "<leader>dc";
      action = "<CMD>lua require('dap').continue()<CR>";
      options = {
        noremap = true;
        silent = true;
        desc = "Debug: continue";
      };
    }
    {
      mode = "n";
      key = "<leader>db";
      action = "<CMD>lua require('dap').toggle_breakpoint()<CR>";
      options = {
        noremap = true;
        silent = true;
        desc = "Debug: toggle breakpoint";
      };
    }
    {
      mode = "n";
      key = "<leader>dB";
      action = "<CMD>lua require('dap').set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>";
      options = {
        noremap = true;
        silent = true;
        desc = "Debug: conditional breakpoint";
      };
    }
    {
      mode = "n";
      key = "<leader>dso";
      action = "<CMD>lua require('dap').step_over()<CR>";
      options = {
        noremap = true;
        silent = true;
        desc = "Debug: step over";
      };
    }
    {
      mode = "n";
      key = "<leader>dsi";
      action = "<CMD>lua require('dap').step_into()<CR>";
      options = {
        noremap = true;
        silent = true;
        desc = "Debug: step into";
      };
    }
    {
      mode = "n";
      key = "<leader>dst";
      action = "<CMD>lua require('dap').step_out()<CR>";
      options = {
        noremap = true;
        silent = true;
        desc = "Debug: step out";
      };
    }
    {
      mode = "n";
      key = "<leader>du";
      action = "<CMD>lua require('dapui').toggle()<CR>";
      options = {
        noremap = true;
        silent = true;
        desc = "Debug: toggle UI";
      };
    }
    {
      mode = "n";
      key = "<leader>dr";
      action = "<CMD>lua require('dap').repl.open()<CR>";
      options = {
        noremap = true;
        silent = true;
        desc = "Debug: open REPL";
      };
    }
    {
      mode = "n";
      key = "<leader>dl";
      action = "<CMD>lua require('dap').run_last()<CR>";
      options = {
        noremap = true;
        silent = true;
        desc = "Debug: run last";
      };
    }
    {
      mode = "n";
      key = "<leader>dx";
      action = "<CMD>lua require('dap').terminate()<CR>";
      options = {
        noremap = true;
        silent = true;
        desc = "Debug: terminate";
      };
    }
  ];
}
