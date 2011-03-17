require 'rubygems'
require 'mechanize'
require 'json'
require 'nokogiri'
require 'ap'
require 'redis'
require 'twitter'
require 'open-uri'
require 'json'

PATH_CONFIG = YAML.load(File.read("path_config.yml"))

Twitter.configure do |config|
  config.consumer_key       = PATH_CONFIG["twitter"]["consumer_key"]
  config.consumer_secret    = PATH_CONFIG["twitter"]["consumer_secret"]
  config.oauth_token        = PATH_CONFIG["twitter"]["oauth_token"]
  config.oauth_token_secret = PATH_CONFIG["twitter"]["oauth_token_secret"]
end

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
  redis = Redis.new
  client = Twitter::Client.new
  json_data.each do |photo|
    if redis.get("not_first") == nil
      redis.set(photo["photo"]["original"]["url"], "PULLED")
      ap photo["photo"]["original"]["url"]
      puts '======='
    else
      if redis.get(photo["photo"]["original"]["url"])
        puts "already have it"
      else
        puts "New Path Item!"
        login = PATH_CONFIG["bitly"]["login"]
        api_key = PATH_CONFIG["bitly"]["api_key"]
        url = photo["photo"]["original"]["url"]
        result = JSON.parse(open("http://api.bitly.com/v3/shorten?login=#{login}&apiKey=#{api_key}&longUrl=#{url}&format=json").read)        
        client.update("#{result["data"]["url"]} #path")
      end
    end
    redis.set("not_first", "true")
  end
end
