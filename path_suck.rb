require 'rubygems'
require 'mechanize'
require 'json'
require 'nokogiri'
require 'ap'
require 'redis'
require 'twitter'
require 'open-uri'
require 'json'

if ARGV[0] && (ARGV[0] == 'test' || ARGV[0] == 'production')

  PATH_CONFIG = YAML.load(File.read("path_config.yml"))

  Twitter.configure do |config|
    config.consumer_key       = PATH_CONFIG["twitter"]["consumer_key"]
    config.consumer_secret    = PATH_CONFIG["twitter"]["consumer_secret"]
    config.oauth_token        = PATH_CONFIG["twitter"]["oauth_token"]
    config.oauth_token_secret = PATH_CONFIG["twitter"]["oauth_token_secret"]
  end

  # Test Mode
  test_mode = true if ARGV == 'test'

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
  
  # Print out the body
  ap my_path_page.body if test_mode

  user_data = nil
  post_data = nil
  profile_id = nil

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

  # If we get some data, make sure to not just SPAM twitter the first run with all our Path posts, skip everything not in Redis on first run, THEN start processing path moments.

  if post_data
    clean_data = post_data.strip.gsub("Path.postData = ", "").chop
    json_data = JSON.parse(clean_data)
    redis = Redis.new
    client = Twitter::Client.new
    json_data.each do |photo|
      if redis.get("not_first") == nil
        redis.set(photo["photo"]["85_484"]["url"], "PULLED")
        ap photo["photo"]["85_484"]["url"]
        puts '======='
      else
        if redis.get(photo["photo"]["85_484"]["url"])
          puts "Path Moment Already Processed"
          #ap photo
          #ap url
        else
          puts "New Path Moment!"
          redis.set(photo["photo"]["85_484"]["url"], "PULLED")
          login = PATH_CONFIG["bitly"]["login"]
          api_key = PATH_CONFIG["bitly"]["api_key"]
          if photo["private"]
            # Private moments link to the 85_484 photo
            url = photo["photo"]["85_484"]["url"]
          else
            # Public moments link directly to the Path Page
            url = "https://www.path.com/#{photo["creator"]["username"]}/posts/#{photo["id"]}/public"
          end      
          unless test_mode  
            result = JSON.parse(open("http://api.bitly.com/v3/shorten?login=#{login}&apiKey=#{api_key}&longUrl=#{url}&format=json").read)        
            client.update("Posted to #path #{result["data"]["url"]}")
          else
            puts " *** TEST MODE *** "
            puts " Url: #{url}";
            puts " *** TEST MODE *** "          
          end
        end
      end
    end
    redis.set("not_first", "true")
  end
else
  puts "Usage `ruby path_suck.rb MODE"
  puts "Valid modes [test, production]"
end
