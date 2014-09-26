# coding: utf-8

get '/' do
  @irkit_keys = get_irkit_keys
  slim :index
end

post '/' do
  ir_key  = params[:ir_key]
  @result = irkit('post', ir_key)
end

post '/save' do
  ir_key  = params[:ir_key]
  @result = irkit('get', ir_key)
  redirect '/'
end

post '/delete' do
  ir_key  = params[:ir_key]
  @result = irkit('delete', ir_key, 'Y')
  redirect '/'
end

def irkit(opt, ir_key, answer="")
  addr   = ENV["IRKIT_ADDRESS"]
  prefix = ENV["COMMAND_PREFIX"]
  answer = "echo #{answer} | " if answer
  if addr
    result = `#{answer}#{prefix} irkit --#{opt} "#{ir_key}" --address #{addr}`
  else
    result = `#{answer}#{prefix} irkit --#{opt} "#{ir_key}"`
  end
  result
end

def get_irkit_keys
  data_file = ENV["IRKIT_DATA_FILE"] || File.expand_path('.irkit.json', ENV['HOME'])
  ir_data = Hashie::Mash.new JSON.parse(File.open(data_file).read)["IR"]
  ir_data.keys
end
