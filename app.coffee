fs      = require('fs')
http    = require('http')
path    = require('path')
url     = require('url')
crypto  = require('crypto')
async   = require('async')
express = require('express')
config  = require('./config.json')

app     = express.createServer()
auth    = express.basicAuth config.credentials.username, config.credentials.password

app.get '/droplets/:appid/:hash', auth, (req, res) ->
  filename = "#{config.droplet_path}/#{req.params.appid}.#{req.params.hash}"
  req.sendfile filename
  console.log "request to download #{filename}"

app.post '/droplets/:appid/:hash', auth, (req, res) ->
  processUpload req, res, (filename) =>
    if filename
      validateFile filename, req.params.hash, (valid) =>
        if valid
          console.log "droplet validated, syncing to other nodes"
          syncFile req.params.appid, req.params.hash
        else
          console.log "droplet #{filename} is invalid, hash doesn't match. removing"
          fs.unlink filename


app.post '/sync/:appid/:hash', auth, (req, res) ->
  processUpload req, res, (filename) =>
    if filename
      validateFile filename, req.params.hash, (valid) =>
        if !valid
          console.log "droplet #{filename} is invalid, hash doesn't match. removing"
          fs.unlink filename


processUpload = (req, res, clbk) ->
  filename = "#{config.droplet_path}/#{req.params.appid}.#{req.params.hash}"
  path.exists filename, (exists) =>
    if exists
      res.send 200
      console.log "already have #{filename}"
      clbk null if clbk
    else
      writer = fs.createWriteStream filename
      req.pipe writer
      req.on 'close', () =>
        writer.destroy()
      writer.on 'close',  () =>
        res.send 200
        console.log "received file #{filename}"
        clbk filename if clbk


validateFile = (filename, hash, clbk) ->
  fs.readFile filename, (err, data) =>
    if crypto.createHash('sha1').update(data).digest('hex') == hash
      clbk true
    else
      clbk false

syncFile = (appid, hash) ->
  filename = "#{config.droplet_path}/#{appid}.#{hash}"
  async.forEach config.sync_hosts, (host, clbk) =>
    console.log "sending #{filename} to #{host}"
    uri = url.parse "http://#{config.credentials.username}:#{config.credentials.password}@#{host}/sync/#{appid}/#{hash}"
    uri.method = 'POST'
    reader = fs.createReadStream filename
    req = http.request uri, (res) =>
      # TODO, check status code
      res.on 'end', () =>
        clbk() if clbk
    reader.pipe req
    req.on 'close', () =>
      reader.destroy()
    req.on 'error', (error) =>
      console.log "error sending #{filename} to #{host}: #{error}"


app.listen config.port
console.log "Listening on port #{config.port}"
