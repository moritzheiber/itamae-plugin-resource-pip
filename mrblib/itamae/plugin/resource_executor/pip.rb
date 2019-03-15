# frozen_string_literal: true

module ::MItamae
  module Plugin
    module ResourceExecutor
      class Pip < ::MItamae::ResourceExecutor::Base
        def apply
          if desired.installed
            if current.installed
              if desired.version && current.version != desired.version
                install!
                updated!
              end
            else
              install!
              updated!
            end
          else
            uninstall! if current.installed
          end
        end

        private

        def set_current_attributes(current, _action)
          installed = installed_pips.find { |pip| pip[:name] == attributes.package_name }
          current.installed = !!installed
          current.version = installed[:version] if current.installed
        end

        def installed_pips
          pips = []
          cmd = [*Array(attributes.pip_binary), 'freeze']
          cmd << '--user' if attributes.user

          run_command(cmd).stdout.each_line do |line|
            name, version = line.chomp.split(/==/)
            pips << { name: name, version: version }
          end
          pips
        rescue Backend::CommandExecutionError
          []
        end

        def set_desired_attributes(desired, action)
          case action
          when :install, :upgrade
            desired.installed = true
          when :uninstall
            desired.installed = false
          end

          desired.version = attributes.version if attributes.version
          desired.options = prepare_options(attributes.options) if attributes.options
        end

        def build_pip_install_command; end

        def install!
          cmd = [*Array(attributes.pip_binary), 'install']
          cmd << '--user' if attributes.user
          cmd << desired.options if desired.options

          cmd << if desired.version
                   "#{attributes.package_name}==#{desired.version}"
                 else
                   attributes.package_name
                 end

          run_command(cmd.flatten)
        end

        def uninstall!
          cmd = [*Array(attributes.pip_binary), 'uninstall']
          cmd << desired.options if desired.options

          cmd << if desired.version
                   "#{attributes.package_name}==#{desired.version}"
                 else
                   attributes.package_name
                 end
          cmd << '-y'

          run_command(cmd)
        end

        def prepare_options(options)
          o = options.split(' ') if options.is_a? String
          o = ([] << o).flatten
          o.reject! { |i| i == '--user' }
          return o unless o.empty?
          false
        end
      end
    end
  end
end
