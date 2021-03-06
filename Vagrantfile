# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"
VAGRANT_REQUIRED_VERSION = "1.6.5"

# Require 1.6.5 at least
if ! defined? Vagrant.require_version
  if Gem::Version.new(Vagrant::VERSION) < Gem::Version.new(VAGRANT_REQUIRED_VERSION)
    puts "Vagrant >= " + VAGRANT_REQUIRED_VERSION + " required. Your version is " + Vagrant::VERSION
    exit 1
  end
else
  Vagrant.require_version ">= " + VAGRANT_REQUIRED_VERSION
end

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  servers = { 'icinga2' => '192.168.33.5'
            }
  http_port = { 'icinga2' => 8080
              }
  ssh_port = { 'icinga2' => 2080
             }

  servers.each do |server_name, server_ip|
    config.vm.define server_name do |app_config|

      # network config
      app_config.vm.hostname = "#{server_name.to_s}"
      app_config.vm.network :forwarded_port, guest: 22, host: 2222, id: "ssh", disabled: true
      app_config.vm.network :forwarded_port, guest: 22, host: ssh_port[server_name], auto_correct: true
      app_config.vm.network :forwarded_port, guest: 80, host: http_port[server_name], auto_correct: true
      app_config.vm.network :private_network, ip: "#{server_ip}"

      # app_config.vm.provision :shell, :path => "manifests/puppet.sh"

      # parallels
      app_config.vm.provider :parallels do |p, override|
        override.vm.box = "parallels/centos-7.1"

        p.name = "Icinga 2: #{server_name.to_s}"

        # Update Parallels Tools automatically
        p.update_guest_tools = true

        # Set power consumption mode to "Better Performance"
        p.optimize_power_consumption = false

        p.memory = 1024
        p.cpus = 2
      end

      # virtualbox
      app_config.vm.provider :virtualbox do |v, override|
        override.vm.box = "centos-71-x64-vbox"
        override.vm.box_url = "http://boxes.icinga.org/centos-71-x64-vbox.box"

        v.customize ["modifyvm", :id, "--memory", "1024"]
        v.customize ["modifyvm", :id, "--cpus", "2"]
      end
    end
  end
end
