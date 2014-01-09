module Ninefold
  class Ninefold::Command::Apps < Ninefold::Command
    desc "list", "list the apps registered to this account"
    def list
      require_user

      load_apps do |apps|
        interaction :listapps, apps
      end
    end

    desc "info", "print out info about an app"
    def info
      pick_app do |app|
        interaction :appinfo, app
      end
    end

    desc "console", "run the rails console on an app"
    option :public_key, aliases: '-k', desc: "your public key location", default: "~/.ssh/id_rsa.pub"
    def console
      run_app_command :console
    end

    desc "dbconsole", "run the rails dbconsole"
    option :public_key, aliases: '-k', desc: "your public key location", default: "~/.ssh/id_rsa.pub"
    def dbconsole
      run_app_command :dbconsole
    end

    desc "rake", "run rake tesks in an app"
    option :public_key, aliases: '-k', desc: "your public key location", default: "~/.ssh/id_rsa.pub"
    def rake(name, *args)
      run_app_command :rake, ([name] + args).join(' ')
    end

    desc "redeploy", "trigger the app redeployment"
    option :force, type: 'boolean', aliases: '-f', desc: "use the force Luke!"
    def redeploy
      pick_app do |app|
        interaction :redeploy, app, options[:force] do
          puts "\n"
          interaction :status, app
        end
      end
    end

    desc "deploy_status", "check on an app's deployment status"
    def deploy_status
      pick_app do |app|
        interaction :status, app
      end
    end

  protected

    def load_apps(&block)
      title "Requesting your apps list..."
      show_spinner

      App.load do |apps|
        hide_spinner

        block.call apps
      end
    end

    def pick_app(&block)
      require_user

      if app = app_from_dot_ninefold_file
        block.call app
      else
        load_apps do |apps|
          if app = interaction(:pickapp, apps)
            save_app_in_dot_ninefold_file(app)
            block.call app
          end
        end
      end
    end

    def run_app_command(name, *args, &block)
      pick_app do |app|
        title "Signing you in..."
        show_spinner

        app.__send__(name, *args, options[:public_key]) do |host, command|
          hide_spinner

          Ninefold::Runner.new(host, command)
        end
      end
    end

    def show_spinner
      @brutus ||= Ninefold::Brutus.new
      @brutus.show
    end

    def hide_spinner
      @brutus.hide
    end

    def app_from_dot_ninefold_file
      if config = Ninefold::Config.read("#{Dir.pwd}/.ninefold")
        Ninefold::App.new(config['app']) if config['app']
      end
    end

    def save_app_in_dot_ninefold_file(app)
      if app.repo == current_rails_app_git_url
        Ninefold::Config.new("#{Dir.pwd}/.ninefold").write(app: app.attributes)
      end
    end

    def current_rails_app_git_url
      marker_files  = ["Gemfile.lock", ".git/config", "app/controllers/application_controller.rb"]
      its_rails_app = marker_files.map { |f| File.exists?("#{Dir.pwd}/#{f}") }.all?

      if its_rails_app
        git_config = Ninefold::Config.read("#{Dir.pwd}/.git/config")
        git_config.each do |group, params|
          params.each do |key, value|
            return value if key == 'url'
          end
        end
      end
    end
  end
end
