require 'sinatra'
require 'google/cloud/storage'
require 'json'
require 'digest'
storage = Google::Cloud::Storage.new(project_id: 'cs291a')
bucket = storage.bucket 'cs291project2', skip_lookup: true
all_files = bucket.files
# valid_name = /\A[A-Fa-f0-9]{2}\/[A-Fa-f0-9]{2}\/[A-Fa-f0-9]{60}\z/
valid_name = /\A[a-f0-9]{2}\/[a-f0-9]{2}\/[a-f0-9]{60}\z/
valid_hex = /\A[A-Fa-f0-9]{64}\z/
# valid_hex = /\A[a-f0-9]{64}\Z/

get '/' do
  # "Hello World\n"
  redirect '/files/'
  return 302
end

get '/files/' do
  file_names = Array.new
  bucket.files.each do |file|
    if file.name.match(valid_name)
      file_names.append(file.name.gsub('/', '').to_s)
    end
  end
  content_type :json
  return 200, file_names.sort.to_json
end

get '/files/:digest' do
  # Respond 422 if DIGEST is not a valid SHA256 hex digest
  digest = params['digest']
  if !digest.to_s.downcase.match(valid_hex)
    return 422
  end

  # Respond 404 if there is no file corresponding to DIGEST
  path = params['digest'].downcase.insert(2, '/').insert(5, '/')
  if bucket.files.map {|file| file.name}.include? path
    file = bucket.file path
    file_content = file.download.read
    content_type file.content_type
    return 200, file_content
  else
    return 404
  end
end

delete '/files/:digest' do
  if !params['digest'].match(valid_hex)
    return 422
  end

  digest = params['digest'].to_s
  path = digest.downcase.insert(2, '/').insert(5, '/')
  bucket.files.each do |file|
    if file.name == path
      file.delete
      return 200
    end
  end
  return 200
end

post '/files/' do
  begin
    file = params['file']['tempfile']
    file_size = File.size(file)
  rescue
    return 422
  end

  # file_size = File.size(file)
  if file_size > 1024**2
    return 422
  end

  # Respond 409 if a file with the same SHA256 hex digest 
  # has already been uploaded
  sha_hex = Digest::SHA256.hexdigest file.read
  path = sha_hex.clone
  path_name = path.to_s.insert(2, '/').insert(5, '/')
  bucket.files.each do |file|
    if file.name.to_s == path_name
      return 409
    end
  end

  # Respond 201 for success
  new_file = bucket.create_file params['file']['tempfile'], path, content_type: params['file']['type']
  content_type :json
  raw_json = { "uploaded" => sha_hex }
  puts sha_hex
  return 201, JSON[raw_json]
end