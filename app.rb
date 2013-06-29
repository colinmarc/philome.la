
require 'rubygems'
require 'sinatra'
require 'omniauth'
require 'omniauth-twitter'
require 'mongo_mapper'

class User
  include MongoMapper::Document

  key :uid, String
  key :handle, String
  key :created, Time

  many :twines, :class_name => 'Twine', :foreign_key => :creator_id
end

class Twine
  include MongoMapper::Document

  key :uid, String
  key :name, String
  key :description, String
  key :created, Time
  key :likes, Integer

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
  Twine.ensure_index(:creator_id)
end

helpers do
  def username
    me = session[:me]
    me.handle if me
  end
end

get '/' do
  erb :front_page
end

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
  handle = '@' + auth['info']['nickname']

  user = User.find_by_uid(uid)
  if user.nil?
    user = User.new(
      :uid => uid,
      :handle => handle,
      :created => Time.now
    )

    user.save
  end

  session[:me] = user

  redirect '/hostpage'
end

get '/logout' do
  session.clear
  redirect to '/'
end


get '/:name' do
  erb :profile
end
