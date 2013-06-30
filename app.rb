
require 'rubygems'
require 'sinatra'
require 'sinatra/json'
require 'omniauth'
require 'omniauth-twitter'
require 'mongo_mapper'

require 'json'
require 'uri'
require 'tempfile'
require 'pp'

VERIFY_SCRIPT_PATH = File.join(File.dirname(__FILE__), 'verify_twine.js')
TWINE_PATH = File.join(File.dirname(__FILE__), 'twines')

class User
  include MongoMapper::Document

  key :uid, String
  key :handle, String
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
  puts tempfile.path

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

  if user.nil? || uploaded.nil? || name.nil?
    @error = "Sorry! Something went wrong. Feel free to email " \
             "<a href=\"mailto:colinmarc@gmail.com?Subject=HALP\" " \
             "target=\"_blank\">colinmarc@gmail.com</a> if you continue to " \
             "have issues."
    redirect '/'
  end

  name = name[0..50]
  slug = name.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
  unless Twine.find_by_creator_id_and_slug(user.id, slug).nil?
    @error = "You already have a game named that!"
    redirect '/'
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

  session[:uploaded] = nil

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

get '/:user/:slug/play' do
  user = User.find_by_name(params[:user])
  halt(404) unless user

  twine = Twine.find_by_creator_id_and_slug(user.id, params[:slug])
  halt(404) unless twine

  twine.increment(:plays => 1)
  send_file File.join(TWINE_PATH, "#{twine.id}.html")
end
