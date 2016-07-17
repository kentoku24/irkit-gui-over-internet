# coding: utf-8
require 'tmp_cache'
require 'aws-sdk-core'
require 'logger'
require 'singleton'


class MyLogger
  include Singleton
  attr_reader :log
  def initialize
    @log = Logger.new('sinatra.log')
  end
end

get '/' do
  MyLogger.instance.log.info "received get / request"
  load_settings
  MyLogger.instance.log.info "obtained devicename #{@device_name}"
  @sequence_keys = get_sequence_keys
  @irkit_keys = get_irkit_keys
  slim :index
end


post '/' do
  ir_key  = params[:ir_key]
  MyLogger.instance.log.info "received post / request with key: #{ir_key}"
  begin
    @result = irkit('post', ir_key)
  rescue Exception => e
    logger.info e
    raise e
  end
end

post '/save' do
  ir_key  = params[:ir_key]
  MyLogger.instance.log.info "received save / request with key: #{ir_key}"
  @result = irkit('get', ir_key)
  redirect '/'
end

post '/delete' do
  ir_key  = params[:ir_key]
  MyLogger.instance.log.info "received delete / request with key: #{ir_key}"
  @result = irkit('delete', ir_key, 'Y')
  redirect '/'
end
# now this is not used
def irkit_old(opt, ir_key, answer="")
  load_settings
  answer = "echo #{answer} | " if answer
  if @addr
    result = `#{answer} irkit --#{opt} "#{ir_key}" --address #{@addr}`
  elsif @device_name
    result = `#{answer} irkit --device #{@device_name} --#{opt} "#{ir_key}" `
  else
    result = `#{answer} irkit --#{opt} "#{ir_key}"`
  end
  result
end

# take a string of commands, convert it into an array of commands
# "light_darker & light_warmer*2 & all_off" => ["light_darker","light_warmer","light_warmer","AC_off","light_off"]
def build_commands(raw_commands)
  db = Aws::DynamoDB::Client.new(
    access_key_id: @aws_access_key_id,
    secret_access_key: @aws_secret_access_key,
    region: 'ap-northeast-1'
  )
  all_ir_keys = get_irkit_keys
  all_sequence_keys = get_sequence_keys
  #all_sequence_keys = db.scan(table_name: "Sequences")[0].reduce([]){|rtn, item| rtn << item["name"]}.sort
  # flatten & symbols
  commands = raw_commands.split(/[ ]*&[ ]*/)

  #replace all commands recognized in Sequence
  commands.map! do |item|
    if all_ir_keys.include? item #this is pure command
      item
    elsif all_sequence_keys.include? item #this should be replaced with some other commands
      db.get_item( :table_name => "Sequences", :key => {name: item} ).item["commands"]
    else
      #its something wrong, but not ignoring anyway...
      item
    end
  end.flatten!

  #flatten * symbols
  commands.map! do |item|
    cmd, count_str = item.split(/[ ]*\*[ ]*/)
    count = count_str.to_i
    count = 1 if count < 1
    rtn_item = []
    count.times do |i|
      rtn_item << cmd
    end
    rtn_item
  end
  
  commands.flatten
end

