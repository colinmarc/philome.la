# encoding: utf-8

require 'rubygems'
require 'sinatra'
require 'sinatra/json'
require 'omniauth'
require 'omniauth-twitter'
require 'mongo_mapper'
require 'twitter'
require 'unicode_utils'

require 'json'
require 'uri'
require 'tempfile'

VERIFY_SCRIPT_PATH = File.join(File.dirname(__FILE__), 'verify_twine.js')
TWINE_PATH = File.join(File.dirname(__FILE__), 'twines')

class User
  include MongoMapper::Document

  key :uid, String
  key :name, String
  key :created, Time

  many :twines, :class_name => 'Twine', :foreign_key => :creator_id
end

class Twine
  include MongoMapper::Document

  key :name, String
  key :slug, String
  key :description, String
  key :created, Time
  key :likes, Integer
  key :plays, Integer

  key :creator_id, ObjectId
  belongs_to :creator, :class_name => 'User'
end

configure do
  set :public_folder, Proc.new { File.join(root, "static") }

  secrets = YAML.load_file(File.join(File.dirname(__FILE__), 'secrets.yaml'))

  use OmniAuth::Builder do
    provider :twitter, secrets['twitter']['key'], secrets['twitter']['secret']
  end

  enable :sessions

  Twitter.configure do |config|
    config.consumer_key = secrets['twitter']['tweeter_key']
    config.consumer_secret = secrets['twitter']['tweeter_secret']
    config.oauth_token = secrets['twitter']['oauth_token']
    config.oauth_token_secret = secrets['twitter']['oauth_secret']
  end

  MongoMapper.connection = Mongo::Connection.new('localhost', 27017)
  MongoMapper.database = "philomela"

  User.ensure_index(:uid)
  User.ensure_index(:name)

  Twine.ensure_index([[:creator_id, 1], [:slug, 1]])
end

helpers do
  def uid
    session[:uid]
  end

  def username
    session[:username]
  end

  def username_link
    "<a href=\"/#{username}\">@#{username}</a>"
  end

  def check_uploaded!
    uploaded = session[:uploaded]

    threshold = Time.now - 60 * 60 # expire after an hour
    if uploaded && session[:uploaded][:created] < threshold
      File.unlink(uploaded[:path])
      session[:uploaded] = nil
    end
  end

  def uploaded_filename
    check_uploaded!

    uploaded = session[:uploaded]
    return nil if uploaded.nil?

    name = uploaded[:name]
    name = name[0..22] + '...' if name.length > 25
    name
  end

  def uploaded_filesize
    check_uploaded!

    uploaded = session[:uploaded]
    return nil if uploaded.nil?

    (uploaded[:size] / 1024).to_s + 'K'
  end

  def sanitize(text)
    Rack::Utils.escape_html(text)
  end
end

# AUTH

get  '/login' do
  if username
    redirect '/'
  else
    redirect '/auth/twitter'
  end
end

get '/auth/twitter/callback' do
  auth = request.env["omniauth.auth"]

  uid = auth['uid']
  user = User.find_by_uid(uid)

  if user.nil?
    user = User.new(
      :uid => uid,
      :name => auth['info']['nickname'],
      :created => Time.now
    )

    user.save
  end

  session[:uid] = user.uid
  session[:username] = user.name
  erb "<script>window.close();</script>"
end

get '/logout' do
  session.clear
  redirect '/'
end

# EVERYTHING ELSE

get '/' do
  erb :publish
end

post '/upload' do
  tempfile = Tempfile.new(['twine', '.html'])

  tempfile.write(params[:userfile][:tempfile].read)
  valid = system "phantomjs '#{VERIFY_SCRIPT_PATH}' '#{tempfile.path}'"

  if valid
    session[:uploaded] = {
      :path => tempfile.path,
      :name => params[:userfile][:filename],
      :size => tempfile.size,
      :created => Time.now
    }
    tempfile.close
  else
    tempfile.unlink
    tempfile.close
  end

  json :valid => valid
