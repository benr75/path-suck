require 'rubygems'
require 'mechanize'
require 'json'
require 'nokogiri'
require 'ap'
require 'redis'

PATH_CONFIG = YAML.load(File.read("path_config.yml"))

# TWIT PIC: 5c61b4cfb2cc6dad01ba5fb0cdbd64a0

# Create a new mechanize object
agent = Mechanize.new

# Load the Path Login Form
page = agent.get('https://www.path.com/login')
form = page.forms[0]  # Select the first form
form.username_or_email = PATH_CONFIG["path"]["user"]
form.password          = PATH_CONFIG["path"]["pass"]

# Submit the form
page = agent.submit(form, form.buttons.first)

my_path_page = agent.get("https://www.path.com/#{PATH_CONFIG["path"]["user"]}")

puts my_path_page.body # Print out the body

user_data = nil
post_data = nil
profile_id = nil

#doc = Nokogiri::HTML(File.open("test.html"))

doc = Nokogiri::HTML(my_path_page.body)

doc.css('script').each do |script|
  if script.content.include?("Path.userData")
    script.content.each_line do |line|
      user_data = line if line.include?("Path.userData")
      post_data = line if line.include?("Path.postData")
      profile_id = line if line.include?("Path.profileId")
    end
  end
end

if post_data
  clean_data = post_data.strip.gsub("Path.postData = ", "").chop
  json_data = JSON.parse(clean_data)
  
  json_data.each do |photo|
    ap photo["photo"]["original"]["url"]
    puts '======='
  end
end
