#
# Cookbook Name:: sagecrm
# Recipe:: default
#
# Copyright (C) 2015 Taliesin Sisson
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'autoit'
include_recipe '7-zip'

if node['sagecrm']['service']['account'] == ""
    raise "Please configure Sage CRM service_account attribute"
end

if node['sagecrm']['service']['password'] == ""
    raise "Please configure Sage CRM service_account_password attribute"
end

if node['sagecrm']['service']['password'] == ""
    raise "Please configure Sage CRM service_account_password attribute"
end

if node['sagecrm']['properties']['License']['Name']  == ""
    raise "Please configure Sage CRM license name attribute"
end

if node['sagecrm']['properties']['License']['Company'] == ""
    raise "Please configure Sage CRM license company attribute"
end

if node['sagecrm']['properties']['License']['Serial'] == ""
    raise "Please configure Sage CRM license serial attribute"
end

username = node['sagecrm']['service']['account']
domain = ""

if username.include? '\\'
	domain = username.split('\\')[0]
	username = username.split('\\')[1]
end

if username.include? '@'
	domain = username.split('@')[1]
	username = username.split('@')[0]
end

if domain == ""  || domain == "."
	domain = node["hostname"]
end

(node['sagecrm']['windows_features']).each do |feature|
	windows_feature feature do
	  action :install
	  all true
	end
end

::Chef::Recipe.send(:include, Windows::Helper)

working_directory = File.join(Chef::Config['file_cache_path'], '/sagecrm')

directory working_directory do
  recursive true
end

sagecrm_install_script_path = File.join(working_directory, 'SageCrmInstall.au3')
sagecrm_install_exe_path = File.join(working_directory, 'SageCrmInstall.exe')

win_friendly_sagecrm_install_script_path = win_friendly_path(sagecrm_install_script_path)
win_friendly_sagecrm_install_exe_path = win_friendly_path(sagecrm_install_exe_path)

sagecrm_installed = is_package_installed?("#{node['sagecrm']['name']}")
filename = File.basename(node['sagecrm']['url']).downcase
download_path = File.join(working_directory, filename)

installation_directory = File.join(working_directory, node['sagecrm']['checksum'])
win_friendly_installation_directory = win_friendly_path(installation_directory)

template sagecrm_install_script_path do
  source 'SageCrmInstall.au3.erb'
  variables(
    WorkingDirectory: win_friendly_installation_directory
  )
  not_if {sagecrm_installed}
end

execute "Check syntax #{win_friendly_sagecrm_install_script_path} with AutoIt" do
  command "\"#{File.join(node['autoit']['home'], '/Au3Check.exe')}\" \"#{win_friendly_sagecrm_install_script_path}\""
  not_if {sagecrm_installed}
end

execute "Compile #{win_friendly_sagecrm_install_script_path} with AutoIt" do
  command "\"#{File.join(node['autoit']['home'], '/Aut2Exe/Aut2exe.exe')}\" /in \"#{win_friendly_sagecrm_install_script_path}\" /out \"#{win_friendly_sagecrm_install_exe_path}\""
  not_if {sagecrm_installed}
end

remote_file download_path do
  source node['sagecrm']['url']
  checksum node['sagecrm']['checksum']
  not_if {sagecrm_installed}
end

execute "Exract #{download_path} To #{win_friendly_installation_directory}" do
  command "\"#{File.join(node['7-zip']['home'], '7z.exe')}\" x -y -o\"#{win_friendly_installation_directory}\" #{download_path}"
  not_if {sagecrm_installed  || ::File.directory?(installation_directory)}
end

if !sagecrm_installed
  node.set['windows_autologin']['autologincount'] = 1
  include_recipe 'windows_autologin'
end

registry_key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' do
  values [{:name => 'install_sage_crm', :type => :string, :data => "\"#{win_friendly_sagecrm_install_exe_path}\" -Logoff"}]
  action :create
  notifies :reboot_now, 'reboot[now]', :immediately
  not_if {sagecrm_installed}
end

reboot 'now' do
  action :nothing
  reason 'Cannot continue Chef run without a reboot.'
end

#Wait some how

#node.set['windows_autologin']['autologincount'] = nil
#node.set['windows_autologin']['enable'] = false

#include_recipe 'windows_autologin'

#reboot 'now' do
#  action :reboot_now
#  reason 'Need to run SageCrm installer in interactive mode that is not in Session 0.'
#end