end

post '/publish' do
  error = nil

  user = User.find_by_uid(uid)
  uploaded = session[:uploaded]
  name = params[:name]

  if user.nil? || uploaded.nil? || name.nil? || !File.exist?(uploaded[:path])
    @error = "Sorry! Something went wrong. Feel free to email " \
             "<a href=\"mailto:colinmarc@gmail.com?Subject=HALP\" " \
             "target=\"_blank\">colinmarc@gmail.com</a> if you continue to " \
             "have issues."

    # clear out the session just in case
    session.delete(:uploaded)

    halt(erb(:publish))
  end

  name = name[0..50]
  slug = UnicodeUtils.nfkc(name).downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
  if slug.empty?
    @error = "Please add some non-unicode non-space characters to " \
             "the name, or it'll be hard to link to it. ☃"
    halt(erb(:publish))
  end


  unless Twine.find_by_creator_id_and_slug(user.id, slug).nil?
    @error = "You already have a game named \"#{name}\"!"
    halt(erb(:publish))
  end

  twine = Twine.new(
    :name => name,
    :slug => slug,
    :creator_id => user.id,
    :created => Time.now,
    :likes => 0,
    :plays => 0
  )

  path = File.join(TWINE_PATH, "#{twine.id}.html")
  FileUtils.copy(uploaded[:path], path)
  File.unlink(uploaded[:path])
  twine.save
  session.delete(:uploaded)

  if params[:tweet] == 'yes'
    Twitter.update("\"#{twine.name}\", by @#{user.name} http://philome.la/#{user.name}/#{twine.slug}")
  end

  redirect "/#{user.name}/#{slug}"
end

get '/:user' do
  @user = User.find_by_name(params[:user])
  halt(404) unless @user

  @twines = Twine.all(:creator_id => @user.id)

  erb :profile
end

get '/:user/:slug' do
  @user = User.find_by_name(params[:user])
  halt(404) unless @user

  @twine = Twine.find_by_creator_id_and_slug(@user.id, params[:slug])
  halt(404) unless @twine

  erb :twine
end

post '/:user/:slug/delete' do
  user = User.find_by_name(params[:user])
  halt(404) unless user
  halt(403) unless user.uid == uid

  twine = Twine.find_by_creator_id_and_slug(user.id, params[:slug])
  halt(404) unless twine

  path = File.join(TWINE_PATH, "#{twine.id}.html")
  File.unlink(path) if File.exist?(path)
  twine.delete

  redirect "/#{user.name}"
end

# post '/:user/:slug/update' do
#   user = User.find_by_name(params[:user])
#   halt(404) unless @user
#   halt(403) unless @user.uid == uid

#   twine = Twine.find_by_creator_id_and_slug(@user.id, params[:slug])
#   halt(404) unless @twine

#   uploaded = session[:uploaded]

#   if uploaded.nil? || !File.exist?(uploaded[:path])
#     @error = "Sorry! Something went wrong. Feel free to email " \
#              "<a href=\"mailto:colinmarc@gmail.com?Subject=HALP\" " \
#              "target=\"_blank\">colinmarc@gmail.com</a> if you continue to " \
#              "have issues."
#     halt(erb(:twine))
#   end

#   path = File.join(TWINE_PATH, "#{twine.id}.html")
#   FileUtils.copy(uploaded[:path], path)
#   File.unlink(uploaded[:path])

#   session[:uploaded] = nil
#   redirect "/#{user.name}/#{twine.slug}"
# end

get '/:user/:slug/play' do
  user = User.find_by_name(params[:user])
  halt(404) unless user

  twine = Twine.find_by_creator_id_and_slug(user.id, params[:slug])
  halt(404) unless twine

  twine.increment(:plays => 1)
  send_file File.join(TWINE_PATH, "#{twine.id}.html")
end

not_found do
  erb '<div id="porpy"><center><img src="404.png"/>404 not found</center></div>'
end

