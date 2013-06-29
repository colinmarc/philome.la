
require 'rubygems'
require 'sinatra'
require 'omniauth'
require 'omniauth-twitter'
require 'mongo_mapper'

configure do
  set :public_folder, Proc.new { File.join(root, "static") }

  use OmniAuth::Builder do
    provider :twitter, ENV['TWITTER_KEY'], ENV['TWITTER_SECRET']
  end

  enable :sessions

  MongoMapper.setup({'production' => {'uri' => 'mongodb://localhost'}}, 'production')
end

class User
  include MongoMapper::Document

  key :token, String
  key :name, String
  key :created, Time

  many :twines
end

class Twine
  include MongoMapper::Document

  key :name, String
  key :token, String
  key :url, String
  key :likes, Integer

  belongs_to :user
end

helpers do
  def username
    session[:identity]
  end
end

get '/' do
  erb :front_page
end

get '/host' do
  redirect '/' unless username
  erb "hello @#{username}"
end

post '/login' do
  redirect '/auth/twitter'
end

get '/auth/twitter/callback' do
  auth = request.env["omniauth.auth"]
  session[:identity] = auth['info']['nickname']
  redirect '/'
end

get '/logout' do
  session.delete(:identity)
  redirect to '/'
end


get '/:name' do
  erb :profile
end