def irkit(opt, ir_key, answer="")
  load_settings
  db = Aws::DynamoDB::Client.new(
    access_key_id: @aws_access_key_id, 
    secret_access_key: @aws_secret_access_key,
    region: 'ap-northeast-1'
  )
  irkit = IRKit::InternetAPI.new(
    clientkey: @irkit_clientkey, 
    deviceid: @irkit_deviceid
  )
  answer = "echo #{answer} | " if answer
  # this recieves command name, retrieve ir sequence from Dynamo and send them to irkit API
  if opt == 'post'
    begin
      all_commands = build_commands params[:ir_key]
      MyLogger.instance.log.info "===all_commands: #{all_commands}"
    rescue Exception => e
      MyLogger.instance.log.info e
      raise
    end
    #MyLogger.instance.log.info "===#{all_commands}"

    #new way
    commands = build_commands params[:ir_key]
    commands.each do |command|
      raw_ir_data = db.get_item( :table_name => "Commands", :key => {name: command} ).item
      ir_data = {"format"=>"raw","freq"=>38, "data"=> raw_ir_data['ir_data'].map{|e|e.to_i} }
      irkit.post_messages ir_data
      MyLogger.instance.log.info "sent #{command} request / original: #{params[:ir_key]}"
    end
    #old way
    #send multiple commands
    #split by & simbol, then split by * simbol
    #commands = params[:ir_key].split(/[ ]*&[ ]*/)
    #commands.each do |command|
    #  ir_key, count_str = command.split(/[ ]*\*[ ]*/)
    #  count = count_str.to_i
    #  count = 1 if count < 1
    #  
    #  #if the command exists in commands, execute it, otherwise search for Sequences
    #  raw_item = db.get_item( :table_name => "Commands", :key => {name: ir_key} )
    #  raw_ir_data = raw_item.item
    #  ir_data = {"format"=>"raw","freq"=>38, "data"=> raw_ir_data['ir_data'].map{|e|e.to_i} }
    #  
    #  count.times do |i|
    #    irkit.post_messages ir_data
    #    MyLogger.instance.log.info "sent #{ir_key} request #{i+1}/#{count}"
    #  end
    #  ir_data.inspect
    #end

    @result = "processed a post request"

    #send single command
    #ir_key  = params[:ir_key]
    #raw_item = db.get_item( :table_name => "Commands", :key => {name: ir_key} )
    #raw_ir_data = raw_item.item
    #ir_data = {"format"=>"raw","freq"=>38, "data"=> raw_ir_data['ir_data'].map{|e|e.to_i} }
    #irkit.post_messages ir_data
    #@result = "not supported"
    #ir_data.inspect
    
  elsif opt == 'get'
    ir_key  = params[:ir_key]
    ir_data = irkit.get_messages.message.data
    db.batch_write_item(
      :request_items => {
        "Commands" => [
          {:put_request => { :item => {:name => ir_key, :ir_data => ir_data} } }
        ]
      }
    )
    @result = ir_key + " " + ir_data.to_s
    redirect '/'
  elsif opt == 'delete'
    ir_key  = params[:ir_key]
    db.delete_item(:table_name => "Commands", :key => {:name => ir_key})
    redirect '/'
  end
end


def load_settings
  @addr = settings.IRKIT_ADDRESS
  @data_file_dir = settings.IRKIT_DATA_DIR || ENV['HOME']
  @device_name = settings.DEVICE_NAME
  @irkit_clientkey = settings.IRKIT_CLIENTKEY
  @irkit_deviceid  = settings.IRKIT_DEVICEID
  @aws_access_key_id = settings.AWS_ACCESS_KEY_ID
  @aws_secret_access_key = settings.AWS_SECRET_ACCESS_KEY
rescue
end

def get_irkit_keys_old
#  keys = TmpCache.get('irkit_keys')
#  if keys == nil
    data_file = File.expand_path('.irkit.json', @data_file_dir)
    ir_data = Hashie::Mash.new JSON.parse(File.open(data_file).read)["IR"]
    keys = ir_data.keys.sort
#    TmpCache.set('irkit_keys',keys,60)
#    keys
#  else
#    keys
#  end
end

def get_irkit_keys
  load_settings
  cached_keys = TmpCache.get('irkit_keys')
  if cached_keys
    MyLogger.instance.log.info "cache hit: #{cached_keys}"
    cached_keys
  else
    MyLogger.instance.log.info "cache miss"
    db = Aws::DynamoDB::Client.new(
      access_key_id: @aws_access_key_id,
      secret_access_key: @aws_secret_access_key,
      region: 'ap-northeast-1'
    )
    keys = db.scan(table_name: "Commands")[0].reduce([]){|rtn, item| rtn << item["name"]}.sort
    TmpCache.set('irkit_keys',keys,60)
    keys
  end
end

def get_sequence_keys
  load_settings
  db = Aws::DynamoDB::Client.new(
    access_key_id: @aws_access_key_id,
    secret_access_key: @aws_secret_access_key,
    region: 'ap-northeast-1'
  )
  db.scan(table_name: "Sequences")[0].reduce([]){|rtn, item| rtn << item["name"]}.sort
end

def add_ir_data_format(data)
  {"format"=>"raw", "freq"=>38, "data"=>data}
end
