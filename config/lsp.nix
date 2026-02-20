{
  lib,
  pkgs,
  ...
}:
let

  ansible_ls =
    let
      pname = "ansible-language-server";
      version = "26.1.3";

      src = pkgs.fetchFromGitHub {
        owner = "ansible";
        repo = "vscode-ansible";
        tag = "v${version}";
        hash = "sha256-DsEW3xP8Fa9nwPuyEFVqG6rvAZgr4TDB6jhyixdvqt8=";
      };

      offlineCache = pkgs.stdenvNoCC.mkDerivation {
        name = "${pname}-${version}-yarn-cache";
        inherit src;

        nativeBuildInputs = [
          pkgs.yarn-berry
          pkgs.nodejs
          pkgs.cacert
        ];

        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "sha256-NYbHhvlVoSL7lT1EdFkNJlmzRzQ0Gudo5pF0t6JtSic=";

        buildPhase = ''
          export HOME=$TMPDIR
          export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt

          yarn config set enableTelemetry false
          yarn config set enableGlobalCache false
          yarn config set cacheFolder .yarn/cache
          yarn install --mode=skip-build

          mkdir -p $out
          cp -r .yarn/cache/* $out/
          cp .yarnrc.yml $out/ || true
        '';

        dontInstall = true;
      };

    in
    pkgs.stdenvNoCC.mkDerivation {
      inherit pname version src;

      nativeBuildInputs = with pkgs; [
        yarn-berry
        nodejs
        makeWrapper
      ];

      buildPhase = ''
        export HOME=$TMPDIR

        mkdir -p .yarn/cache
        for f in ${offlineCache}/*; do
          if [ "$(basename $f)" != ".yarnrc.yml" ]; then
            cp -r "$f" .yarn/cache/
          fi
        done

        yarn config set enableTelemetry false
        yarn config set enableGlobalCache false
        yarn config set cacheFolder .yarn/cache
        yarn config set enableNetwork false

        yarn workspaces focus @ansible/ansible-language-server

        cd packages/ansible-language-server
        rm -rf test
        yarn run compile
      '';

      installPhase = ''
        mkdir -p $out/lib/node_modules/ansible-language-server
        cp -r out package.json $out/lib/node_modules/ansible-language-server/

        cd ../..
        cp -rL node_modules $out/lib/node_modules/ansible-language-server/

        mkdir -p $out/lib/node_modules/ansible-language-server/bin
        cp packages/ansible-language-server/bin/ansible-language-server $out/lib/node_modules/ansible-language-server/bin/

        mkdir -p $out/bin
        makeWrapper ${pkgs.nodejs}/bin/node $out/bin/ansible-language-server \
          --prefix PATH : ${pkgs.python3}/bin \
          --add-flags "$out/lib/node_modules/ansible-language-server/out/server/src/server.js"
      '';

      meta = with lib; {
        changelog = "https://github.com/ansible/vscode-ansible/releases/tag/v${version}";
        description = "Ansible Language Server";
        mainProgram = "ansible-language-server";
        homepage = "https://github.com/ansible/vscode-ansible";
        license = licenses.mit;
      };
    };

in
{
  extraConfigLuaPost = ''
    local severity = vim.diagnostic.severity
    vim.diagnostic.config({
        signs = {
            text = {
                [severity.ERROR] = " ",
                [severity.WARN] = " ",
                [severity.INFO] = " ",
                [severity.HINT] = " ",
            },
        },
    })
  '';
  lsp = {
    inlayHints.enable = false;
    keymaps = [
      {
        key = "grh";
        lspBufAction = "hover";
        mode = "n";
      }
      {
        key = "<leader>lde";
        action = "<CMD>lua vim.diagnostic.open_float()<Enter>";
        mode = "n";
      }
      {
        mode = "n";
        key = "<leader>lx";
        action = "<CMD>lua vim.g.type_checking = not vim.g.type_checking; local clients = vim.lsp.get_clients({name = 'ty'}); for _, client in ipairs(clients) do vim.lsp.stop_client(client.id) end; vim.defer_fn(function() vim.lsp.start({name = 'ty', cmd = {'ty', 'server'}, settings = { ty = { analysis = { typeCheckingMode = vim.g.type_checking and 'on' or 'off', }, }, }, root_markers = {'.git', 'pyproject.toml', 'setup.py'}}) end, 100)<CR>";
      }
    ];
    servers = {
      ansible = {
        enable = true;
        package = ansible_ls;
        config = {
          cmd = [
            "ansible-language-server"
            "--stdio"
          ];
          filetypes = [ "yaml.ansible" ];
          root_markers = [
            ".git"
            "inventory"
            "ansible.cfg"
          ];
          settings = {
            ansible = {
              path = "ansible";
              useFullyQualifiedCollectionNames = true;
            };
            executionEnvironment.enabled = false;
            python = {
              interpreterPath = "python";
              envKind = "auto";
            };
          };
        };
      };
      html.enable = true;
      bashls = {
        enable = true;
        config = {
          cmd = [ "bash-language-server" "start" ];
          filetypes = [ "zsh" "sh" "bash" "ksh" ];
        };
      };
      nixd = {
        enable = true;
        config = {
          cmd = [ "nixd" ];
          filetypes = [ "nix" ];
          settings = {
            nixd = {
              options = {
                nixvim = {
                  expr = "(builtins.getFlake \"github:nix-community/nixvim\").legacyPackages.\${builtins.currentSystem}.nixvimConfiguration.options";
                };
                nixos = {
                  expr = ''(builtins.getFlake "github:dtvillafana/dotfiles-nix").outputs.nixosConfigurations.thinkpad.options'';
                };
                home_manager = {
                  expr = ''((builtins.getFlake "github:dtvillafana/dotfiles-nix").outputs.nixosConfigurations.thinkpad.options.home-manager.users.type.getSubOptions [])'';
                };
              };
            };
          };
        };
      };
      djlsp = {
        enable = true;
        package = pkgs.python3Packages.buildPythonPackage rec {
          pname = "django_template_lsp";
          version = "1.2.2";
          format = "pyproject";
          src = pkgs.python3Packages.fetchPypi {
            inherit pname version;
            hash = "sha256-FdzLsz3H70y4ThZzvwWD1UUrspuMskZWO4xbpOFBXIM=";
          };
          nativeBuildInputs = with pkgs.python3Packages; [ setuptools ];
          propagatedBuildInputs = with pkgs.python3Packages; [ pygls lsprotocol jedi ];
          meta = with lib; {
            description = "Language server for Django templates";
            homepage = "https://github.com/fourdigits/djlsp";
            license = licenses.mit;
          };
        };
        config = {
          cmd = [ "djlsp" ];
          filetypes = [ "htmldjango" ];
        };
      };
      htmx = {
        enable = true;
        config = {
          cmd = [ "htmx-lsp" ];
          filetypes = [
            "aspnetcorerazor" "astro" "astro-markdown" "blade" "clojure"
            "django-html" "edge" "eelixir" "ejs" "elixir" "erb" "eruby"
            "gohtml" "gohtmltmpl" "haml" "handlebars" "hbs" "heex" "html"
            "html-eex" "htmlangular" "htmldjango" "jade" "javascript"
            "javascriptreact" "leaf" "liquid" "markdown" "mdx" "mustache"
            "njk" "nunjucks" "php" "razor" "reason" "rescript" "slim"
            "svelte" "templ" "twig" "typescript" "typescriptreact" "vue"
          ];
        };
      };
      ty = {
        enable = true;
        config = {
          cmd = [ "ty" "server" ];
          filetypes = [ "python" ];
        };
      };
      jsonls = {
        enable = true;
        config = {
          cmd = [ "vscode-json-language-server" "--stdio" ];
          filetypes = [ "json" ];
        };
      };
      lemminx = {
        enable = true;
        config = {
          cmd = [ "lemminx" ];
          filetypes = [ "xml" ];
        };
      };
      ts_ls = {
        enable = true;
        config = {
          cmd = [ "typescript-language-server" "--stdio" ];
          root_dir = lib.nixvim.mkRaw ''
            function(bufnr, on_dir)
                local root_markers = { 'package-lock.json', 'yarn.lock', 'pnpm-lock.yaml', 'bun.lockb', 'bun.lock', '.git' }
                local project_root = vim.fs.root(bufnr, root_markers)
                if not project_root then
                  return
                end
                on_dir(project_root)
            end
          '';
        };
      };
      tailwindcss = {
        enable = true;
        config = {
          cmd = [ "tailwindcss-language-server" ];
          filetypes = [
            "aspnetcorerazor" "astro" "astro-markdown" "blade" "clojure"
            "django-html" "htmldjango" "edge" "eelixir" "elixir" "ejs"
            "erb" "eruby" "gohtml" "gohtmltmpl" "haml" "handlebars" "hbs"
            "htmlangular" "html-eex" "heex" "jade" "leaf" "liquid" "mdx"
            "mustache" "njk" "nunjucks" "php" "razor" "slim" "twig" "css"
            "less" "postcss" "sass" "scss" "stylus" "sugarss" "javascript"
            "javascriptreact" "reason" "rescript" "typescript"
            "typescriptreact" "vue" "svelte" "templ"
          ];
        };
      };
      lua_ls = {
        enable = true;
        config = {
          telemetry.enable = false;
          diagnostics.globals = [ "vim" ];
        };
      };
      kotlin_language_server = {        # <-- moved inside servers
        enable = true;
        config = {
          cmd = [ "kotlin-language-server" ];
          filetypes = [ "kotlin" ];
          root_markers = [
            "settings.gradle"
            "settings.gradle.kts"
            "build.gradle"
            "build.gradle.kts"
            "pom.xml"
            ".git"
          ];
        };
      };
      svls = {                          # <-- moved inside servers
        enable = true;
        config = {
          cmd = [ "svls" ];
          filetypes = [ "verilog" "systemverilog" ];
          root_markers = [ ".svls.toml" ".git" ];
        };
      };
    };
    luaConfig = {
      post = ''
        vim.g.type_checking = true;
        function RESET_LSP()
            local cur_buf = vim.api.nvim_get_current_buf()
            local clients = vim.lsp.get_clients({bufnr = cur_buf})

            local client_names = {}
            for _, client in ipairs(clients) do
                table.insert(client_names, client.name)
                vim.lsp.stop_client(client.id)
            end

            local filepath = vim.api.nvim_buf_get_name(cur_buf)
            local directory = vim.fn.fnamemodify(filepath, ':h')
            local command = 'cd ' .. directory
            vim.api.nvim_exec2(command, { output = false })
            vim.api.nvim_exec2('DirenvExport', { output = false })

            vim.defer_fn(function()
                vim.cmd('edit!')
                if #client_names > 0 then
                    local message = "Restarted LSP servers: " .. table.concat(client_names, ", ")
                    vim.notify(message, vim.log.levels.INFO)
                else
                    vim.notify("No LSP servers were running", vim.log.levels.WARN)
                end
            end, 1000)
        end
      '';
    };
  };

  plugins.lsp = {
    servers = {
      lua_ls = {
        enable = true;
        settings = {
          telemetry.enable = false;
          diagnostics.globals = [ "vim" ];
        };
      };
      rust_analyzer = {
        enable = true;
        installCargo = true;
        installRustc = true;
      };
    };
  };

  plugins = {
    lspconfig.enable = true;
    telescope.keymaps = {
      "<leader>lf" = "lsp_references";
      "<leader>lg" = "lsp_definitions";
      "<leader>lt" = "lsp_type_definitions";
      "<leader>lci" = "lsp_incoming_calls";
      "<leader>lco" = "lsp_outgoing_calls";
    };
    direnv = {
      enable = true;
      settings.direnv_silent_reload = 0;
    };
  };
  filetype = {
    pattern = {
      ".*inventory" = "yaml.ansible";
      ".*playbook.yml" = "yaml.ansible";
      ".*config.yml" = "yaml.ansible";
    };
  };
}
